---
name: octolens
description: Query and manage Octolens social-listening data — brand mentions, keywords, feeds, analytics, and notifications across Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky, Hacker News, GitHub, news, podcasts, and the open web. Use when the user wants to fetch or filter mentions, set up keyword tracking, configure Slack/email/webhook alerts, run sentiment/volume/source analytics, or otherwise interact with their Octolens workspace. Prefer the Octolens MCP server when available; otherwise use the REST API v2.
license: MIT
metadata:
  author: octolens
  version: "2.0"
compatibility: Requires an Octolens account on a plan with API access (Pro, Scale, or Enterprise). MCP path needs an MCP-capable agent; REST path needs internet access.
---

# Octolens

Octolens is a social-listening platform. A workspace tracks **keywords** (phrases like a brand, competitor, or product). A pipeline collects matching posts — **mentions** — from Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky, Hacker News, GitHub, Stack Overflow, dev.to, news, podcasts, and the open web. Every mention is AI-scored for relevance, classified for sentiment, and given topic **tags**. Users save filter presets as **feeds**, which can drive Slack / email / webhook notifications.

There are two ways to work with Octolens. **Prefer the MCP server** — it is self-documenting, handles auth once, and exposes purpose-built tools. Fall back to the **REST API v2** for scripting, bulk export, or environments without MCP.

## Decision: MCP or REST?

