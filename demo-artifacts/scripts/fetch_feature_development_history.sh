#!/bin/bash

# Script to fetch feature development history for a single service across multiple weeks
# Usage:
#   ./fetch_feature_development_history.sh <service-name> <weeks-back>
#   ./fetch_feature_development_history.sh commerce-ai 4       # Last 4 weeks of commerce-ai
#   ./fetch_feature_development_history.sh ta-hotel-service 2  # Last 2 weeks of ta-hotel-service

# Configuration
BUCKET="sentinal-features-summary"
REGION="us-west-1"

# Auto-detect AWS profile usage
# - In AgentCore/containers: Use IAM role (no profile needed)
# - Locally in Claude Code: Use profile if available
if [ -n "$AWS_EXECUTION_ENV" ] || [ -n "$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" ] || [ -n "$ECS_CONTAINER_METADATA_URI" ]; then
    # Running in container (ECS/Fargate/AgentCore) - use IAM role
    # AWS_EXECUTION_ENV is set in AgentCore
    PROFILE=""
    AWS_PROFILE_FLAG="--region $REGION"
else
    # Local environment - always use sre-dev-AdministratorAccess profile
    PROFILE="sre-dev-AdministratorAccess"
    AWS_PROFILE_FLAG="--profile $PROFILE --region $REGION"
fi

# Validate arguments
if [ -z "$1" ]; then
    echo "Error: Service name is required"
    echo "Usage: $0 <service-name> <weeks-back>"
    echo "Example: $0 commerce-ai 4"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: Number of weeks is required"
    echo "Usage: $0 <service-name> <weeks-back>"
    echo "Example: $0 commerce-ai 4"
    exit 1
fi

SERVICE_NAME="$1"
WEEKS_BACK="$2"

# Validate weeks is a number
if ! [[ "$WEEKS_BACK" =~ ^[0-9]+$ ]]; then
    echo "Error: Weeks must be a positive number"
    exit 1
fi

# Function to get all available weeks
get_all_weeks() {
    aws s3 ls "s3://$BUCKET/" $AWS_PROFILE_FLAG | grep PRE | awk '{print $2}' | sed 's|/||' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort -r
}

echo "========================================"
echo "Fetching Feature Development History"
echo "========================================"
echo "Service: $SERVICE_NAME"
echo "Weeks back: $WEEKS_BACK"
echo ""

# Get available weeks
echo "Fetching available weeks from S3..."
ALL_WEEKS=$(get_all_weeks)

if [ -z "$ALL_WEEKS" ]; then
    echo "Error: Could not find any feature development data in S3 bucket"
    exit 1
fi

TOTAL_WEEKS=$(echo "$ALL_WEEKS" | wc -l | tr -d ' ')
echo "Found $TOTAL_WEEKS weeks available in S3"
echo ""

# Check if we have enough weeks
if [ "$WEEKS_BACK" -gt "$TOTAL_WEEKS" ]; then
    echo "Warning: Only $TOTAL_WEEKS weeks available, will fetch all of them"
    WEEKS_BACK=$TOTAL_WEEKS
fi

# Download files for each week
echo "Downloading $SERVICE_NAME.txt for the last $WEEKS_BACK weeks..."
echo ""

downloaded=0
not_found=0
failed=0

for i in $(seq 0 $((WEEKS_BACK - 1))); do
    WEEK=$(echo "$ALL_WEEKS" | sed -n "$((i + 1))p")

    if [ -z "$WEEK" ]; then
        break
    fi

    S3_PATH="s3://$BUCKET/$WEEK/${SERVICE_NAME}.txt"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOCAL_FILE="$SCRIPT_DIR/../.cache/service-feature-development/${SERVICE_NAME}-${WEEK}.txt"

    # Try to download the file
    if aws s3 cp "$S3_PATH" "$LOCAL_FILE" $AWS_PROFILE_FLAG --quiet 2>/dev/null; then
        # Check if it's a "No recent changes" file
        if grep -q "^No recent changes" "$LOCAL_FILE"; then
            echo "✗ $WEEK: No feature development activity"
            ((not_found++))
        else
            FILE_SIZE=$(wc -c < "$LOCAL_FILE" | tr -d ' ')
            echo "✓ $WEEK: Downloaded ($FILE_SIZE bytes) -> $LOCAL_FILE"
            ((downloaded++))
        fi
    else
        echo "✗ $WEEK: File not found in S3"
        ((not_found++))
    fi
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Downloaded: $downloaded file(s)"
echo "Not found or no activity: $not_found file(s)"

if [ "$downloaded" -eq 0 ]; then
    echo ""
    echo "No files were downloaded. Service '$SERVICE_NAME' may not exist or had no feature development activity."
    exit 1
fi

echo ""
echo "Files saved with format: ${SERVICE_NAME}-YYYY-MM-DD.txt"
