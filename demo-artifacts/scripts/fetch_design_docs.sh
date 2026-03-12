#!/bin/bash

# Script to fetch Technical Design Documents from a wiki with intelligent metadata extraction
# Uses AWS Bedrock (Claude) to extract: Tech Lead, Manager, Team, Epic, Services, Problem, Summary
# Supports incremental sync with per-TDD caching (skips unchanged documents)
#
# Usage:
#   ./fetch_design_docs.sh           # Incremental sync (fetch only new TDDs)
#   ./fetch_design_docs.sh --full    # Full refresh (re-process all TDDs)

# Configuration - set these environment variables or override below
CONFLUENCE_URL="${CONFLUENCE_URL:-https://your-instance.atlassian.net}"
PARENT_PAGE_ID="${CONFLUENCE_PARENT_PAGE_ID:-2992766999}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/../references/design-docs/design-doc-index.md"
CACHE_DIR="$SCRIPT_DIR/../references/design-docs/design-doc-details"
LAST_SYNC_FILE="$SCRIPT_DIR/../references/design-docs/.last-tdd-sync"

# AWS Bedrock Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"

# Auto-detect latest Sonnet inference profile
if [ -z "$BEDROCK_MODEL" ]; then
    echo "Detecting latest Claude Sonnet inference profile..."
    BEDROCK_MODEL=$(aws bedrock list-inference-profiles --region "$AWS_REGION" 2>/dev/null | \
        jq -r '.inferenceProfileSummaries[] | select(.inferenceProfileId | contains("sonnet")) | .inferenceProfileId' | \
        sort -V | tail -1)

    if [ -z "$BEDROCK_MODEL" ]; then
        echo "Error: Could not detect Claude Sonnet inference profile"
        exit 1
    fi
    echo "Using inference profile: $BEDROCK_MODEL"
fi

# Check for authentication
if [ -z "$CONFLUENCE_TOKEN" ] || [ -z "$CONFLUENCE_EMAIL" ]; then
    echo "Error: Confluence authentication not configured"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity --region "$AWS_REGION" &>/dev/null; then
    echo "Error: AWS credentials not configured or expired"
    echo "Current profile: $AWS_PROFILE"
    exit 1
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Parse arguments
SYNC_MODE="incremental"
LIMIT=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --full) SYNC_MODE="full"; shift ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo ""
echo "=========================================="
echo "Fetch TDD Index with Caching"
echo "=========================================="
echo ""
echo "Sync Mode: $SYNC_MODE"
echo "Model: $BEDROCK_MODEL"
echo "Region: $AWS_REGION"
echo "Cache Dir: $CACHE_DIR"
[ -n "$LIMIT" ] && echo "Limit: $LIMIT TDDs"
echo ""

# Determine date filter
LAST_SYNC_DATE="2020-01-01T00:00:00.000Z"
if [ -f "$OUTPUT_FILE" ] && [ "$SYNC_MODE" == "incremental" ]; then
    if [ -f "$LAST_SYNC_FILE" ]; then
        LAST_SYNC_DATE=$(cat "$LAST_SYNC_FILE")
        echo "Running INCREMENTAL sync (after $LAST_SYNC_DATE)"
    else
        echo "No last sync found. Running FULL sync."
        SYNC_MODE="full"
    fi
else
    echo "Running FULL sync"
fi

# Build CQL query
if [ "$SYNC_MODE" == "full" ]; then
    CQL="parent=$PARENT_PAGE_ID ORDER BY created DESC"
else
    CQL_DATE=$(echo "$LAST_SYNC_DATE" | cut -d'T' -f1)
    CQL="parent=$PARENT_PAGE_ID AND created>='$CQL_DATE' ORDER BY created DESC"
fi

# Fetch TDD list
TEMP_JSON="/tmp/confluence_tdds_$$.json"
CQL_ENCODED=$(echo "$CQL" | jq -sRr @uri)
RESPONSE=$(curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
  -H "Accept: application/json" \
  "$CONFLUENCE_URL/wiki/rest/api/content/search?cql=$CQL_ENCODED&limit=250&expand=history")

