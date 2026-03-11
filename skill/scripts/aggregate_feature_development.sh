#!/bin/bash

# Script to aggregate weekly feature development summaries from S3
# Usage:
#   ./aggregate_feature_development.sh                    # Latest week
#   ./aggregate_feature_development.sh 2025-11-25         # Specific date
#   ./aggregate_feature_development.sh -1                 # 1 week back
#   ./aggregate_feature_development.sh -2                 # 2 weeks back
#   ./aggregate_feature_development.sh latest             # Same as no argument
#   ./aggregate_feature_development.sh [date] [output]    # Custom output file

# Configuration
BUCKET="features-summary-temp"

# Auto-detect AWS profile usage
# - In AgentCore/containers: Use IAM role (no profile needed)
# - Locally in Claude Code: Use profile if available
if [ -n "$AWS_EXECUTION_ENV" ] || [ -n "$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" ] || [ -n "$ECS_CONTAINER_METADATA_URI" ]; then
    # Running in container (ECS/Fargate/AgentCore) - use IAM role
    # AWS_EXECUTION_ENV is set in AgentCore
    PROFILE=""
    AWS_PROFILE_FLAG=""
else
    # Local environment - always use sre-dev-AdministratorAccess profile
    PROFILE="sre-dev-AdministratorAccess"
    AWS_PROFILE_FLAG="--profile $PROFILE"
fi

# Function to get all available weeks
get_all_weeks() {
    aws s3 ls "s3://$BUCKET/" $AWS_PROFILE_FLAG | grep PRE | awk '{print $2}' | sed 's|/||' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort -r
}

# Parse arguments
if [ -z "$1" ] || [ "$1" == "latest" ]; then
    # If no date provided or "latest", try to find the most recent directory
    echo "Looking for available feature development summaries..."
    echo ""

    ALL_WEEKS=$(get_all_weeks)

    if [ -z "$ALL_WEEKS" ]; then
        echo "Error: Could not find any feature development summaries in S3 bucket"
        exit 1
    fi

    echo "Available weeks:"
    echo "$ALL_WEEKS" | nl -w2 -s'. '
    echo ""

    # Get the most recent week
    SELECTED_WEEK=$(echo "$ALL_WEEKS" | head -1)
    PREFIX="$SELECTED_WEEK"
    echo "Using most recent summary: $SELECTED_WEEK"
    echo ""
elif [[ "$1" =~ ^-[0-9]+$ ]]; then
    # Negative number: N weeks back (e.g., -1 for last week, -2 for 2 weeks back)
    WEEKS_BACK=${1#-}
    echo "Looking for week $WEEKS_BACK back from latest..."
    echo ""

    ALL_WEEKS=$(get_all_weeks)

    if [ -z "$ALL_WEEKS" ]; then
        echo "Error: Could not find any weekly summaries in S3 bucket"
        exit 1
    fi

    echo "Available weeks:"
    echo "$ALL_WEEKS" | nl -w2 -s'. '
    echo ""

    # Get the Nth week (0-indexed, so we need to add 1)
    SELECTED_WEEK=$(echo "$ALL_WEEKS" | sed -n "$((WEEKS_BACK + 1))p")

    if [ -z "$SELECTED_WEEK" ]; then
        echo "Error: Cannot go back $WEEKS_BACK weeks. Only $(echo "$ALL_WEEKS" | wc -l) weeks available."
        exit 1
    fi

    PREFIX="$SELECTED_WEEK"
    echo "Using summary from $WEEKS_BACK week(s) back: $SELECTED_WEEK"
    echo ""
else
    # Explicit date provided
    PREFIX="$1"
    SELECTED_WEEK="$1"
    echo "Using explicitly provided date: $SELECTED_WEEK"
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$2" ]; then
    OUTPUT_FILE="$SCRIPT_DIR/../references/feature-development-summaries/feature_development_summary_${SELECTED_WEEK}.md"
else
    OUTPUT_FILE="$2"
fi

# Check if cached summary exists in S3
SUMMARY_S3_PATH="s3://$BUCKET/$PREFIX/SUMMARY.md"
echo "Checking for cached summary in S3..."
if aws s3 ls "$SUMMARY_S3_PATH" $AWS_PROFILE_FLAG >/dev/null 2>&1; then
    echo "✓ Found cached summary! Downloading from S3..."
    if aws s3 cp "$SUMMARY_S3_PATH" "$OUTPUT_FILE" $AWS_PROFILE_FLAG; then
        echo ""
        echo "Summary downloaded from cache: $OUTPUT_FILE"
        exit 0
    else
        echo "⚠ Failed to download cached summary, will regenerate..."
    fi
else
    echo "✗ No cached summary found, will generate fresh summary..."
fi
echo ""

TEMP_DIR="./s3_temp_files_$$"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Initialize output file
echo "# Feature Development Summary - ${SELECTED_WEEK}" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get list of all files
echo "Downloading files from s3://$BUCKET/$PREFIX/..."
file_count=0
added_count=0
skipped_count=0

while read -r file; do
    if [ -n "$file" ]; then
        ((file_count++))
        filename=$(basename "$file")
        service_name="${filename%.txt}"

        # Download file
        if aws s3 cp "s3://$BUCKET/$PREFIX/$file" "$TEMP_DIR/$filename" $AWS_PROFILE_FLAG --quiet 2>/dev/null; then
            # Read content
            content=$(cat "$TEMP_DIR/$filename")

            # Check if it's a "No recent changes" message
            if [[ ! "$content" =~ ^No\ recent\ changes ]]; then
                # Add to output file
                echo "## $service_name" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                echo "$content" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                echo "---" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"

                echo "✓ Added: $service_name"
                ((added_count++))
            else
                echo "✗ Skipped: $service_name (no recent changes)"
                ((skipped_count++))
            fi
        else
            echo "✗ Failed to download: $file"
        fi
    fi
done < <(aws s3 ls "s3://$BUCKET/$PREFIX/" $AWS_PROFILE_FLAG | awk '{print $4}')

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Summary:"
echo "  - Services with changes: $added_count"
echo "  - Services without changes: $skipped_count"
echo ""
echo "Output written to: $OUTPUT_FILE"

# Upload summary to S3 for caching
echo ""
echo "Uploading summary to S3 for future caching..."
if aws s3 cp "$OUTPUT_FILE" "$SUMMARY_S3_PATH" $AWS_PROFILE_FLAG; then
    echo "✓ Summary cached to S3: $SUMMARY_S3_PATH"
else
    echo "⚠ Failed to upload summary to S3 (non-fatal)"
fi
