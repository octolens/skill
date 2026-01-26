#!/bin/bash

# List all keywords from Octolens API
# Usage: ./list-keywords.sh YOUR_API_KEY

set -e

API_KEY="${1}"

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    echo "Usage: $0 YOUR_API_KEY"
    exit 1
fi

echo "Fetching keywords..."

curl -s "https://app.octolens.com/api/v1/keywords" \
  -H "Authorization: Bearer ${API_KEY}" | jq '.'

echo ""
echo "✓ Request complete"
