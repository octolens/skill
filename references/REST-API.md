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

### `POST /mentions` — list mentions · *read*
Body: `view?` (feed ID), `filters?` (see SKILL.md "Mention filters"), `includeAll?` (default false), `limit?` (1–100, default 20), `cursor?`.
Returns `{ data: Mention[], pagination: { nextCursor } }`.

**Mention shape:** `id` (numeric postId), `sourceId`, `url`, `title|null`, `body|null`, `source`, `timestamp` (`YYYY-MM-DD HH:mm:ss.SSS`), `author|null`, `authorName|null`, `authorAvatar|null`, `authorUrl|null`, `authorFollowers|null`, `relevance` (`relevant`/`not_relevant`), `relevanceComment|null`, `sentiment` (`Positive`/`Neutral`/`Negative`/null), `language|null`, `tags[]`, `keywords[]` (`{id, keyword}`), `engaged`. Optional internal fields may appear: `relevanceScore`, `feedbackRelevant`, `imageUrl`, `keywordId`.

### `POST /mentions/export` — bulk export · *read*
Body = `/mentions` body + `format` (`json` | `csv`, default `json`). Up to 50,000 mentions.
- `json`: downloadable `{ data: Mention[], total }`.
- `csv`: 15 columns (id, sourceId, timestamp, source, url, title, body, author, authorFollowers, language, keywords, tags, relevance, sentiment, engaged).
- `X-Total-Count` header carries the total.

### `GET /mentions/{sourceId}` — one mention · *read*
Path: `sourceId` (e.g. `reddit_t3_1abc234`). Returns a single `Mention`.

### `PATCH /mentions/{sourceId}` — update a mention · *write*
Discriminated on `action`. Returns `{ ok: true }`.
- `{ action: "engage", postId, timestamp }` — toggle engaged flag.
- `{ action: "relevance", postId, relevance, timestamp }` — `relevance`: 0 high, 1 medium, 2 low, 3 clear/reset.
- `{ action: "sentiment", sentimentLabel, timestamp }` — `sentimentLabel`: `Positive`/`Neutral`/`Negative`.

`timestamp` must be copied verbatim from the list response (Tinybird-style; ISO 8601 also accepted).

### `GET /mentions/by-author` — author timeline · *read*
Query: `source` (required: twitter, reddit, bluesky, dev, github, hackernews, tiktok, linkedin), `handle?` (accepts `name`, `@name`, or URL), `profileUrl?` (LinkedIn: `in/<slug>` etc.), `limit?` (1–50, default 10), `cursor?`. Returns `{ data: Mention[], pagination }`.

---

## Keywords

A keyword's public shape: `id`, `keyword`, `context|null`, `additionalTerms|null`, `additionalTermsAndOr` (true=OR / false=AND), `caseSensitive`, `symbolSensitive`, `platforms` (string[]), `excludeWords|null`, `wildcardExcludeWords|null`, `excludeAuthors|null`, `tag|null` (`own_brand`/`competitor`/`industry_term`), `paused`, `isSubReddit|null`, `createdAt`, `updatedAt`.

### `GET /keywords` — list · *read*
Returns `{ data: Keyword[] }` (bounded, no pagination — typically <100).

### `POST /keywords` — create · *write*
Body: `keyword` (required, 1–100 chars), `context?` (≤200), `additionalTerms?` (≤500), `additionalTermsAndOr?` (default true), `caseSensitive?` (default false), `symbolSensitive?` (default true), `platforms?` (string[] of platform enums), `excludeWords?`, `wildcardExcludeWords?`, `excludeAuthors?`, `tag?`, `isSubReddit?`. Omitting AI-enriched fields lets Octolens auto-fill them. Returns the created `Keyword`.

### `PATCH /keywords/{id}` — update · *write*
Any subset of the create fields. Returns the updated `Keyword`.

### `DELETE /keywords/{id}` — delete · *write*
Returns `{ ok: true }`.

### `POST /keywords/{id}/pause` — toggle pause · *write*
Returns the updated `Keyword` (`paused` flipped).

---

## Keyword suggestions

AI-proposed refinements to keyword config (exclude words, extra terms, etc.).