# Check for errors
if echo "$RESPONSE" | grep -q '"statusCode":'; then
    echo "Error fetching pages from Confluence:"
    echo "$RESPONSE" | jq -r '.message // .statusCode'
    rm -f "$TEMP_JSON"
    exit 1
fi

echo "$RESPONSE" > "$TEMP_JSON"

RESULTS_COUNT=$(jq '.results | length' "$TEMP_JSON")

# Apply limit if specified
if [ -n "$LIMIT" ] && [ "$LIMIT" -lt "$RESULTS_COUNT" ]; then
    echo "Limiting to first $LIMIT TDDs (of $RESULTS_COUNT found)"
    RESULTS_COUNT=$LIMIT
fi

if [ "$RESULTS_COUNT" -eq 0 ]; then
    echo "✓ No new TDDs found"
    rm -f "$TEMP_JSON"
    exit 0
fi

echo "✓ Found $RESULTS_COUNT TDD(s)"
echo ""

# Function to call Bedrock for LLM processing
call_bedrock_llm() {
    local prompt="$1"
    local content="$2"

    # Build Bedrock API request and save to temp file
    local temp_request="/tmp/bedrock_request_$$.json"
    local temp_response="/tmp/bedrock_response_$$.json"

    jq -n \
        --arg prompt "$prompt" \
        --arg content "$content" \
        '{
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [{
                "role": "user",
                "content": ($prompt + "\n\n" + $content)
            }],
            "temperature": 0.3
        }' > "$temp_request"

    # Call Bedrock with fileb:// prefix
    aws bedrock-runtime invoke-model \
        --region "$AWS_REGION" \
        --model-id "$BEDROCK_MODEL" \
        --body "fileb://$temp_request" \
        "$temp_response" 2>/dev/null >/dev/null

    # Extract text from response and strip markdown code fences
    local result=$(cat "$temp_response" 2>/dev/null | \
        jq -r '.content[0].text // ""' 2>/dev/null | \
        sed 's/^```json//; s/^```//; s/```$//' | \
        grep -v '^$' | \
        tr '\n' ' ' || echo "")

    # Cleanup
    rm -f "$temp_request" "$temp_response"

    echo "$result"
}

# Initialize output file for full sync
CURRENT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

if [ "$SYNC_MODE" == "full" ]; then
    cat > "$OUTPUT_FILE" <<EOF
# Technical Design Documents Index

