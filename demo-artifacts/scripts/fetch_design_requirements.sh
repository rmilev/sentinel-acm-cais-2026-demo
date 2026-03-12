#!/bin/bash

# Script to fetch the TDD requirements policy from a wiki using REST API
# Usage:
#   ./fetch_design_requirements.sh

# Configuration - set these environment variables or override below
CONFLUENCE_URL="${CONFLUENCE_URL:-https://your-instance.atlassian.net}"
PAGE_ID="${CONFLUENCE_PARENT_PAGE_ID:-2992766999}"
OUTPUT_FILE="../references/design-docs/design-requirements.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_PATH="$SCRIPT_DIR/$OUTPUT_FILE"

# Check for authentication
if [ -z "$CONFLUENCE_TOKEN" ]; then
    echo "Error: CONFLUENCE_TOKEN environment variable not set"
    echo ""
    echo "Please set up authentication:"
    echo "  1. Generate an API token at: https://id.atlassian.com/manage-profile/security/api-tokens"
    echo "  2. Export credentials:"
    echo "     export CONFLUENCE_EMAIL='your.email@example.com'"
    echo "     export CONFLUENCE_TOKEN='your-api-token'"
    echo ""
    echo "Or add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "  export CONFLUENCE_EMAIL='your.email@example.com'"
    echo "  export CONFLUENCE_TOKEN='your-api-token'"
    exit 1
fi

if [ -z "$CONFLUENCE_EMAIL" ]; then
    echo "Error: CONFLUENCE_EMAIL environment variable not set"
    echo "Export your Confluence email: export CONFLUENCE_EMAIL='your.email@example.com'"
    exit 1
fi

echo "========================================"
echo "Fetch TDD Requirements Policy"
echo "========================================"
echo ""
echo "Fetching from Confluence REST API..."
echo "  URL: $CONFLUENCE_URL"
echo "  Page ID: $PAGE_ID"
echo "  User: $CONFLUENCE_EMAIL"
echo ""

# Check if we need to fetch (compare version)
echo "Checking if update needed..."
TEMP_METADATA="/tmp/confluence_metadata_$$.json"
curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
  -H "Accept: application/json" \
  "$CONFLUENCE_URL/wiki/api/v2/pages/$PAGE_ID" > "$TEMP_METADATA"

# Check for errors
if grep -q '"statusCode":' "$TEMP_METADATA"; then
    echo "Error fetching page metadata from Confluence:"
    cat "$TEMP_METADATA" | jq -r '.message // .statusCode'
    rm -f "$TEMP_METADATA"
    exit 1
fi

CURRENT_VERSION=$(cat "$TEMP_METADATA" | jq -r '.version.number')
PAGE_TITLE=$(cat "$TEMP_METADATA" | jq -r '.title')
rm -f "$TEMP_METADATA"

# Check cached version
NEEDS_FETCH=true
if [ -f "$OUTPUT_PATH" ]; then
    CACHED_VERSION=$(grep "^\*\*Version\*\*:" "$OUTPUT_PATH" 2>/dev/null | sed 's/.*: //')
    if [ "$CACHED_VERSION" == "$CURRENT_VERSION" ]; then
        echo "✓ Cache up-to-date (version $CURRENT_VERSION)"
        echo "✓ Using cached file: $OUTPUT_PATH"
        NEEDS_FETCH=false
    else
        echo "→ Cache outdated (cached: v${CACHED_VERSION:-unknown}, current: v$CURRENT_VERSION)"
    fi
else
    echo "→ No cache found"
fi

if [ "$NEEDS_FETCH" = false ]; then
    echo ""
    echo "✓ No update needed"
    exit 0
fi

# Fetch page content from Confluence API
echo "→ Fetching full content..."
# API docs: https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-page/#api-pages-id-get
RESPONSE=$(curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
  -H "Accept: application/json" \
  "$CONFLUENCE_URL/wiki/api/v2/pages/$PAGE_ID?body-format=storage")

# Check for errors
if echo "$RESPONSE" | grep -q '"statusCode":'; then
    echo "Error fetching page from Confluence:"
    echo "$RESPONSE" | jq -r '.message // .statusCode'
    exit 1
fi

# Extract page body
PAGE_BODY=$(echo "$RESPONSE" | jq -r '.body.storage.value')

if [ "$PAGE_BODY" == "null" ] || [ -z "$PAGE_BODY" ]; then
    echo "Error: Could not extract page content"
    exit 1
fi

echo "✓ Successfully fetched: $PAGE_TITLE"
echo ""

# Convert HTML to Markdown (basic conversion)
# For better conversion, could use pandoc if available
echo "Converting HTML to Markdown..."

# Create markdown file
cat > "$OUTPUT_PATH" <<EOF
# Technical Design Documents - When to Write a TDD

**Source**: Confluence page $PAGE_ID
**Title**: $PAGE_TITLE
**Version**: $CURRENT_VERSION
**Last fetched**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

---

EOF

# Simple HTML to Markdown conversion
# Remove HTML tags and convert basic formatting
echo "$PAGE_BODY" | \
    sed 's/<[/]*strong>/**/g' | \
    sed 's/<[/]*em>/_/g' | \
    sed 's/<[/]*p>/\n/g' | \
    sed 's/<li>/- /g' | \
    sed 's/<[/]*li>//g' | \
    sed 's/<[/]*ul>/\n/g' | \
    sed 's/<[/]*ol>/\n/g' | \
    sed 's/<h1[^>]*>/\n# /g' | \
    sed 's/<h2[^>]*>/\n## /g' | \
    sed 's/<h3[^>]*>/\n### /g' | \
    sed 's/<h4[^>]*>/\n#### /g' | \
    sed 's/<[/]*h[1-4]>//g' | \
    sed 's/<br[^>]*>/\n/g' | \
    sed 's/<[^>]*>//g' | \
    sed 's/&nbsp;/ /g' | \
    sed 's/&amp;/\&/g' | \
    sed 's/&lt;/</g' | \
    sed 's/&gt;/>/g' | \
    sed 's/&quot;/"/g' | \
    grep -v '^$' >> "$OUTPUT_PATH"

echo ""
echo "✓ Saved to: $OUTPUT_PATH"
echo "✓ File size: $(wc -c < "$OUTPUT_PATH") bytes"
echo ""
echo "Note: HTML to Markdown conversion is basic."
echo "For better formatting, install pandoc and we can use:"
echo "  echo \"\$PAGE_BODY\" | pandoc -f html -t markdown"
echo ""
