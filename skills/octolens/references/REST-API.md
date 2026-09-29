# Octolens REST API v2 — full endpoint reference

Read this when you need a less-common endpoint or an exact field list. The core
concepts (auth, filters, pagination, errors) and the common endpoints live in
`SKILL.md`; this file is the complete catalog.

- **Base URL:** `https://app.octolens.com/api/v2`
- **Auth:** `Authorization: Bearer <ak_...>` (org-scoped API key; scopes `read` < `write` < `admin`)
- **Live spec:** `GET /api/v2/openapi.json` · **Docs UI:** `GET /api/v2/docs`

Scope column below: the scope an API key needs. POSTs that only read (list/export/analytics/wizard) require `read`.

---

## Mentions

### `POST /mentions` — list mentions · _read_

Body: `view?` (feed ID), `filters?` (see SKILL.md "Mention filters"), `includeAll?` (default false), `includeEngagementMetrics?` (default false), `limit?` (1–100, default 20), `cursor?`.
Returns `{ data: Mention[], pagination: { nextCursor } }`.

Public engagement thresholds are source-scoped. Simple filters use
`engagement: [{ source: "twitter", metric: "likes", value: 100 }]` (`operator`
defaults to `>=`); advanced groups use a one-key
`{ engagement: { source, metric, operator, value } }` condition. Supported
numeric operators are `>=`, `<=`, `=`, and `equals`.

**Mention shape:** `id` (numeric postId), `sourceId`, `url`, `title|null`, `body|null`, `source`, `timestamp` (`YYYY-MM-DD HH:mm:ss.SSS`), `author|null`, `authorName|null`, `authorAvatar|null`, `authorUrl|null`, `authorFollowers|null`, `relevance` (`relevant`/`not_relevant`), `relevanceComment|null`, `sentiment` (`Positive`/`Neutral`/`Negative`/null), `language|null`, `tags[]`, `keywords[]` (`{id, keyword}`), `engaged`, and optional direct-review metadata as `review: { rating, ratingMax, verified, response, responseAt, targetName }`. With `includeEngagementMetrics: true`, also includes `engagementMetrics` (source-specific number map) and `engagementObservedAt|null`. Optional internal fields may appear: `relevanceScore`, `feedbackRelevant`, `imageUrl`, `keywordId`.
**Mention shape:** `id` (numeric postId), `sourceId`, `url`, `title|null`, `body|null`, `source`, `timestamp` (`YYYY-MM-DD HH:mm:ss.SSS`), `author|null`, `authorName|null`, `authorAvatar|null`, `authorUrl|null`, `authorFollowers|null`, `relevance` (`relevant`/`not_relevant`), `relevanceComment|null`, `sentiment` (`Positive`/`Neutral`/`Negative`/null), `language|null`, `tags[]`, `keywords[]` (`{id, keyword}`), `engaged`, `isReply` (`true` for a detected reply or comment on X, Reddit, Bluesky, or Hacker News). Legacy mentions read as `isReply: false` because there was no backfill. With `includeEngagementMetrics: true`, also includes `engagementMetrics` (source-specific number map) and `engagementObservedAt|null`. Optional internal fields may appear: `relevanceScore`, `feedbackRelevant`, `imageUrl`, `keywordId`.

### `POST /mentions/export` — bulk export · _read_

Body = `/mentions` body + `format` (`json` | `csv`, default `json`). Up to 50,000 mentions.

- `json`: downloadable `{ data: Mention[], total }`.
- `csv`: the original 15 columns (id, sourceId, timestamp, source, url, title, body, author, authorFollowers, language, keywords, tags, relevance, sentiment, engaged) remain the prefix. With `includeEngagementMetrics: true`, the established `engagementMetrics` and `engagementObservedAt` columns remain next. Flattened `reviewRating`, `reviewRatingMax`, `reviewVerified`, `reviewResponse`, `reviewResponseAt`, and `reviewTargetName` columns follow; ordinary mentions leave those cells blank.
- `X-Total-Count` header carries the total.

### `GET /mentions/{sourceId}` — one mention · _read_

Path: `sourceId` (e.g. `reddit_t3_1abc234`). Query: `includeEngagementMetrics?` (`true`/`false`). Returns a single `Mention`.

### `PATCH /mentions/{sourceId}` — update a mention · _write_