**Last full sync**: $CURRENT_TIMESTAMP
**Last incremental sync**: $CURRENT_TIMESTAMP
**Parent page**: $CONFLUENCE_URL/wiki/spaces/RND/pages/$PARENT_PAGE_ID
**Total documents**: $RESULTS_COUNT
**Summarization**: AWS Bedrock ($BEDROCK_MODEL)
**Cache**: Detailed summaries stored in \`design-doc-details/\`

## Design Documents (Sorted by Creation Date - Newest First)

EOF
fi

# Process TDDs
echo "Processing TDDs with detailed caching..."
PROCESSED_COUNT=0

while read -r page; do
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))

    # Apply limit
    if [ -n "$LIMIT" ] && [ "$PROCESSED_COUNT" -gt "$LIMIT" ]; then
        break
    fi

    PAGE_ID=$(echo "$page" | jq -r '.id')
    TITLE=$(echo "$page" | jq -r '.title')
    STATUS=$(echo "$page" | jq -r '.status')
    CREATED=$(echo "$page" | jq -r '.history.createdDate // "unknown"')

    echo "  [$PROCESSED_COUNT/$RESULTS_COUNT] $TITLE"

    CACHE_FILE="$CACHE_DIR/$PAGE_ID.json"

    # Fetch metadata to check if extraction is needed
    echo "    → Checking if extraction needed..."
    TEMP_TDD="/tmp/tdd_single_$$.json"
    curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
        "$CONFLUENCE_URL/wiki/rest/api/content/$PAGE_ID?expand=version" \
        > "$TEMP_TDD"

    LAST_EDITED=$(jq -r '.version.when // "unknown"' "$TEMP_TDD")

    # Check if cache exists and is up-to-date
    NEEDS_EXTRACTION=true
    if [ -f "$CACHE_FILE" ]; then
        CACHED_LAST_EDITED=$(jq -r '.last_edited // "unknown"' "$CACHE_FILE" 2>/dev/null)
        HAS_EXTRACTION=$(jq -e '.extraction.metadata' "$CACHE_FILE" &>/dev/null && echo "true" || echo "false")

        if [ "$HAS_EXTRACTION" == "false" ]; then
            echo "    → Cache missing extraction details"
        elif [ "$CACHED_LAST_EDITED" == "$LAST_EDITED" ]; then
            echo "    ✓ Cache up-to-date (last edited: $LAST_EDITED)"
            NEEDS_EXTRACTION=false
        else
            echo "    → Cache outdated (cached: $CACHED_LAST_EDITED, current: $LAST_EDITED)"
        fi
    else
        echo "    → No cache found"
    fi

    # Only extract if needed
    if [ "$NEEDS_EXTRACTION" = true ]; then
        # Fetch full content
        echo "    → Fetching full content..."
        curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
            "$CONFLUENCE_URL/wiki/rest/api/content/$PAGE_ID?expand=body.export_view,version" \
            > "$TEMP_TDD"

        HTML_BODY=$(jq -r '.body.export_view.value // ""' "$TEMP_TDD")
        LAST_EDITED=$(jq -r '.version.when // "unknown"' "$TEMP_TDD")

        # Extract text content (remove HTML)
        TEXT_CONTENT=$(echo "$HTML_BODY" | \
            sed 's/<[^>]*>//g' | \
            sed 's/&nbsp;/ /g' | \
            sed 's/&quot;/"/g' | \
            sed 's/&amp;/\&/g' | \
            tr -s '[:space:]' ' ' | \
            head -c 20000)

        # Call Bedrock for detailed extraction
        echo "    → Calling Bedrock for detailed extraction..."

    EXTRACTION_PROMPT="Extract detailed information from this Technical Design Document and return ONLY valid JSON.

Return JSON with this structure:
{
  \"metadata\": {
    \"tech_lead\": \"name or empty string\",
    \"manager\": \"name or empty string\",
    \"team\": \"team name or empty string\",
    \"epic\": \"Epic ID or empty string\",
    \"services\": [\"service-name-1\", \"service-name-2\"]
  },
  \"summary\": \"A detailed 2-3 sentence summary of the entire design document\",
  \"problem\": \"1-2 sentence problem summary\",
  \"sections\": {
    \"goals\": \"Summary of Goals & Non-Goals section (or empty if not present)\",
    \"proposed_solution\": \"Summary of Proposed/Suggested Solution section (or empty if not present)\",
    \"business_logic\": \"Summary of Business Logic section (or empty if not present)\",
    \"api_design\": \"Summary of API Design & Security section (or empty if not present)\",
    \"auth\": \"Summary of Authentication and Authorization section (or empty if not present)\",
    \"data_model\": \"Summary of Data Model / Schema Changes section (or empty if not present)\",
    \"migration\": \"Summary of Migration Strategy section (or empty if not present)\",
    \"rollout\": \"Summary of Rollout / Deployment Strategy section (or empty if not present)\",
    \"monitoring\": \"Summary of Monitoring & Alerting section (or empty if not present)\",
    \"testing\": \"Summary of Testing Strategy section (or empty if not present)\"
  }
}

Guidelines:
- Look for Tech Lead/Manager/Team in metadata table at top
- Look for Epic/ticket references (format: ARCH-XXX, ENG-XXX, etc)
- Service names follow patterns: xxx-service, xxx-platform, xxx-api
- For sections: ONLY include summaries if the section has actual content beyond the template
- If a section is just the template heading with no content, leave it as empty string
- Keep summaries concise but informative

Document content:"

        LLM_RESPONSE=$(call_bedrock_llm "$EXTRACTION_PROMPT" "$TEXT_CONTENT")

        # Save to cache file with metadata (pretty-printed JSON)
        if [ -n "$LLM_RESPONSE" ]; then
            jq -n \
                --arg page_id "$PAGE_ID" \
                --arg title "$TITLE" \
                --arg url "$CONFLUENCE_URL/wiki/spaces/RND/pages/$PAGE_ID" \
                --arg created "$CREATED" \
                --arg last_edited "$LAST_EDITED" \
                --arg status "$STATUS" \
                --arg extracted_at "$CURRENT_TIMESTAMP" \
                --argjson extraction "$LLM_RESPONSE" \
                '{
                    page_id: $page_id,
                    title: $title,
                    url: $url,
                    created: $created,
                    last_edited: $last_edited,
                    status: $status,
                    extracted_at: $extracted_at,
                    extraction: $extraction
                }' > "$CACHE_FILE"
            echo "    → Cached to $CACHE_FILE"
        fi
    fi

    # Read from cache for index generation (works for both new and cached entries)
    if [ -f "$CACHE_FILE" ]; then
        LLM_RESPONSE=$(jq -c '.extraction' "$CACHE_FILE" 2>/dev/null)
        TECH_LEAD=$(echo "$LLM_RESPONSE" | jq -r '.metadata.tech_lead // ""' 2>/dev/null)
        MANAGER=$(echo "$LLM_RESPONSE" | jq -r '.metadata.manager // ""' 2>/dev/null)
        TEAM=$(echo "$LLM_RESPONSE" | jq -r '.metadata.team // ""' 2>/dev/null)
        EPIC=$(echo "$LLM_RESPONSE" | jq -r '.metadata.epic // ""' 2>/dev/null)
        SERVICES=$(echo "$LLM_RESPONSE" | jq -r '.metadata.services | join(", ") // "unknown"' 2>/dev/null)
        PROBLEM=$(echo "$LLM_RESPONSE" | jq -r '.problem // ""' 2>/dev/null)
        SUMMARY=$(echo "$LLM_RESPONSE" | jq -r '.summary // ""' 2>/dev/null)
    else
        TECH_LEAD=""
        MANAGER=""
        TEAM=""
        EPIC=""
        SERVICES="unknown"
        PROBLEM=""
        SUMMARY=""
    fi

    # Build lightweight index entry
    TDD_ENTRY="
### $TITLE
- **Page ID**: $PAGE_ID
- **URL**: $CONFLUENCE_URL/wiki/spaces/RND/pages/$PAGE_ID
- **Created**: $CREATED
- **Last Edited**: $LAST_EDITED
- **Status**: $STATUS"

    # Add optional metadata fields
    [ -n "$TECH_LEAD" ] && TDD_ENTRY="$TDD_ENTRY
- **Tech Lead**: $TECH_LEAD"

    [ -n "$MANAGER" ] && TDD_ENTRY="$TDD_ENTRY
- **Manager**: $MANAGER"

    [ -n "$TEAM" ] && TDD_ENTRY="$TDD_ENTRY
- **Team**: $TEAM"

    [ -n "$EPIC" ] && TDD_ENTRY="$TDD_ENTRY
- **Epic**: $EPIC"

    TDD_ENTRY="$TDD_ENTRY
- **Related Services**: $SERVICES"

    [ -n "$PROBLEM" ] && TDD_ENTRY="$TDD_ENTRY
- **Problem**: $PROBLEM"

    [ -n "$SUMMARY" ] && TDD_ENTRY="$TDD_ENTRY
- **Summary**: $SUMMARY"

    TDD_ENTRY="$TDD_ENTRY
- **Detailed Cache**: \`design-doc-details/$PAGE_ID.json\`

---
"

    # Write immediately (streaming)
    echo "$TDD_ENTRY" >> "$OUTPUT_FILE"

    rm -f "$TEMP_TDD"
    echo "    ✓ Complete"

done < <(jq -c ".results[0:${LIMIT:-250}][]" "$TEMP_JSON")

# Save timestamp
echo "$CURRENT_TIMESTAMP" > "$LAST_SYNC_FILE"

# Cleanup
rm -f "$TEMP_JSON"

echo ""
echo "✓ Index updated: $OUTPUT_FILE"
echo "✓ Cache directory: $CACHE_DIR"
echo "✓ Processed: $PROCESSED_COUNT TDDs"
echo ""
