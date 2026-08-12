---
name: octolens
description: Query and manage Octolens social-listening data — run one-time AI-scored searches, fetch brand mentions, and manage keywords, feeds, analytics, and notifications across Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky, Hacker News, GitHub, news, podcasts, and the open web. Use when the user wants to search for what people say about a brand right now, fetch or filter mentions, set up keyword tracking, configure Slack/email/webhook alerts, run sentiment/volume/source analytics, or otherwise interact with their Octolens workspace — including creating one from scratch with `octolens signup`. Two access paths are covered here: the `octolens` CLI for shell scripts, CI jobs, terminal work and bulk export (stable exit codes, pure `--json`, automatic retries), and the REST API v2 for raw programmatic access, non-Node environments, and anything the CLI does not cover.
license: MIT
metadata:
  author: octolens
  version: "4.0"
compatibility: Requires an Octolens account on a plan with API access (Agents, Pro, Scale, or Enterprise) — no account is fine too, `octolens signup` creates an Agents-plan workspace from the terminal. The CLI path needs Node.js 20+ and a shell; the REST path needs internet access.
---

# Octolens

Octolens is a social-listening platform. A workspace tracks **keywords** (phrases like a brand, competitor, or product). A pipeline collects matching posts — **mentions** — from Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky, Hacker News, GitHub, Stack Overflow, dev.to, news, podcasts, and the open web. Every mention is AI-scored for relevance, classified for sentiment, and given topic **tags**. Users save filter presets as **feeds**, which can drive Slack / email / webhook notifications. Alongside continuous monitoring there is **on-demand search**: `octolens search "phrase"` (or `POST /api/v2/search`) runs a one-time AI-scored search across the workspace's enabled platforms — results belong to the search and never join the mentions feed.

**Starting from zero?** The CLI creates the account too: `octolens signup` (browser handoff) or `octolens signup --headless` (email → emailed 6-digit code → company domain, fully scriptable, resumable two-step under `--json`) creates an **Agents-plan** workspace — 50 lifetime searches + 5,000 AI-scored mentions/month — and finishes with a stored, validated API key. When the allowance runs out the server answers `403 UPGRADE_REQUIRED` (CLI exit `6`) whose envelope carries `upgradeUrl` and `upgradeCommand`; `octolens upgrade` mints a single-use, already-authenticated link into the upgrade page.

This skill covers two ways to work with Octolens, and the right one depends on where you are running.

## Decision: CLI or REST?