Discriminated on `action`. Returns `{ ok: true }`.

- `{ action: "engage", postId, timestamp }` — toggle engaged flag.
- `{ action: "relevance", postId, relevance, timestamp }` — `relevance`: 0 high, 1 medium, 2 low, 3 clear/reset.
- `{ action: "sentiment", sentimentLabel, timestamp }` — `sentimentLabel`: `Positive`/`Neutral`/`Negative`.

`timestamp` must be copied verbatim from the list response (Tinybird-style; ISO 8601 also accepted).

### `GET /mentions/by-author` — author timeline · _read_

Query: `source` (required: twitter, reddit, bluesky, dev, github, hackernews, tiktok, linkedin), `handle?` (accepts `name`, `@name`, or URL), `profileUrl?` (LinkedIn: `in/<slug>` etc.), `limit?` (1–50, default 10), `cursor?`, `includeEngagementMetrics?` (`true`/`false`). Returns `{ data: Mention[], pagination }`.

---

## Keywords

A keyword's public shape: `id`, `keyword`, `context|null`, `additionalTerms|null`, `additionalTermsAndOr` (true=OR / false=AND), `caseSensitive`, `symbolSensitive`, `platforms` (string[]), `excludeWords|null`, `wildcardExcludeWords|null`, `excludeAuthors|null`, `tag|null` (`own_brand`/`competitor`/`industry_term`), `paused`, `isSubReddit|null`, `createdAt`, `updatedAt`.

### `GET /keywords` — list · _read_

Returns `{ data: Keyword[] }` (bounded, no pagination — typically <100).

### `POST /keywords` — create · _write_

Body: `keyword` (required, 1–100 chars), `context?` (≤200), `additionalTerms?` (≤1,000 after CSV normalization), `additionalTermsAndOr?` (default true), `caseSensitive?` (default false), `symbolSensitive?` (default true), `platforms?` (string[] of platform enums), `excludeWords?` (≤5,000), `wildcardExcludeWords?` (≤5,000), `excludeAuthors?` (≤5,000), `tag?`, `isSubReddit?`. Omitting AI-enriched fields lets Octolens auto-fill them. Returns the created `Keyword`.

### `PATCH /keywords/{id}` — update · _write_

Any subset of the create fields. Returns the updated `Keyword`.

### `DELETE /keywords/{id}` — delete · _write_

Returns `{ ok: true }`.

### `POST /keywords/{id}/pause` — toggle pause · _write_

Returns the updated `Keyword` (`paused` flipped).

---

## Keyword suggestions

AI-proposed refinements to keyword config (exclude words, extra terms, etc.).

### `GET /keywords/suggestions` — list · _read_

Query: `keywordId?` (narrow to one keyword), `withVolume?` (default true when no keywordId), `cursor?`, `limit?` (1–100, default 25; org-wide only).
Response varies:

- With `keywordId`: `{ keyword: {settings...}, suggestions: [...] }`.
- `withVolume: false`: `[{ keywordId, count }]`.
- default org-wide: `{ keywords: [{id, keyword, volume}], suggestions: [...], totalSuggestionCount, nextCursor }`.

Suggestion `type` ∈ `add_exclude_words`, `add_exclude_authors`, `add_additional_terms`, `change_additional_terms_logic`, `set_exact_match`, `disable_source`. Each has `value`, `reason`, `impact`, `impactScore`.

### `POST /keywords/suggestions` — accept · _write_

Body: `{ suggestionId, modifiedValue? }`. Returns `{ success: true, appliedChanges: {...} }`.

### `DELETE /keywords/suggestions` — reject · _write_

Body: `{ suggestionId }` (one) or `{ keywordId }` (all pending for that keyword). Returns `{ success: true }`.

---

## Feeds

A feed = a saved filter (view) + optional notification destinations.

**Feed shape:** `id`, `name`, `icon` (Heroicons name, e.g. `BellIcon`), `simpleFilters|null`, `advancedFilters|null`, `isDefault`, `destinations[]`, `createdAt`, `updatedAt`.

**Feed filter grammar** (distinct from the mentions `filters` body):