- **MCP** — interactive agent work, ad-hoc questions, configuring keywords/feeds/alerts. Tools carry their own descriptions; you don't need this skill's endpoint catalog. → [Set up MCP](#option-a-mcp-preferred)
- **REST v2** — shell scripts, CI jobs, CSV/JSON export, or any agent without MCP. → [REST API v2](#option-b-rest-api-v2)

If the Octolens MCP tools are already connected (tool names start with `octolens` / `Octolens`), just use them — skip setup.

---

## Option A: MCP (preferred)

Install the Octolens MCP server (HTTP transport). For Claude Code:

```bash
claude mcp add --transport http octolens "https://app.octolens.com/api/mcp/v2"
```

On first use the server runs an OAuth flow in the browser — the user signs in to Octolens to authorize. No API key to manage. Other MCP clients (Cursor, Claude Desktop, etc.) take the same URL: `https://app.octolens.com/api/mcp/v2`.

Once connected, the server sends its own instructions and every tool is self-described. Typical tools: `list_mentions`, `get_mention`, `list_keywords` / `add_keyword` / `update_keyword` / `pause_keyword` / `delete_keyword`, `list_feeds` / `create_feed` / `update_feed`, `list_tags`, `get_workspace`, `get_usage`, `analytics`, `search_slack_channels`, `list_keyword_suggestions`. Read the tool descriptions — do not guess parameters.

**MCP gotchas**

- Write tools (`add_*`, `update_*`, `create_*`, `delete_*`, `pause_*`, `accept_*`, `reject_*`) mutate the live workspace. Gather every value from the user — never invent emails, URLs, Slack channels, frequencies, or exclude lists.
- To filter mentions by keyword you need numeric keyword **IDs** — resolve a name with `find_keyword` / `list_keywords` first.
- To wire a Slack alert: `search_slack_channels` (get channel IDs) → `create_feed` with a SLACK destination.

---

## Option B: REST API v2

Use this when MCP isn't available or you're scripting.

**Base URL:** `https://app.octolens.com/api/v2`
**Interactive docs:** `https://app.octolens.com/api/v2/docs` · **OpenAPI:** `https://app.octolens.com/api/v2/openapi.json`

### Authentication

Bearer token using an Octolens **API key** (created in the app under Settings → API; format `ak_...`). API keys are org-scoped and carry a scope:

| Scope | Grants |
|-------|--------|
| `read` (default) | All GET endpoints + read-style POSTs (list/export/analytics) |
| `write` | `read` + create/update/delete of keywords, feeds, feedback, mentions |
| `admin` | `write` + member management |

```bash
curl "https://app.octolens.com/api/v2/keywords" \
  -H "Authorization: Bearer $OCTOLENS_API_KEY"
```

**Always ask the user for their API key** before making calls; store it in an env var. Session/cookie auth is not supported on v2 — API key only.

### Conventions

- **Envelope:** successful reads return `{ "data": [...] }`; list endpoints add `{ "pagination": { "nextCursor": <string|null> } }`. Writes return the affected object or `{ "ok": true }` / `{ "success": true }`.
- **Pagination:** omit `cursor` for page one; pass the response's `pagination.nextCursor` back unchanged. `null` means no more pages.
- **Rate limit:** 500 requests/hour per org. Watch `X-RateLimit-Remaining` / `X-RateLimit-Reset`; on 429 honor `Retry-After`.
- **Errors:** non-2xx returns `{ "error": { "code", "message", "status", "details?" } }`. Codes include `UNAUTHORIZED` (401), `FORBIDDEN` (403, wrong scope / no API plan), `VALIDATION_ERROR` (400, with a `details` array), `*_NOT_FOUND` (404), `RATE_LIMITED` (429), `INTERNAL_ERROR` (500).

### Most-used endpoints

| Method & path | Purpose |
|---|---|
| `POST /mentions` | List/filter mentions (read; filters in body) |
| `POST /mentions/export` | Export up to 50k mentions as `json` or `csv` |
| `GET /mentions/{sourceId}` | Fetch one mention |
| `GET /mentions/by-author` | Mentions from one author (`?source=&handle=`) |
| `GET /keywords` · `POST /keywords` · `PATCH /keywords/{id}` · `DELETE /keywords/{id}` · `POST /keywords/{id}/pause` | Manage tracked keywords |
| `GET /tags` | Valid tag values for filtering |
| `GET /feeds` · `POST /feeds` · `GET/PATCH/DELETE /feeds/{id}` | Saved filters + notification destinations |
| `GET /analytics/volume` · `/sentiment` · `/sources` · `/keywords` | Aggregations (query-param filters) |
| `GET /org` · `/org/usage` · `/org/company` | Workspace info, quota, company profile |
| `POST /ai/filter-wizard` | Natural language → filter object |

Full request/response shapes for **every** endpoint are in **[references/REST-API.md](references/REST-API.md)** — read it on demand when you need a less-common endpoint or an exact field list.

### Listing mentions

`POST /api/v2/mentions` with a JSON body:

```json
{ "limit": 20, "filters": { "source": ["twitter"], "sentiment": ["positive"] } }
```

```bash
curl -X POST "https://app.octolens.com/api/v2/mentions" \
  -H "Authorization: Bearer $OCTOLENS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit":20,"filters":{"source":["reddit","github"],"!tag":["promotional_post"]}}'
```

Response: `{ "data": [Mention, ...], "pagination": { "nextCursor": "..." } }`. A `Mention` has `id` (numeric postId), `sourceId`, `url`, `title`, `body`, `source`, `timestamp`, `author`, `authorFollowers`, `relevance` (`relevant`/`not_relevant`), `sentiment` (`Positive`/`Neutral`/`Negative`/`null`), `language`, `tags[]`, `keywords[]` (`{id, keyword}`), `engaged`.

Other body fields: `view` (feed ID to reuse its saved filters — merges with inline `filters`), `includeAll` (default `false`; `true` also returns low-relevance posts), `cursor`.

## Mention filters

The `filters` object accepts two interchangeable shapes (identical to v1, so old filter bodies still work).

**Simple (flat map, AND-combined).** Prefix any array field with `!` to negate (NOT IN). Unknown keys are rejected with a 400.

| Field | Type | Values |
|-------|------|--------|
| `source` | string[] | `reddit`, `twitter`, `linkedin`, `youtube`, `tiktok`, `bluesky`, `hackernews`, `github`, `stackoverflow`, `dev`, `news`, `newsletter`, `podcasts`, `firehose` (open web), `producthunt`, `medium` |
| `sentiment` | string[] | `positive`, `neutral`, `negative` (lowercase in filters; returned Title-case) |
| `keyword` | number[] | Keyword **IDs** only (get from `GET /keywords`). Names are invalid. |
| `language` | string[] | ISO 639-1: `en`, `es`, `fr`, `de`, `pt`, `it`, `nl`, `ja`, `ko`, `zh` |
| `tag` | string[] | AI tag names (discover via `GET /tags`) |
| `relevance` | number[] | `0` high, `1` medium, `2` low |
| `minXFollowers` / `maxXFollowers` | number | Author X/Twitter follower bounds |
| `startDate` / `endDate` | string | ISO 8601, e.g. `2026-01-15T00:00:00Z` |

```json
{ "source": ["twitter"], "sentiment": ["positive"], "minXFollowers": 1000, "!keyword": [5, 6] }
```

**Advanced (AND/OR groups).** Top-level `operator` joins `groups`; each group's `operator` joins its `conditions`. Each condition is a one-key object (same field names as above). Date/follower bounds may also sit at the top level.

```json
{
  "operator": "AND",
  "groups": [
    { "operator": "OR",  "conditions": [ { "source": ["twitter"] }, { "source": ["linkedin"] } ] },
    { "operator": "AND", "conditions": [ { "sentiment": ["positive"] }, { "!tag": ["promotional_post"] } ] }
  ],
  "startDate": "2026-01-20T00:00:00Z"
}
```

To build a filter from plain English, POST the request to `/api/v2/ai/filter-wizard` (`{ "query": "negative tweets about pricing, last 7 days" }`) and reuse the returned object.

## Gotchas

- **`bookmarked` and `engaged` are not filter fields on v2** — they existed in v1 docs but were removed. Filters are `.strict()`: any unknown or stale key returns a 400, not a silent ignore. Don't carry them over.
- **`keyword` filter is ID-only.** A keyword *name* (even a valid one) returns a 400. Always resolve names via `GET /keywords` first.
- **Mention timestamps are Tinybird-style**: `YYYY-MM-DD HH:mm:ss.SSS` (UTC, no `Z`). When mutating a mention or posting feedback, copy the `timestamp` from the list response verbatim — it's part of the lookup key alongside `sourceId`/`postId`.
- **Sentiment case differs by direction**: filter with lowercase (`"positive"`), but mentions return Title-case (`"Positive"`).
- **Scope errors are 403, not 401.** A valid read-only key calling a write endpoint gets `FORBIDDEN` — mint a `write` key.
- **`platforms` on a keyword** is returned as a string array but several other places (and the create body) accept comma strings — check `references/REST-API.md` for the exact shape per endpoint.
- This skill ships **no scripts** — call the API directly with `curl` / `fetch`, or use MCP.

## Workflow

1. Decide MCP vs REST (above). If MCP tools are connected, use them.
2. For REST: confirm the API key; export it as `$OCTOLENS_API_KEY`.
3. If filtering by keyword, list keywords first to get IDs.
4. Build the smallest filter that answers the question; prefer simple mode, drop to advanced only for cross-field OR logic. Or use the filter wizard.
5. Execute; paginate with `nextCursor` only if the user needs more than one page.
6. Summarize insights (sentiment split, top sources/authors, trends) — don't just dump rows.
