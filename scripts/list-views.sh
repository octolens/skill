#!/bin/bash

# List all saved views from Octolens API
# Usage: ./list-views.sh YOUR_API_KEY

set -e

API_KEY="${1}"

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    echo "Usage: $0 YOUR_API_KEY"
    exit 1
fi

echo "Fetching views..."

curl -s "https://app.octolens.com/api/v1/views" \
  -H "Authorization: Bearer ${API_KEY}" | jq '.'

echo ""
echo "✓ Request complete"