- `simpleFilters`: `{ conditions: [{ field, values }] }` — AND-combined. The case-sensitive fields are `Keywords`, `Source`, `Sentiment`, `Language`, `Tags`, `RelevanceScore`, `Engaged`, `Bookmarked`, `IsReply`, `RelevantOnly`, `TimeRange`, `TwitterFollowerCount`, and the platform-specific engagement fields `Engagement.twitter.likes`, `Engagement.twitter.reposts`, `Engagement.twitter.replies`, `Engagement.twitter.quotes`, `Engagement.twitter.bookmarks`, `Engagement.twitter.views`. Most `values` are comma-separated (`Keywords` uses IDs, `Source` uses lowercase platform slugs, and `Sentiment` uses `Positive`/`Neutral`/`Negative`). `IsReply` takes exactly `1` (detected reply/comment on a supported threaded platform) or `0` (top-level or legacy row). A simple engagement field takes one non-negative integer and means “at least” (`>=`).
- `advancedFilters`: `{ top_level_operator: "AND"|"OR", groups: [{ group_operator, conditions: [{ field, operator, values }] }] }`. Condition `operator` ∈ `in`, `not in`, `equals`, `=`, `>=`, `<=`; `IsReply` accepts `in`, `not in`, `equals`, or `=` with values containing only `0`/`1`; engagement fields accept only the numeric operators `equals`, `=`, `>=`, `<=` and one non-negative integer value.
- A saved feed may contain at most 50 conditions total across its simple and advanced sides. Missing engagement counters do not match, including a threshold of zero.

**Destination shape:** `type` (`EMAIL`/`SLACK`/`WEBHOOK`), `frequency` (`hourly`/`hourlyAtTopOfHour`/`daily`/`weekly`), `deliveryMode?` (`batch`/`individual`; webhooks always individual), `time?` (`HH:mm`), `timezone?` (IANA/UTC), `dayOfWeek?` (0=Sun–6=Sat, required for weekly), and one of:

- `emailDestination: { emails }` (comma-separated address list)
- `slackDestination: { channels, channelNamesMap? }` (`channels` = comma-separated channel IDs from `search_slack_channels` / `/integrations/slack/channels`)
- `webhookDestination: { url }`

### `GET /feeds` — list · _read_

Query: `excludeWithNotifications?`. Returns `{ data: Feed[] }`.

### `POST /feeds` — create · _write_

Body: `name` (required), `icon` (required), `simpleFilters?`, `advancedFilters?` (omit both for match-all), `destinations?`. Returns the created `Feed`.

### `GET /feeds/{id}` — fetch one · _read_

### `PATCH /feeds/{id}` — update · _write_

Partial; at least one field required. Passing `destinations` replaces the whole list (pass `[]` to clear; omit to leave unchanged).

### `DELETE /feeds/{id}` — delete · _write_

Returns `{ ok: true }`.

---

## Feedback (relevance training)

### `POST /feedback` — submit · _write_

Body: `sourceId`, `timestamp`, `postId`, `keywordId`, `source`, `feedbackType` (`RELEVANT`/`NOT_RELEVANT`), `feedbackReason?`, `feedbackSource?` (`WEB`/`SLACK`/`API`, default `API`), `originalRelevanceScore?`. Returns the created feedback row.

### `DELETE /feedback` — remove · _write_

Body: `{ sourceId, timestamp }`. Returns `{ success: true }`.

---

## Tags

### `GET /tags` — filterable tags · _read_

Returns `{ data: string[] }` — the union of tags this org's mentions carry plus a conventional fallback set, alphabetized. Use these values for the mentions `tag` filter.

---

## On-demand search

One-time AI-scored searches across the workspace's enabled platforms. Results
belong to the search — they never appear in the mentions feed. **Every**
successful search-route response carries remaining-quota headers:
`X-Octolens-Mentions-Remaining` (all plans) and `X-Octolens-Searches-Remaining`
(plans with a lifetime search cap — the Agents plan: 50 lifetime searches,
5,000 AI-scored mentions/month). Self-throttle on them instead of slamming
into the wall.

### `POST /search` — run a search · _read_