| You are… | Use | Why |
|---|---|---|
| Writing a shell script, a CI job, a cron, or working in a terminal — anything where you branch on the result, plus bulk export | **CLI** | Stable exit codes, pure `--json`, automatic `Retry-After` retries, name→id resolution → [Option A](#option-a-cli-scripts-ci-and-the-terminal) |
| Calling from application code, a non-Node runtime, a box where you cannot install a binary, or reaching for something the CLI does not cover | **REST v2** | Raw HTTP, no dependencies, the full endpoint surface → [Option B](#option-b-rest-api-v2) |

**Prefer the CLI when you are in a shell.** It is a client of this same REST API, but it carries guarantees the raw endpoints do not: a frozen exit-code map you can branch on, one JSON document on stdout with the error envelope on stderr, automatic 429 retry honouring `Retry-After`, a per-request `--timeout`, response-shape validation, and a distinct `RESPONSE_LOST` code (exit `10`) that tells you a write may have landed so you verify instead of duplicating it. Reach for REST when you cannot install Node 20+, when you are calling from application code rather than a shell, or when you need an endpoint the CLI does not expose.

Octolens also offers an MCP server, whose tools carry their own descriptions — docs: <https://octolens.com/docs/mcp/v2/overview>.

---

## Option A: CLI (scripts, CI, and the terminal)

The `octolens` CLI is the terminal interface to the same workspace. Use it for shell scripts, CI jobs, cron, bulk export, and any automation that branches on whether an operation succeeded.

```bash
npm install -g octolens     # Node 20+; or run one-off with `npx octolens <cmd>`
```

### Authentication

```bash
export OCTOLENS_API_KEY=ak_...   # CI/scripts — create at https://app.octolens.com/me/api
octolens login                   # workstations — browser handoff, stores a profile
octolens whoami                  # confirms workspace, auth source, and key scope
```

An `OCTOLENS_API_KEY` in the environment outranks any stored profile. Scopes are the same API-key scopes as REST (`read` < `write` < `admin`).

**No account yet?** `octolens signup` creates the workspace and ends authenticated — browser handoff by default; `--headless` runs entirely in the terminal (resumable two-step under `--json`: `octolens signup --headless --email you@corp.com --json` sends the code, then `--signup-id … --code … --domain …` finishes and stores the key). An already-authenticated CLI is refused (`ALREADY_AUTHENTICATED`, exit `2`) — signup never mints a second workspace by accident.

### Search on demand

```bash
octolens search "your brand" --days 7 --json     # one-time AI-scored search, no keyword setup
```

`--days 1|7|30`, `--source reddit,twitter,…`, `--min-relevance high|medium|low`, `--max-results 1–500`. The CLI absorbs the async path (a long-running search is polled to completion), so stdout is always the completed envelope. Results never join the mentions feed. On the Agents plan searches draw on a lifetime allowance of 50 (plus 5,000 AI-scored mentions/month); at the wall the run exits `6` (`UPGRADE_REQUIRED`, with `upgradeUrl`/`upgradeCommand` in the envelope) and `octolens upgrade` opens the upgrade page already signed in.

### The `--json` contract

`--json` emits **exactly one** JSON document on stdout with no decoration; diagnostics and the error envelope (`{ "error": { "code", "message", "status" } }`) go to stderr. stdout is 0 bytes of noise, stderr is 0 bytes on success. `--json` also forces non-interactive mode — a `--json` run never prompts; missing input exits `2` naming the flag to pass. (The one exception: `feeds watch --json` streams NDJSON, one mention per line.)

### Exit codes — branch on these, never on message text

| | | | |
|---|---|---|---|
| `0` success | `3` auth | `6` plan/limit | `9` ran, but the operation failed at its target |
| `1` unexpected (retryable) | `4` not found | `7` rate-limited | `10` write accepted, answer lost — **verify, do not retry** |
| `2` usage | `5` permission/scope | `8` cancelled at a prompt | |

The two that catch people out: **exit `9`** means the command worked and the thing it asked for did not (a `notifications test` delivery Slack rejected; values the server refused on `filters add`) — re-running unchanged will fail again. **Exit `10` (`RESPONSE_LOST`)** means a state-changing request was accepted but its answer was lost; verify with the matching `list`/`get` before writing again, because retrying duplicates a landed write.

429s are retried automatically inside the request budget honouring `Retry-After`; exhausted retries exit `7` with `retryAfterSeconds` on the envelope when the server stated it. Every request runs under `--timeout` (default 30s), whose expiry exits `1` with `REQUEST_TIMEOUT`.

### High-value examples

```bash
# What are people saying about a brand RIGHT NOW — no keyword setup first
octolens search "acme corp" --days 7 --min-relevance high --json | jq -r '.mentions[].url'

# Filter by keyword NAME — no id lookup needed, unlike REST
octolens mentions list --keyword 'acme corp' --sentiment negative --since 2026-06-01 --json

# Bulk export, one call, no pagination loop
octolens mentions export --source reddit --since 2026-01-01 -o mentions.csv

# Branch on the outcome
octolens keywords add 'acme corp' --json
case $? in
  0)  ;;                                  # created
  10) octolens keywords list --json | jq -e '.data[] | select(.keyword=="acme corp")' ;;
  3)  echo "set OCTOLENS_API_KEY" >&2; exit 3 ;;
esac

# Wire a Slack alert end to end (42 / C0123ABCDEF = the id each step printed)
octolens feeds create --name "Negative Reddit" --source reddit --sentiment negative --json
octolens slack channels --search alerts --json
octolens notifications create --name "Neg Reddit to Slack" --feed 42 --slack C0123ABCDEF --frequency hourly --json

# Stream new mentions and act on each one
octolens feeds watch --backlog none --json | jq -r --unbuffered 'select(.type != "error") | .sourceId'
```

Command groups: `search`, `mentions`, `keywords`, `feeds`, `notifications`, `filters`, `suggestions`, `analytics`, `dashboard`, `tags`, `feedback`, `slack`, `members`, `org`, `company`, `billing`, plus `signup`/`login`/`logout`/`switch`/`whoami`/`upgrade`/`init`/`version`. `octolens help <group>` is always available.

Every command, flag, exit code and error code is in **[references/CLI.md](references/CLI.md)** — read it on demand for exact flag names, pagination rules, or the error taxonomy.

**CLI gotchas**

- Destructive commands (`keywords rm`, `feeds rm`, `notifications rm`, `members rm`, `feedback rm`) require `--yes` headless, otherwise exit `2`.
- `--limit` and `--all` are mutually exclusive on every list command (exit `2`, before any network call). On cursor-paginated lists (`mentions list`, `mentions by-author`, `slack channels`, org-wide `suggestions list`) passing **neither** returns just the first server page of 20 — pass `--limit N` or `--all` when you need a known quantity.
- `mentions engage` without `--engaged true|false` **toggles** — always pass the explicit value in automation.
- `analytics`/`dashboard` need `--since` and `--until` together; `mentions` accepts either alone.
- A read-scoped key hitting a write command exits `5`, not `3` — mint a `write` key rather than logging in again.
- `octolens search` exits `6` at the Agents-plan quota wall (`UPGRADE_REQUIRED`, envelope carries `upgradeUrl`/`upgradeCommand`) — recover with `octolens upgrade`, never by retrying. `octolens org usage --json` reports the remaining allowance (`searches: {used, limit, remaining}` on the Agents plan).

---

## Option B: REST API v2

Use this for raw programmatic access — application code, non-Node runtimes, or a box where you cannot install a binary.

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
- **Rate limit:** 500 requests/hour per org. Watch `X-RateLimit-Remaining` / `X-RateLimit-Reset`; on 429 honor `Retry-After`. The search routes additionally send remaining-quota headers on success — `X-Octolens-Mentions-Remaining` (all plans) and `X-Octolens-Searches-Remaining` (plans with a lifetime search cap, i.e. Agents) — so a client can self-throttle before hitting the quota wall.
- **Errors:** non-2xx returns `{ "error": { "code", "message", "status", "details?" } }`. Codes include `UNAUTHORIZED` (401), `FORBIDDEN` (403, wrong scope / no API plan), `VALIDATION_ERROR` (400, with a `details` array), `*_NOT_FOUND` (404), `RATE_LIMITED` (429), `INTERNAL_ERROR` (500). Additive per-code fields ride alongside the standard three: `UPGRADE_REQUIRED` (403 — an Agents-plan cap was hit) carries `upgradeUrl` and `upgradeCommand` (`octolens upgrade`); `QUOTA_EXCEEDED` (402) is the monthly mention quota on non-Agents plans.

### Most-used endpoints

| Method & path | Purpose |
|---|---|
| `POST /search` | Run a one-time AI-scored search (200 completed, or 202 + `pollUrl`) |
| `GET /search/{searchId}` | Poll a running search; `GET /search` lists past searches |
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

## Mention filters (REST)

The `filters` object accepts two interchangeable shapes (identical to v1, so old filter bodies still work). On the CLI these are expressed as repeatable flags (`--source`, `--keyword`, `--sentiment`, …) instead. Note that a **feed**'s stored filter uses a different grammar — see `references/REST-API.md` § Feeds, which is also what `octolens feeds create --filter-json` takes.

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

## REST gotchas

- **`bookmarked` and `engaged` are not filter fields on v2** — they existed in v1 docs but were removed. Filters are `.strict()`: any unknown or stale key returns a 400, not a silent ignore. Don't carry them over.
- **`keyword` filter is ID-only.** A keyword *name* (even a valid one) returns a 400. Always resolve names via `GET /keywords` first.
- **Mention timestamps are Tinybird-style**: `YYYY-MM-DD HH:mm:ss.SSS` (UTC, no `Z`). When mutating a mention or posting feedback, copy the `timestamp` from the list response verbatim — it's part of the lookup key alongside `sourceId`/`postId`.
- **Sentiment case differs by direction**: filter with lowercase (`"positive"`), but mentions return Title-case (`"Positive"`).
- **Scope errors are 403, not 401.** A valid read-only key calling a write endpoint gets `FORBIDDEN` — mint a `write` key.
- **`platforms` on a keyword** is returned as a string array but several other places (and the create body) accept comma strings — check `references/REST-API.md` for the exact shape per endpoint.
- This skill ships **no scripts** — use the `octolens` CLI, or call the API directly with `curl` / `fetch`.

## Workflow

1. Pick a path (above): the CLI if you're in a shell or a CI job, REST otherwise.
2. Confirm the credential: both paths need an API key in `$OCTOLENS_API_KEY` (CLI alternative: `octolens login`; no account at all → `octolens signup`, or `octolens signup --headless` from a bare shell). Verify with `octolens whoami` on the CLI path.
3. If filtering by keyword on REST, list keywords first to get IDs. The CLI resolves names for you.
4. Build the smallest filter that answers the question; prefer simple mode, drop to advanced only for cross-field OR logic. Or use the filter wizard (`POST /ai/filter-wizard`, or `octolens feeds create --ai "…"`).
5. Execute; paginate only if the user needs more than one page (REST: `nextCursor`; CLI: `--limit` / `--all`).
6. In scripts, branch on the CLI's exit code — never on message text — and treat exit `10` as "verify, don't retry".
7. Summarize insights (sentiment split, top sources/authors, trends) — don't just dump rows.