### `GET /keywords/suggestions` — list · *read*
Query: `keywordId?` (narrow to one keyword), `withVolume?` (default true when no keywordId), `cursor?`, `limit?` (1–100, default 25; org-wide only).
Response varies:
- With `keywordId`: `{ keyword: {settings...}, suggestions: [...] }`.
- `withVolume: false`: `[{ keywordId, count }]`.
- default org-wide: `{ keywords: [{id, keyword, volume}], suggestions: [...], totalSuggestionCount, nextCursor }`.

Suggestion `type` ∈ `add_exclude_words`, `add_exclude_authors`, `add_additional_terms`, `change_additional_terms_logic`, `set_exact_match`, `disable_source`. Each has `value`, `reason`, `impact`, `impactScore`.

### `POST /keywords/suggestions` — accept · *write*
Body: `{ suggestionId, modifiedValue? }`. Returns `{ success: true, appliedChanges: {...} }`.

### `DELETE /keywords/suggestions` — reject · *write*
Body: `{ suggestionId }` (one) or `{ keywordId }` (all pending for that keyword). Returns `{ success: true }`.

---

## Feeds

A feed = a saved filter (view) + optional notification destinations.

**Feed shape:** `id`, `name`, `icon` (Heroicons name, e.g. `BellIcon`), `simpleFilters|null`, `advancedFilters|null`, `isDefault`, `destinations[]`, `createdAt`, `updatedAt`.

**Feed filter grammar** (distinct from the mentions `filters` body):
- `simpleFilters`: `{ conditions: [{ field, values }] }` — AND-combined. `field` ∈ `Keywords`, `Source`, `Sentiment`, `Relevance`, `Language`, `Tag`, `Author`, `Engaged`, `StartDate`, `EndDate`, `MinXFollowers`, `MaxXFollowers` (case-sensitive). `values` is a comma-separated string (keyword IDs for `Keywords`; uppercase enums for `Source`/`Sentiment`).
- `advancedFilters`: `{ top_level_operator: "AND"|"OR", groups: [{ group_operator, conditions: [{ field, operator, values }] }] }`. Condition `operator` ∈ `in`, `not in`, `equals`, `=`, `>=`, `<=`.

**Destination shape:** `type` (`EMAIL`/`SLACK`/`WEBHOOK`), `frequency` (`hourly`/`hourlyAtTopOfHour`/`daily`/`weekly`), `deliveryMode?` (`batch`/`individual`; webhooks always individual), `time?` (`HH:mm`), `timezone?` (IANA/UTC), `dayOfWeek?` (0=Sun–6=Sat, required for weekly), and one of:
- `emailDestination: { emails }` (comma-separated address list)
- `slackDestination: { channels, channelNamesMap? }` (`channels` = comma-separated channel IDs from `search_slack_channels` / `/integrations/slack/channels`)
- `webhookDestination: { url }`

### `GET /feeds` — list · *read*
Query: `excludeWithNotifications?`. Returns `{ data: Feed[] }`.

### `POST /feeds` — create · *write*
Body: `name` (required), `icon` (required), `simpleFilters?`, `advancedFilters?` (omit both for match-all), `destinations?`. Returns the created `Feed`.

### `GET /feeds/{id}` — fetch one · *read*

### `PATCH /feeds/{id}` — update · *write*
Partial; at least one field required. Passing `destinations` replaces the whole list (pass `[]` to clear; omit to leave unchanged).

### `DELETE /feeds/{id}` — delete · *write*
Returns `{ ok: true }`.

---

## Feedback (relevance training)

### `POST /feedback` — submit · *write*
Body: `sourceId`, `timestamp`, `postId`, `keywordId`, `source`, `feedbackType` (`RELEVANT`/`NOT_RELEVANT`), `feedbackReason?`, `feedbackSource?` (`WEB`/`SLACK`/`API`, default `API`), `originalRelevanceScore?`. Returns the created feedback row.

### `DELETE /feedback` — remove · *write*
Body: `{ sourceId, timestamp }`. Returns `{ success: true }`.

---

## Tags

### `GET /tags` — filterable tags · *read*
Returns `{ data: string[] }` — the union of tags this org's mentions carry plus a conventional fallback set, alphabetized. Use these values for the mentions `tag` filter.