Body: `query` (required), `timeWindow?` (`1d`/`7d`/`30d`, default `7d`), `sources?` (string[]), `maxResults?` (1–500, default 100), `minRelevance?` (`high`/`medium`/`low`), `waitMs?` (block up to 25s).
Blocks up to `waitMs`; returns **200** `{ status: "completed", searchId, query, mentions: [...], stats }` when it finishes in time, else **202** `{ status: "running", searchId, pollUrl, partialStats }` — poll `GET /search/{searchId}` (a `Retry-After: 2` header paces the loop). New results count against the monthly mention quota (`stats.mentionsConsumed`); results the workspace already collected are flagged `alreadyInWorkspace` and are free.
At a quota wall: **403 `UPGRADE_REQUIRED`** on the Agents plan — the envelope carries additive `upgradeUrl` and `upgradeCommand` fields (`octolens upgrade` mints a signed-in upgrade link) — or **402 `QUOTA_EXCEEDED`** on other plans (enable flex pricing or upgrade).

### `GET /search/{searchId}` — poll · _read_

`{ status: "running" | "completed" | "failed" | "quota_exhausted", ... }` — `completed` carries the full `mentions` + `stats`; `quota_exhausted` means the mention quota ran out mid-search (nothing billed for it).

### `GET /search` — list past searches · _read_

Paginated (`limit?`, `cursor?`): `{ data: [{ searchId, query, status, createdAt, stats? }], pagination: { nextCursor } }`.

---

## Attention ("Needs your attention")

The workspace's signals — the list the Home page shows. Seven rule kinds:
`no_keywords`, `no_destination`, `noisy_keyword`, `pending_suggestions`, `limit_risk`,
`delivery_broken`, `uncaught_relevant`; and four insight kinds detected in the workspace's
mention data: `mention_spike`, `high_reach_unanswered`, `tag_cluster`, `negative_rising`
(their `body` is a model-written one-liner, or a fixed template when the model is off).
Recomputed hourly (`:15`) and on demand when the store is older than 15 minutes. Feature
notes: `docs/attention-signals.md` in the repo.

### `GET /attention` — list · _read_

No parameters. Returns `{ data: AttentionItem[] }` — ranked (`score` desc), capped at 5,
minus the workspace's dismissals; `[]` is a valid answer.

`AttentionItem`: `id`, `kind`, `dedupeKey` (stable per subject — what a dismissal keys on),
`title`, `body`, `severity` (1–3), `score`, `source?` (platform badge for mention-backed
items), `action`, `payload?` (structured facts: `keywordId`, `suggestionIds`, …), `createdAt`,
`expiresAt?`.

`action` is ONE of: `{ type: "open", target: <in-app path>, label }` ·
`{ type: "apply", target: <write tool>, input, label }` — an approval-gated write-tool call;
**never run it without the user's confirmation** · `{ type: "ask", target: <prompt>, keywordIds?, label }` ·
`{ type: "skill", target: <session>, label }`.

### `POST /attention/{id}/dismiss` — dismiss / restore · _write_

Body: `{ dismissed: boolean }` — the TARGET state, never a toggle. `true` dismisses for the
**whole workspace** (keyed by `dedupeKey`, so the subject stays quiet across recomputes until
`suppressedUntil`; re-dismissing refreshes the window), `false` restores it.
Returns `{ id, kind, dedupeKey, dismissed, suppressedUntil }` — the committed state
(`suppressedUntil` null = never re-raised, or not dismissed). Idempotent and safe to retry.
Unknown or foreign id → 404 `ATTENTION_ITEM_NOT_FOUND`.

---

## Analytics

All four take the same query-param filters: `startDate?` + `endDate?` (ISO 8601, both-or-neither; default last 30 days; max 365), `keywordIds?` (number | number[]), `platforms?` (string | string[]), `tag?`, `sentiment?` (`POSITIVE`/`NEUTRAL`/`NEGATIVE`), `relevance?` (0/1/2 or array; default `[0,1]`).

- `GET /analytics/volume` — `?granularity=day|hour` → `{ granularity, data: [{ bucket, count }] }`.
- `GET /analytics/sentiment` → `{ data: [{ sentiment, count }] }`.
- `GET /analytics/sources` → `{ data: [{ source, count }] }` (desc).
- `GET /analytics/keywords` → `{ data: [{ keywordId, keyword, count }] }` (desc; multi-keyword mentions counted per keyword).

---

## Organization

### `GET /org` — info · _read_

`{ organizationId, name, plan, isAnnualPlan, platforms, createdAt, onboardingFinishedAt, freeTrialExpired }`.

### `PATCH /org` — update · _write_

