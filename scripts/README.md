# Octolens API Scripts

These bash scripts provide quick access to the Octolens API. All scripts require `curl` and `jq` to be installed.

## Prerequisites

```bash
# Check if curl is installed
curl --version

# Check if jq is installed (for JSON parsing)
jq --version

# Install jq if needed (macOS)
brew install jq

# Install jq if needed (Ubuntu/Debian)
sudo apt-get install jq
```

## Available Scripts

### 1. fetch-mentions.sh

Fetch mentions with basic parameters.

```bash
./fetch-mentions.sh YOUR_API_KEY [limit] [includeAll]
```

**Parameters:**
- `YOUR_API_KEY` (required): Your Octolens API key
- `limit` (optional, default: 20): Number of results to return (1-100)
- `includeAll` (optional, default: false): Include low-relevance posts

**Examples:**
```bash
# Fetch 20 mentions (default)
./fetch-mentions.sh your_api_key_here

# Fetch 50 mentions
./fetch-mentions.sh your_api_key_here 50

# Fetch 30 mentions including low-relevance posts
./fetch-mentions.sh your_api_key_here 30 true
```

### 2. list-keywords.sh

List all keywords configured for your organization.

```bash
./list-keywords.sh YOUR_API_KEY
```

**Example:**
```bash
./list-keywords.sh your_api_key_here
```

### 3. list-views.sh

List all saved views (pre-configured filters).

```bash
./list-views.sh YOUR_API_KEY
```

**Example:**
```bash
./list-views.sh your_api_key_here
```

### 4. query-mentions.sh

Query mentions with custom filter JSON.

```bash
./query-mentions.sh YOUR_API_KEY '{"filter": "json"}'
```

**Examples:**
```bash
# Filter by source
./query-mentions.sh your_api_key_here '{"source": ["twitter", "reddit"]}'

# Filter by sentiment
./query-mentions.sh your_api_key_here '{"sentiment": ["positive"]}'

# Multiple filters (implicit AND)
./query-mentions.sh your_api_key_here '{"source": ["twitter"], "sentiment": ["positive"], "minXFollowers": 1000}'

# With exclusion
./query-mentions.sh your_api_key_here '{"source": ["twitter"], "!tag": ["spam"]}'

# Date range
./query-mentions.sh your_api_key_here '{"startDate": "2024-01-01T00:00:00Z", "endDate": "2024-01-31T23:59:59Z"}'

# Combine multiple filters
./query-mentions.sh your_api_key_here '{
  "source": ["twitter", "linkedin"],
  "sentiment": ["positive"],
  "minXFollowers": 500,
  "startDate": "2024-01-20T00:00:00Z"
}'
```

### 5. advanced-query.sh

Query with complex AND/OR logic (demonstrates advanced filtering).

```bash
./advanced-query.sh YOUR_API_KEY [limit]
```

**Default query**: `(Twitter OR Reddit) AND (Positive sentiment) AND NOT spam`

**Example:**
```bash
# Use default query with 20 results
./advanced-query.sh your_api_key_here

# Use default query with 50 results
./advanced-query.sh your_api_key_here 50
```

## Filter Fields Reference

| Field | Type | Values |
|-------|------|--------|
| `source` | array | twitter, reddit, github, linkedin, youtube, hackernews, devto, stackoverflow, bluesky, newsletter, podcast |
| `sentiment` | array | positive, neutral, negative |
| `keyword` | array | Keyword IDs (get from list-keywords.sh) |
| `language` | array | en, es, fr, de, pt, it, nl, ja, ko, zh |
| `tag` | array | Tag names |
| `bookmarked` | boolean | true or false |
| `engaged` | boolean | true or false |
| `minXFollowers` | number | Minimum follower count |
| `maxXFollowers` | number | Maximum follower count |
| `startDate` | string | ISO 8601 format |
| `endDate` | string | ISO 8601 format |

## Exclusions

Prefix any array field with `!` to exclude values:

```bash
# Exclude spam tag
'{"!tag": ["spam"]}'

# Exclude specific keywords
'{"!keyword": [5, 6]}'

# Exclude negative sentiment
'{"!sentiment": ["negative"]}'
```

## Advanced Filtering

For complex AND/OR logic, use the `operator` and `groups` structure:

```json
{
  "operator": "AND",
  "groups": [
    {
      "operator": "OR",
      "conditions": [
        { "source": ["twitter"] },
        { "source": ["reddit"] }
      ]
    },
    {
      "operator": "AND",
      "conditions": [
        { "sentiment": ["positive"] },
        { "!tag": ["spam"] }
      ]
    }
  ]
}
```

## Tips

1. **Escape quotes**: When using filters in bash, escape quotes properly or use single quotes around the JSON
2. **Pretty print**: All scripts use `jq '.'` for formatted output
3. **Save responses**: Pipe output to a file: `./fetch-mentions.sh key > results.json`
4. **Chain with jq**: Extract specific fields: `./list-keywords.sh key | jq '.data[].keyword'`
5. **Error handling**: Scripts exit on error (`set -e`), check exit codes in your workflows

## Common Patterns

### Get positive mentions from high-follower accounts
```bash
./query-mentions.sh your_api_key_here '{
  "sentiment": ["positive"],
  "minXFollowers": 10000
}'
```

### Get recent mentions (last 7 days)
```bash
# Calculate date 7 days ago
START_DATE=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ")
./query-mentions.sh your_api_key_here "{\"startDate\": \"$START_DATE\"}"
```

### Filter by specific keyword
```bash
# First get keyword IDs
./list-keywords.sh your_api_key_here | jq '.data[] | {id, keyword}'

# Then filter by keyword ID
./query-mentions.sh your_api_key_here '{"keyword": [1]}'
```

### Exclude negative sentiment and spam
```bash
./query-mentions.sh your_api_key_here '{
  "!sentiment": ["negative"],
  "!tag": ["spam", "irrelevant"]
}'
```

## Troubleshooting

### "command not found: jq"
Install jq: `brew install jq` (macOS) or `sudo apt-get install jq` (Ubuntu)

### "unauthorized" error
Check your API key is correct and has proper permissions

### "rate_limit_exceeded" error
You've hit the 500 requests/hour limit. Wait for the rate limit to reset.

### Invalid JSON
Ensure your filter JSON is properly formatted. Test with: `echo '{"source": ["twitter"]}' | jq`
