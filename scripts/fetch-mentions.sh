#!/bin/bash

# Fetch mentions from Octolens API
# Usage: ./fetch-mentions.sh YOUR_API_KEY [limit] [includeAll]

set -e

API_KEY="${1}"
LIMIT="${2:-20}"
INCLUDE_ALL="${3:-false}"

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    echo "Usage: $0 YOUR_API_KEY [limit] [includeAll]"
    exit 1
fi

echo "Fetching mentions (limit: $LIMIT, includeAll: $INCLUDE_ALL)..."

curl -s -X POST "https://app.octolens.com/api/v1/mentions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"limit\": ${LIMIT},
    \"includeAll\": ${INCLUDE_ALL}
  }" | jq '.'

echo ""
echo "✓ Request complete"