---

## Analytics

All four take the same query-param filters: `startDate?` + `endDate?` (ISO 8601, both-or-neither; default last 30 days; max 365), `keywordIds?` (number | number[]), `platforms?` (string | string[]), `tag?`, `sentiment?` (`POSITIVE`/`NEUTRAL`/`NEGATIVE`), `relevance?` (0/1/2 or array; default `[0,1]`).

- `GET /analytics/volume` — `?granularity=day|hour` → `{ granularity, data: [{ bucket, count }] }`.
- `GET /analytics/sentiment` → `{ data: [{ sentiment, count }] }`.
- `GET /analytics/sources` → `{ data: [{ source, count }] }` (desc).
- `GET /analytics/keywords` → `{ data: [{ keywordId, keyword, count }] }` (desc; multi-keyword mentions counted per keyword).

---

## Organization

### `GET /org` — info · *read*
`{ organizationId, name, plan, isAnnualPlan, platforms, createdAt, onboardingFinishedAt, freeTrialExpired }`.

### `PATCH /org` — update · *write*
Body: `name?`, `platforms?` (`"all"` or string[]).

### `GET /org/usage` — quota · *read*
`{ plan, mentions: {count, limit, resetAt}, keywords: {count, limit}, flex?: {enabled, budgetCents, used, resetAt} }`.

### `GET /org/company` — company profile · *read*
`{ id, name, domain, website, logo, industry, sector, tags, description, linkedin, twitter, relevanceContext, productUseCases, competitors, companyMoat, relevanceGuidelines, classificationGuidelines }`.

### `PATCH /org/company` — update profile · *write*
Partial update of any company-profile field (drives AI relevance/classification).

### `GET /org/members` — list · *read*
`{ data: [{ id, userId, email, firstName, lastName, role, createdAt }] }`. `id` is the membership ID.

### `POST /org/members/invite` — invite · *admin*
Body: `{ email, role? }` (`admin`/`member`, default `member`).

### `DELETE /org/members/{id}` — remove · *admin*
Path = membership ID. Returns `{ id, removed: true }`. Fails `LAST_ADMIN` if removing the only admin.

---

## Filters (global)

### `GET /filters/global` — read · *read*
`{ negativeKeywords[], negativeAuthors[], negativeSubreddits[], positiveSubreddits[], negativeRepos[] }`.

### `PATCH /filters/global` — update · *write*
Partial (≥1 field). Pass `[]` to clear a list; omit to leave unchanged.

---

## AI & integrations

### `POST /ai/filter-wizard` — NL → filters · *read*
Body: `{ query }`. Returns `{ filters, isAdvanced, limit, includeAll, view, explanation }`. The `filters` object plugs straight into `POST /mentions`.

### `GET /integrations/slack/channels` — search Slack channels · *read*
Query: `q?` (substring on channel name), `cursor?`, `pages?` (1–10, default 2). Returns `{ data: [{ id, name }], pagination }`. Use the `id` values for a feed's `slackDestination.channels`.

---

## Utilities

- `GET /docs` — Scalar API docs (HTML, public).
- `GET /openapi.json` — OpenAPI 3.1 spec (public; the machine-readable source of truth — fetch it if anything here looks stale).

---

## Error codes

`{ "error": { "code", "message", "status", "details?" } }`

| Status | Codes |
|--------|-------|
| 400 | `VALIDATION_ERROR` (+`details` array), `KEYWORD_LIMIT_EXCEEDED`, `LAST_ADMIN`, `ITEM_EXISTS`, `INVALID_DOMAIN`, `INVALID_TIMEZONE` |
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN` (missing scope, or plan lacks API access) |
| 404 | `NOT_FOUND`, `FEED_NOT_FOUND`, `KEYWORD_NOT_FOUND`, `POST_NOT_FOUND`, `SUGGESTION_NOT_FOUND`, `COMPANY_NOT_FOUND`, `ORG_NOT_FOUND`, `SETTINGS_NOT_FOUND` |
| 429 | `RATE_LIMITED` (+`Retry-After`) |
| 500 | `INTERNAL_ERROR` |
