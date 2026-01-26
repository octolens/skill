#!/bin/bash

# Query mentions with advanced AND/OR filter groups
# Usage: ./advanced-query.sh YOUR_API_KEY

set -e

API_KEY="${1}"
LIMIT="${2:-20}"

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    echo "Usage: $0 YOUR_API_KEY [limit]"
    exit 1
fi

echo "Querying mentions with advanced filters..."
echo "Query: (Twitter OR Reddit) AND (Positive sentiment) AND NOT spam"

curl -s -X POST "https://app.octolens.com/api/v1/mentions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"limit\": ${LIMIT},
    \"filters\": {
      \"operator\": \"AND\",
      \"groups\": [
        {
          \"operator\": \"OR\",
          \"conditions\": [
            { \"source\": [\"twitter\"] },
            { \"source\": [\"reddit\"] }
          ]
        },
        {
          \"operator\": \"AND\",
          \"conditions\": [
            { \"sentiment\": [\"positive\"] },
            { \"!tag\": [\"spam\"] }
          ]
        }
      ]
    }
  }" | jq '.'

echo ""
echo "✓ Request complete"
