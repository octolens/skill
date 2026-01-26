#!/bin/bash

# Query mentions with custom filters
# Usage: ./query-mentions.sh YOUR_API_KEY '{"source": ["twitter"], "sentiment": ["positive"]}'

set -e

API_KEY="${1}"
FILTERS="${2}"

if [ -z "$API_KEY" ] || [ -z "$FILTERS" ]; then
    echo "Error: API key and filters required"
    echo "Usage: $0 YOUR_API_KEY '{\"source\": [\"twitter\"]}'"
    echo ""
    echo "Example filters:"
    echo "  Simple: '{\"source\": [\"twitter\"], \"sentiment\": [\"positive\"]}'"
    echo "  With exclusion: '{\"source\": [\"twitter\"], \"!tag\": [\"spam\"]}'"
    echo "  Date range: '{\"startDate\": \"2024-01-01T00:00:00Z\", \"endDate\": \"2024-01-31T23:59:59Z\"}'"
    exit 1
fi

echo "Querying mentions with custom filters..."

curl -s -X POST "https://app.octolens.com/api/v1/mentions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"limit\": 20,
    \"filters\": ${FILTERS}
  }" | jq '.'

echo ""
echo "✓ Request complete"