Body: `name?`, `platforms?` (`"all"` or string[]).

### `GET /org/usage` — quota · _read_

`{ plan, mentions: {count, limit, resetAt}, keywords: {count, limit}, flex?: {enabled, budgetCents, used, resetAt}, searches?: {used, limit, remaining} }` — `searches` is present only on the Agents plan (the lifetime on-demand search allowance; it never resets).

### `POST /org/upgrade-link` — authenticated upgrade link · _write_

`{ url, destination, plan, expiresAt, expiresInSeconds }` — a single-use, short-lived (10 min) Clerk-ticket deep link that opens the upgrade page **already signed in** (works for workspaces that never had a browser session). Plan-aware: Agents → the upgrade page, other plans → the billing page. This is what `octolens upgrade` calls.

### `GET /org/company` — company profile · _read_

`{ id, name, domain, website, logo, industry, sector, tags, description, linkedin, twitter, relevanceContext, productUseCases, competitors, companyMoat, relevanceGuidelines, classificationGuidelines }`.

### `PATCH /org/company` — update profile · _write_

Partial update of any company-profile field (drives AI relevance/classification).

### `GET /org/members` — list · _read_

`{ data: [{ id, userId, email, firstName, lastName, role, createdAt }] }`. `id` is the membership ID.

### `POST /org/members/invite` — invite · _admin_

Body: `{ email, role? }` (`admin`/`member`, default `member`).

### `DELETE /org/members/{id}` — remove · _admin_

Path = membership ID. Returns `{ id, removed: true }`. Fails `LAST_ADMIN` if removing the only admin.

---

## Filters (global)

### `GET /filters/global` — read · _read_

`{ negativeKeywords[], negativeAuthors[], negativeSubreddits[], positiveSubreddits[], negativeRepos[] }`.

### `PATCH /filters/global` — update · _write_

Partial (≥1 field). Pass `[]` to clear a list; omit to leave unchanged.

---

## AI & integrations

### `POST /ai/filter-wizard` — NL → filters · _read_

Body: `{ query }`. Returns `{ filters, isAdvanced, limit, includeAll, view, explanation }`. The `filters` object plugs straight into `POST /mentions`.

### `GET /integrations/slack/channels` — search Slack channels · _read_

Query: `q?` (substring on channel name), `cursor?`, `pages?` (1–10, default 2). Returns `{ data: [{ id, name }], pagination }`. Use the `id` values for a feed's `slackDestination.channels`.

---

## Utilities

- `GET /docs` — Scalar API docs (HTML, public).
- `GET /openapi.json` — OpenAPI 3.1 spec (public; the machine-readable source of truth — fetch it if anything here looks stale).

---

## Error codes

`{ "error": { "code", "message", "status", "details?" } }`

| Status | Codes                                                                                                                                                                        |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 400    | `VALIDATION_ERROR` (+`details` array), `KEYWORD_LIMIT_EXCEEDED`, `LAST_ADMIN`, `ITEM_EXISTS`, `INVALID_DOMAIN`, `INVALID_TIMEZONE`                                           |
| 401    | `UNAUTHORIZED`                                                                                                                                                               |
| 402    | `QUOTA_EXCEEDED` (monthly mention quota, non-Agents plans)                                                                                                                   |
| 403    | `FORBIDDEN` (missing scope, or plan lacks API access), `UPGRADE_REQUIRED` (Agents-plan cap — envelope adds `upgradeUrl` + `upgradeCommand`)                                  |
| 404    | `NOT_FOUND`, `FEED_NOT_FOUND`, `KEYWORD_NOT_FOUND`, `POST_NOT_FOUND`, `SEARCH_NOT_FOUND`, `SUGGESTION_NOT_FOUND`, `COMPANY_NOT_FOUND`, `ORG_NOT_FOUND`, `SETTINGS_NOT_FOUND`, `ATTENTION_ITEM_NOT_FOUND` |
| 429    | `RATE_LIMITED` (+`Retry-After`)                                                                                                                                              |
| 500    | `INTERNAL_ERROR`                                                                                                                                                             |

Additive per-code envelope fields (`upgradeUrl`/`upgradeCommand` on `UPGRADE_REQUIRED`, `details` on `VALIDATION_ERROR`) ride **inside** `error`, alongside the always-present `code`/`message`/`status`.
