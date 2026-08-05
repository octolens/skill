# Octolens CLI — full command and contract reference

Read this when you need an exact flag name, the meaning of an exit code, or the
retry/timeout semantics. The routing decision (CLI vs REST) and the short version
of the CLI contract live in `SKILL.md`; this file is the complete catalog.

- **Package:** `octolens` on npm · **Binary:** `octolens` · **Node:** ≥ 20
- **Backend:** the public REST API v2 at `https://app.octolens.com` (the CLI is a
  client of the same API documented in `references/REST-API.md` — same plans,
  same scopes, same rate limit)
- **Derived from:** the `octolens@0.1.0` contract manifest — 75 commands
  (62 visible, the rest alias spellings), 11 exit codes, and 104 error codes of
  which 91 can reach this build

---

## Install

```bash
npm install -g octolens     # then: octolens <command>
npx octolens mentions list  # or run it without installing
```

`octolens autocomplete` installs shell completions (zsh, bash, fish, powershell).

## Authenticate

Two credentials, one precedence rule: **an `OCTOLENS_API_KEY` in the environment
wins over any stored profile.**

```bash
# CI / scripts / containers — no interactive step, nothing written to disk
export OCTOLENS_API_KEY=ak_...      # create at https://app.octolens.com/me/api

# Workstations — browser handoff mints a key and stores a profile
octolens login                      # --scope read|write|admin (default write)
octolens login --with-key           # masked paste prompt instead of the browser
octolens login --with-key ak_...    # non-interactive
octolens login --no-browser         # print the authorize URL, wait out of band
```

Profiles live in `~/.config/octolens/config.json` (override the directory with
`OCTOLENS_CONFIG_DIR`, or the XDG base with `XDG_CONFIG_HOME`). `octolens switch
<profile>` changes the active one, `octolens logout [--profile <name>|--all]`
removes stored ones — it cannot remove an env key, unset the variable for that.

The base URL a login verified against is **persisted with the profile**, so later
commands need no extra flag. An env `OCTOLENS_API_KEY` replaces the profile's
key, never its pinned deployment; only `--base-url` / `OCTOLENS_BASE_URL`
retargets a run.

`octolens whoami` reports the active workspace, the auth source (`env` vs
`profile`) and the key's scope — the cheapest preflight in a script.

**Scopes are the API-key scopes** (`read` < `write` < `admin`). A read key
calling a write command fails with `FORBIDDEN` / exit `5`, not `3`.

### Environment variables

| Variable | Effect |
|---|---|
| `OCTOLENS_API_KEY` | API key for the run. Outranks any stored profile. Whitespace-only is treated as absent. |
| `OCTOLENS_BASE_URL` | Same as `--base-url`. Defaults to `https://app.octolens.com`. |
| `OCTOLENS_DEBUG=1` | Same as `--verbose`. |
| `OCTOLENS_CONFIG_DIR` | Directory holding `config.json` (default `~/.config/octolens`). |

---

## Global flags

Accepted by every command.

| Flag | Type | Description |
|---|---|---|
| `--json` | boolean | Pure machine-readable JSON on stdout, no decoration. Also forces non-interactive mode. |
| `--timeout <seconds>` | integer | Per-request deadline (default 30s). See "Retries and timeouts". |
| `--verbose` | boolean | Diagnostics on stderr: one line per REST request (method, path, status, duration) plus retry/backoff events. |
| `--base-url <url>` | string | Override the app base URL. Feeds the REST base, `--web` pages and OAuth handoffs alike. |
| `--web` | boolean | Open this resource's page in the web app instead of running the command. Always prints the URL; a browser spawns only on a TTY without `--json`. Commands with no page (e.g. `version`, the auth commands) exit `2` with `NO_WEB_PAGE`. |
| `--transport rest` | enum | Forces the public REST v2 backend — the only transport the CLI has, so you never need to pass it. |

---

## The agent contract

### `--json`

`--json` emits **exactly one** machine-readable JSON document on stdout with no
decoration. Progress and diagnostics go to stderr. The one declared exception is
the long-lived stream command `feeds watch`, which emits **NDJSON** — one JSON
document per line.

`--json` also forces non-interactive mode: a prompt opens only when stdin *and*
stdout are both a terminal **and** `--json` was not passed. So a `--json` run
never prompts and never exits `8`; missing input exits `2` naming the flags to
pass instead.

stdout stays pure in both modes. In `--json` mode every stderr line is itself a
parseable JSON object, so `2>err.json && jq < err.json` always works. The
exception is the opt-in `--verbose` / `OCTOLENS_DEBUG=1` diagnostic stream, which
deliberately reads like `curl -v`.

### Exit codes

Exit codes are **frozen**. Branch on the code (and on the error envelope's
`code`), never on message text.

| Code | Name | Meaning |
|---|---|---|
| `0` | `OK` | success |
| `1` | `UNEXPECTED` | unexpected — the documented **retryable** exit |
| `2` | `USAGE` | usage: bad flags, bad values, missing required input |
| `3` | `AUTH` | auth |
| `4` | `NOT_FOUND` | not found |
| `5` | `PERMISSION` | permission / scope |
| `6` | `LIMIT` | plan / limit |
| `7` | `RATE_LIMITED` | rate-limited |
| `8` | `CANCELLED` | cancelled — a human aborted a prompt with EOF/Ctrl-C |
| `9` | `FAILED` | the command ran and the operation did not succeed at its target |
| `10` | `INDETERMINATE` | a write was accepted and its answer lost — **verify, do not retry** |

Exit `9` is worth its own note: the command itself worked, the *thing it asked
for* did not. `notifications test` exits `9` when a real delivery to Slack or a
webhook endpoint fails (`NOTIFICATION_TEST_FAILED`,
`NOTIFICATION_TEST_PARTIAL_FAILURE`), and `filters add` exits `9` when the server
refused some or all values (`FILTERS_ADD_REFUSED`,
`FILTERS_ADD_PARTIALLY_REFUSED`). Neither is a usage bug and neither is retryable
as-is.

### The error envelope

Every failure renders exactly one envelope, on **stderr**:

```json
{ "error": { "code": "RATE_LIMITED", "message": "…", "status": 429 } }
```

Those three fields are the contract and are always present. Anything else is
additive and per-code: `retryAfterSeconds` and `resetAt` ride on `RATE_LIMITED`
(exit `7`) **only when the server stated them** — their absence means "not
stated", never "retry now". Read extra fields only after branching on `code`, and
never require them.

Without `--json` the same failure prints `Error [CODE]: message`.

### Retries and timeouts

Every request runs under a per-operation deadline — **30s by default**, overridden
uniformly by the global `--timeout <seconds>`. When it expires the request is
aborted and the run exits `1` with a `REQUEST_TIMEOUT` (status 504) envelope
naming the operation and the deployment that never answered. It never blocks
indefinitely with empty output.

`429` responses are retried automatically **inside that same budget**, honouring
`Retry-After` with exponential backoff capped at 30 000 ms. A wait that exceeds
the cap or the time remaining in the budget is not slept off: the run surfaces
`RATE_LIMITED` (exit `7`) with the `Retry-After` intact so you can reschedule.
The budget is absolute across retries, not per attempt.

Per-operation defaults are longer where the work genuinely is: `mentions export`,
the AI filter wizard (`feeds create --ai`), `keywords add` and `suggestions
accept` (LLM round-trips), and `notifications test` (a real third-party delivery).
Passing `--timeout` overrides all of them uniformly, longer ones included. A bad
value (`0`, `2.5`, `abc`, `> 3600`) exits `2` with `INVALID_TIMEOUT` before any
transport is chosen.

`login`'s out-of-band browser-handoff wait is governed by the same budget
(default 180s there); its expiry exits `2` with `LOGIN_TIMEOUT`, so a headless
`login --no-browser` always terminates on its own. `slack connect --timeout` is a
different flag with a different meaning — how long to wait for the OAuth flow
(default 120s; `0` means "just open the URL and return").

### `RESPONSE_LOST` — the indeterminate write

**The one case an automated caller must branch on.** A state-changing request
whose `2xx` status line arrived but whose response body was lost answers
`RESPONSE_LOST` (status 502, **exit `10`**): the server accepted the write and
the outcome is unknown.

Verify with the matching `list` / `get` before writing again — **do not retry**.
Exit `1` is the documented retryable exit and this deliberately is not it,
because retrying a landed write duplicates it.

```bash
octolens keywords add "acme corp" --json
case $? in
  0)  ;;                                        # created
  10) octolens keywords list --json | jq -e '.data[] | select(.keyword=="acme corp")' ;;
  *)  exit $? ;;
esac
```

### The auth preflight

Credentials are resolved per run. The **no-usable-credential family** —
`MISSING_API_KEY`, `NOT_LOGGED_IN`, `NO_CREDENTIALS`, `NO_PROFILES` — all exit
`3`. Test **membership of the family** (or simply `exit === 3`) to decide "do I
need to authenticate?", then read the specific member for the remedy. Which
member you get depends on the command — `whoami` answers `NOT_LOGGED_IN` where a
data command answers `NO_CREDENTIALS` for the identical state — so never branch on
a single member.

`CONFLICTING_CREDENTIALS`, `INVALID_API_KEY`, `MISSING_PROFILE`,
`NO_STORED_PROFILE` and `UNAUTHORIZED` are deliberately **not** in the family: a
credential exists and something else is wrong with it, so a login loop is the
wrong recovery.

---

## Pagination

Defined once, applied by every list command.

- Every list command's `--json` carries `pagination.nextCursor` (`null` when the
  collection is exhausted).
- Every list command takes the same two flags: `--limit <n>` and `--all`. They
  are **mutually exclusive** — combining them exits `2` (`CONFLICTING_FLAGS`)
  before any API call. `--limit 0`, a negative value or a non-integer also exits
  `2` (`INVALID_LIMIT` / `USAGE_ERROR`).
- **Cursor-paginated lists** — `mentions list`, `mentions by-author`,
  `suggestions list` (org-wide), `slack channels`: `--limit N` returns the first
  N items across as few pages as possible and `--all` drains every page.
  **Passing neither returns one server page — 20 items** — so always pass one of
  them when you need a known quantity.
- **Bounded lists** — `keywords list`, `feeds list`, `tags list`, `members list`,
  `members invitations`, `notifications list`, `suggestions list --keyword <kw>`:
  the full collection comes back in one response and `nextCursor` is always
  `null`. There the flags are a client-side head of that complete result, and
  passing neither returns everything.
- `nextCursor` is a **signal, not an input** — there is no `--cursor` flag. Re-run
  with a larger `--limit`, or use `--all`.

---

## Commands

62 visible commands. On every destructive command `rm`, `remove` and `delete` are
interchangeable aliases (`feeds delete` = `feeds remove` = `feeds rm`); only one
spelling per command is listed below.

Flag markers: `!` required · `^` required headless (`--json` or no TTY; an
interactive run prompts instead) · `~` at least one flag of that group is
required headless. `<n>` is an integer, `<v>` a string, `<a|b>` an enum.

#### `analytics`

- **`octolens analytics keywords`** — Per-keyword mention volume (bar chart), highest first
  Flags: `--keyword <v>` · `--since <v>` · `--until <v>`
  Exits: 0, 1, 2, 4
- **`octolens analytics sentiment`** — Sentiment split (Positive/Neutral/Negative/unknown)
  Flags: `--keyword <v>` · `--since <v>` · `--until <v>`
  Exits: 0, 1, 2, 4
- **`octolens analytics sources`** — Per-platform mention volume (bar chart), highest first
  Flags: `--keyword <v>` · `--since <v>` · `--until <v>`
  Exits: 0, 1, 2, 4
- **`octolens analytics volume`** — Mention volume over time (sparkline + per-bucket counts)
  Flags: `--granularity <day|hour>` · `--keyword <v>` · `--since <v>` · `--until <v>`
  Exits: 0, 1, 2, 4

`--since` and `--until` must be passed **together** (omit both for the last 30
days); one alone exits `2` with `INCOMPLETE_WINDOW`. `--keyword` filters the
*posts*, not the output rows — `analytics keywords --keyword X` returns every
keyword co-mentioned on X's posts.

#### `autocomplete`

- **`octolens autocomplete [SHELL]`** — Install shell completions (zsh, bash, fish, powershell)
  Flags: `--refresh-cache`
  Exits: 0, 1, 2
- **`octolens autocomplete fish`** — Print fish shell completions
  Exits: 0, 1, 2

#### `billing`

- **`octolens billing`** — Show your plan + usage; `--web` opens the subscription page in the browser
  Exits: 0, 1, 2

#### `company`

- **`octolens company get`** — Show the monitored company profile
  Exits: 0, 1, 2
- **`octolens company update`** — Update the monitored company profile (name, description, AI guidelines)
  Flags: `--classification-guidelines <v>` · `--company-moat <v>` · `--competitors <v>` · `--description <v>` · `--linkedin <v>` · `--logo <v>` · `--name <v>` · `--product-use-cases <v>` · `--relevance-context <v>` · `--relevance-guidelines <v>` · `--twitter <v>`
  Exits: 0, 1, 2

The company profile drives AI relevance and classification. `--relevance-context`
(≤400 chars) is the highest-leverage field: it disambiguates the brand for every
relevance prompt. An update with no fields exits `2` (`NOTHING_TO_UPDATE`).

#### `dashboard`

- **`octolens dashboard`** — Composite KPI overview: volume trend, top keywords, sentiment split, usage vs plan
  Flags: `--keyword <v>` · `--since <v>` · `--until <v>`
  Exits: 0, 1, 2, 4

#### `feedback`

- **`octolens feedback rm <SOURCEID>`** — Remove the relevance feedback on a mention
  Flags: `--force` · `--yes`^
  Exits: 0, 1, 2, 8
- **`octolens feedback stats`** — Show aggregated relevance-feedback stats (org-wide or per-keyword)
  Flags: `--keyword <n>`
  Exits: 0, 1, 2
- **`octolens feedback submit <SOURCEID>`** — Submit relevance feedback on a mention (thumbs up/down)
  Flags: `--keyword <n>` · `--not-relevant`~ · `--reason <v>` · `--relevant`~
  Exits: 0, 1, 2

#### `feeds`

- **`octolens feeds create`** — Create a feed from a filter (flags, `--filter-json`, or `--ai`)
  Flags: `--ai <v>` · `--filter-json <v>` · `--icon <v>` · `--keyword <v>` · `--name <v>`^ · `--sentiment <v>` · `--source <v>` · `--yes`
  Exits: 0, 1, 2, 8
- **`octolens feeds get <ID>`** — Get a single feed by id (pretty-prints its filter)
  Exits: 0, 1, 2
- **`octolens feeds list`** — List your saved feeds
  Flags: `--all` · `--exclude-with-notifications` · `--limit <n>`
  Exits: 0, 1, 2
- **`octolens feeds rm <ID>`** — Delete a feed by id
  Flags: `--force` · `--yes`^
  Exits: 0, 1, 2, 8
- **`octolens feeds update <ID>`** — Update a feed's name, icon, and/or filter
  Flags: `--ai <v>` · `--filter-json <v>` · `--icon <v>` · `--keyword <v>` · `--name <v>` · `--sentiment <v>` · `--source <v>` · `--yes`
  Exits: 0, 1, 2, 8
- **`octolens feeds watch`** — Live-watch your feed with keyboard triage (polling live view)
  Flags: `--backlog <all|none>` · `--feed <n>` · `--interval <v>` · `--keyword <v>` · `--relevance <relevant|all>` · `--sentiment <v>` · `--source <v>`
  Exits: 0, 1, 2

Three ways to express a feed's filter, mutually exclusive: the ergonomic flags
(`--source`/`--keyword`/`--sentiment`, repeatable), `--filter-json` for full
fidelity (a simple `{ conditions: [...] }` or an advanced
`{ top_level_operator, groups: [...] }` — see `references/REST-API.md` § Feeds),
or `--ai "<plain English>"` to let the filter wizard build it. `--ai` previews and
confirms on a TTY; headless (or with `--yes`) it applies directly. `--icon` takes
a Heroicons name and defaults to `BellIcon`.

**`feeds watch` is a stream.** The first poll emits the current first page (the
~20 newest existing mentions) as if they had just arrived; every later poll emits
only mentions newer than the newest already shown. Pass `--backlog none` for a
tail-only stream — the right choice when an agent *acts* on each line. Under
`--json` it emits NDJSON, one Mention document per line, forever; `--interval` is
seconds (default 15, minimum 2). If the stream dies on a fatal error after
emitting mentions the **last** line is a `{"type":"error","error":{…},"emitted":N,
"watermark":…}` record (the same envelope also goes to stderr, with the mapped
non-zero exit code) — every other line has no `type` field and is a Mention. A
transient poll failure emits one `{"event":"poll_failed","error":{…},"retryInMs":N}`
object on stderr and keeps going, so a non-empty stderr here does not imply
failure: branch on the exit code.

#### `filters`

- **`octolens filters add <LIST> [VALUE…]`** — Add value(s) to a global filter list (skips duplicates)
  Exits: 0, 1, 2, 9
- **`octolens filters get`** — Show your org-wide filter lists (all, or one with `--list`)
  Flags: `--list <v>`
  Exits: 0, 1, 2
- **`octolens filters remove <LIST> [VALUE…]`** — Remove value(s) from a global filter list
  Flags: `--force` · `--yes`
  Exits: 0, 1, 2, 8
- **`octolens filters set <LIST> [VALUE…]`** — Replace a global filter list wholesale (no values + `--clear` = empty it)
  Flags: `--clear` · `--values-json <v>`
  Exits: 0, 1, 2, 8

`<LIST>` is one of `negativeKeywords`, `negativeAuthors`, `negativeSubreddits`,
`positiveSubreddits`, `negativeRepos`; anything else exits `2`
(`UNKNOWN_FILTER_LIST`). `filters set --values-json '["a b","c,d"]'` is the way to
pass values containing spaces or commas. Emptying a non-empty list headlessly
requires `--clear` (`filters set`) or `--yes` (`filters remove`), otherwise
`CLEAR_NOT_CONFIRMED`.

#### `help`

- **`octolens help [COMMAND]`** — Show help for the CLI, a command group, or a single command
  Exits: 0, 1, 2

`help --json` is the one place `--json` is refused: it exits `2` with
`JSON_NOT_SUPPORTED` and writes nothing to stdout, rather than emitting prose onto
a stdout a caller promised itself was JSON.

#### `init`

- **`octolens init`** — Guided onboarding: company profile, keywords, filters, and your first feed
  Exits: 0, 1, 2, 8

Headless (`--json`, or no TTY) `init` never prompts: it reports the onboarding
plan and exits `0` **whether or not steps remain**. Read `fullyOnboarded` and
`steps[].done` — never the exit code — to know what is left.

#### `keywords`

- **`octolens keywords add [TERM]`** — Start monitoring a new keyword (interactive on a TTY)
  Flags: `--additional-terms <v>` · `--allow-duplicate` · `--context <v>` · `--exclude-words <v>` · `--source <v>` · `--sources <v>` · `--tag <v>` · `--term <v>`^
  Exits: 0, 1, 2, 4, 8
- **`octolens keywords list`** — List your tracked keywords with status and mention volume
  Flags: `--all` · `--limit <n>` · `--volume`
  Exits: 0, 1, 2, 4
- **`octolens keywords pause <KEYWORD>`** — Pause data collection for a keyword (idempotent)
  Exits: 0, 1, 2, 4
- **`octolens keywords resume <KEYWORD>`** — Resume data collection for a keyword (idempotent)
  Exits: 0, 1, 2, 4
- **`octolens keywords rm <KEYWORD>`** — Delete a keyword (confirms on a TTY; `--yes` headless)
  Flags: `--force` · `--yes`^
  Exits: 0, 1, 2, 4, 8
- **`octolens keywords update <KEYWORD>`** — Update a keyword's matching config (by id or name)
  Flags: `--additional-terms <v>` · `--additional-terms-or` · `--case-sensitive` · `--context <v>` · `--exact-match` · `--exclude-authors <v>` · `--exclude-words <v>` · `--source <v>` · `--sources <v>` · `--tag <v>` · `--wildcard-exclude-words <v>`
  Exits: 0, 1, 2, 4

Unlike the REST API, **`<KEYWORD>` accepts a name or an id** — the CLI resolves
names for you. An unresolvable name exits `4` (`KEYWORD_NOT_FOUND`); a name
matching several keywords exits `2` (`AMBIGUOUS_KEYWORD`), so pass the id.
`keywords add` takes the term positionally or as `--term`; headless one of the two
is required. Adding an already-tracked term is a **no-op that returns the existing
keyword**; pass `--allow-duplicate` to force a second one. `--tag` is one of
`own_brand`, `competitor`, `industry_term`. `keywords list --no-volume` skips the
analytics aggregation and is much faster. On `keywords update`, an empty string
clears a comma-separated field.

#### `login` / `logout` / `switch` / `whoami`

- **`octolens login [KEY]`** — Authenticate the CLI (browser handoff or API key)
  Flags: `--no-browser` · `--profile <v>` · `--scope <read|write|admin>` · `--with-key`
  Exits: 0, 1, 2, 8
- **`octolens logout`** — Remove stored login credentials
  Flags: `--all` · `--profile <v>`
  Exits: 0, 1, 2
- **`octolens switch [PROFILE]`** — Switch the active workspace profile
  Exits: 0, 1, 2, 3, 4, 8
- **`octolens whoami`** — Show the active login: workspace, auth source (env vs profile), and scope
  Exits: 0, 1, 2, 3

A valueless `--with-key` opens a masked paste prompt on a TTY; headless it exits
`2` (`MISSING_KEY_VALUE`) telling you to pass the value inline or set
`OCTOLENS_API_KEY`. A bare `login` headless exits `2`
(`BROWSER_LOGIN_REQUIRES_TTY`) — in CI, set the env var instead of logging in.

#### `members`

- **`octolens members invitations`** — List invitations that haven't been accepted yet
  Flags: `--all` · `--limit <n>`
  Exits: 0, 1, 2
- **`octolens members invite`** — Invite a member by email (admin only)
  Flags: `--email <v>`^ · `--role <admin|member>`
  Exits: 0, 1, 2, 5, 8
- **`octolens members list`** — List the organization's members
  Flags: `--all` · `--limit <n>`
  Exits: 0, 1, 2
- **`octolens members rm <MEMBER>`** — Remove a member or revoke a pending invitation (admin only)
  Flags: `--force` · `--yes`^
  Exits: 0, 1, 2, 4, 5, 8

Both writes need an `admin`-scoped key — a `write` key exits `5`
(`ADMIN_SCOPE_REQUIRED`). `members rm` covers pending invitations as well as
accepted members; an ambiguous identifier exits `2` (`AMBIGUOUS_MEMBER`).

#### `mentions`

- **`octolens mentions by-author [AUTHOR]`** — List an author's mentions on a single platform
  Flags: `--all` · `--limit <n>` · `--profile-url <v>` · `--source <v>`!
  Exits: 0, 1, 2
- **`octolens mentions engage <SOURCEID>`** — Set (or toggle) the engaged-with flag on a mention
  Flags: `--engaged <true|false>`
  Exits: 0, 1, 2
- **`octolens mentions export`** — Export filtered mentions to a CSV/JSON file or stdout
  Flags: `--author <v>` · `--feed <n>` · `--format <csv|json>` · `--keyword <v>` · `--limit <n>` · `--output <v>` · `--relevance <relevant|all>` · `--search <v>` · `--sentiment <v>` · `--since <v>` · `--source <v>` · `--until <v>`
  Exits: 0, 1, 2
- **`octolens mentions get <SOURCEID>`** — Get a single mention by its sourceId (or its numeric id)
  Exits: 0, 1, 2
- **`octolens mentions list`** — List mentions from your feed, filtered and paginated
  Flags: `--all` · `--author <v>` · `--feed <n>` · `--keyword <v>` · `--limit <n>` · `--relevance <relevant|all>` · `--search <v>` · `--sentiment <v>` · `--since <v>` · `--source <v>` · `--until <v>`
  Exits: 0, 1, 2
- **`octolens mentions update <SOURCEID>`** — Override a mention's relevance and/or sentiment (triage)
  Flags: `--relevance <v>`~ · `--sentiment <v>`~
  Exits: 0, 1, 2, 8

`--source`, `--keyword` and `--sentiment` are **repeatable** (values OR together);
different flags AND together. `--keyword` takes a name or an id. `--relevance`
defaults to `relevant`; pass `--relevance all` to include low-relevance posts.
`--feed <id>` reuses a saved feed's filter as the base.

`--since`/`--until` work independently here (unlike `analytics`). Omitting
`--since` means **unbounded** — the web feed's default 7-day view does not apply.
An inverted window exits `2` (`INVALID_WINDOW`) rather than returning nothing.

Both id fields round-trip: a list row carries `sourceId` (stable, platform-native)
and `id` (internal numeric), and `get` / `update` / `engage` accept either. A
blank or whitespace-only id is a usage error (`2`, `INVALID_ARGUMENT`) caught at
parse time, not a `404`.

`mentions engage --engaged true|false` is an **idempotent absolute write**;
omitting the flag **toggles** and is therefore not safe to re-run. Prefer the
explicit form in scripts.

`mentions update --relevance` accepts `relevant`, `not_relevant`, `high`,
`medium`, `low`, `clear`; `--sentiment` accepts `Positive`, `Neutral`, `Negative`.

`mentions export` tops out at the API's 50,000-row export ceiling. It writes to
stdout unless `-o/--output` names a file. The format
follows the extension (`.csv`/`.json`; anything else is csv; `.jsonl`/`.ndjson`
are refused), or `--format`. `mentions export -o out.csv --json` writes a **csv
file** and emits one advisory object on stderr saying so — `--json` shapes stdout,
not the file.

```json
{
  "data": [
    { "sourceId": "reddit_t3_1abc234", "id": 101, "source": "reddit",
      "author": "jane", "relevance": "relevant", "sentiment": "Positive",
      "engaged": false, "url": "https://reddit.com/…" }
  ],
  "pagination": { "nextCursor": null }
}
```

#### `notifications`

- **`octolens notifications create`** — Create a notification on a feed (flags for agents, a guided wizard on a TTY)
  Flags: `--day-of-week <n>` · `--delivery-mode <v>` · `--destinations-json <v>`~ · `--email <v>`~ · `--feed <n>`^ · `--frequency <v>` · `--name <v>`^ · `--slack <v>`~ · `--time <v>` · `--timezone <v>` · `--type <v>` · `--webhook <v>`~
  Exits: 0, 1, 2, 8
- **`octolens notifications get <ID>`** — Get a single notification by id
  Exits: 0, 1, 2
- **`octolens notifications list`** — List your notifications (feed → destination delivery rules)
  Flags: `--all` · `--limit <n>`
  Exits: 0, 1, 2
- **`octolens notifications rm <ID>`** — Delete a notification by id (the feed is not affected)
  Flags: `--force` · `--yes`^
  Exits: 0, 1, 2, 8
- **`octolens notifications test <ID>`** — Send a real test delivery to every destination and report the outcome
  Exits: 0, 1, 2, 9
- **`octolens notifications update <ID>`** — Update a notification (name, feed, enable/disable, destinations)
  Flags: `--day-of-week <n>` · `--delivery-mode <v>` · `--destinations-json <v>` · `--disable` · `--email <v>` · `--enable` · `--feed <n>` · `--frequency <v>` · `--name <v>` · `--slack <v>` · `--time <v>` · `--timezone <v>` · `--type <v>` · `--webhook <v>`
  Exits: 0, 1, 2

A notification = a **feed** (its filters) + one or more **destinations**. Headless,
`create` requires `--name` and `--feed`, plus at least one destination flag:
`--email <comma-separated>`, `--slack <comma-separated channel ids>`,
`--webhook <url>` (each implies its `--type`), or `--destinations-json` for
several at once. Get Slack channel ids from `octolens slack channels`.

`--frequency` is `hourly`, `hourlyAtTopOfHour`, `daily` or `weekly` (create
defaults to `daily`; on update, omit it to keep the current cadence).
`--time HH:mm` pairs with `--timezone` (IANA name or UTC offset), and `weekly`
requires `--day-of-week 0`–`6` (0 = Sunday). `--delivery-mode` is `batch` (one
digest per period) or `individual` (one message per mention).

**`notifications test` sends a real delivery.** It exits `9` when a destination
rejects it (`NOTIFICATION_TEST_FAILED`, or
`NOTIFICATION_TEST_PARTIAL_FAILURE` when only some did) — the command worked, the
delivery did not.

#### `org`

- **`octolens org get`** — Show the authenticated workspace (name, plan, platforms)
  Exits: 0, 1, 2
- **`octolens org update`** — Update workspace settings (name, monitored platforms)
  Flags: `--name <v>` · `--platforms <v>`
  Exits: 0, 1, 2
- **`octolens org usage`** — Show mention/keyword usage against your plan limits
  Exits: 0, 1, 2

`--platforms` is repeatable; pass `--platforms all` for every supported platform.

#### `slack`

- **`octolens slack channels`** — Search the workspace's Slack channels (feeds a notification's `--slack`)
  Flags: `--all` · `--limit <n>` · `--search <v>`
  Exits: 0, 1, 2
- **`octolens slack connect`** — Connect Slack via the browser OAuth flow, then wait for it to go live
  Flags: `--no-browser` · `--timeout <n>`
  Exits: 0, 1, 2
- **`octolens slack status`** — Show the workspace's Slack connection status
  Exits: 0, 1, 2

#### `suggestions`

- **`octolens suggestions accept <ID>`** — Accept a keyword suggestion (applies it to the keyword)
  Flags: `--value <v>`
  Exits: 0, 1, 2
- **`octolens suggestions list`** — List AI keyword-tuning suggestions (org-wide or per keyword)
  Flags: `--all` · `--keyword <v>` · `--limit <n>`
  Exits: 0, 1, 2, 4
- **`octolens suggestions reject [ID]`** — Reject a suggestion by id, or all for a keyword (`--keyword`)
  Flags: `--keyword <v>`
  Exits: 0, 1, 2, 4

`suggestions accept --value` overrides the suggested value before applying it.
`reject` needs exactly one target: an id **or** `--keyword` — neither exits `2`
(`REJECT_TARGET_REQUIRED`), both exits `2` (`REJECT_TARGET_CONFLICT`).

#### `tags`

- **`octolens tags list`** — List the tag names you can filter mentions by
  Flags: `--all` · `--limit <n>`
  Exits: 0, 1, 2

#### `version`

- **`octolens version`** — Show the Octolens CLI version and build metadata
  Exits: 0, 1, 2

---

## Error codes

The 91 codes this build can emit, grouped by the exit code they map to. **Branch on the exit code first**,
then read `error.code` for the remedy — the exit map is frozen, individual codes
may be added.

**Exit `1`** — `CONFIG_INVALID`, `INTERNAL_ERROR`, `INVALID_RESPONSE`,
`REQUEST_TIMEOUT`, `SLACK_CONNECT_TIMEOUT`, `UNEXPECTED_ERROR`

**Exit `2`** — `AMBIGUOUS_KEYWORD`, `AMBIGUOUS_MEMBER`,
`AUTHOR_FILTERS_UNSUPPORTED`, `AUTHOR_NEEDS_SOURCE`, `AUTHOR_REQUIRED`,
`BROWSER_LOGIN_REQUIRES_TTY`, `CLEAR_NOT_CONFIRMED`, `COMMAND_NOT_FOUND`,
`CONFLICTING_DESTINATION`, `CONFLICTING_FILTER_FLAGS`, `CONFLICTING_FLAGS`,
`CONFLICTING_TERM`, `CONFLICTING_VALUE_FLAGS`, `INCOMPLETE_WINDOW`,
`INVALID_ARGUMENT`, `INVALID_BASE_URL`, `INVALID_DATE`, `INVALID_DAY_OF_WEEK`,
`INVALID_DELIVERY_MODE`, `INVALID_DESTINATIONS_JSON`, `INVALID_DESTINATION_TYPE`,
`INVALID_EMAIL`, `INVALID_FILTER_JSON`, `INVALID_FLAG_COMBINATION`,
`INVALID_FORMAT`, `INVALID_FREQUENCY`, `INVALID_INTERVAL`, `INVALID_LIMIT`,
`INVALID_PROFILE_CHOICE`, `INVALID_RELEVANCE`, `INVALID_SENTIMENT`,
`INVALID_STORED_BASE_URL`, `INVALID_TIMEOUT`, `INVALID_VALUES_JSON`,
`INVALID_WINDOW`, `JSON_NOT_SUPPORTED`, `LOGIN_TIMEOUT`, `MISSING_DESTINATION`,
`MISSING_DESTINATION_TARGET`, `MISSING_KEYWORD`, `MISSING_KEY_VALUE`,
`MISSING_PROFILE`, `MISSING_REQUIRED_ARGS`, `MISSING_REQUIRED_FLAGS`,
`NOTHING_TO_UPDATE`, `NOTIFICATION_TEST_NO_DESTINATIONS`, `NO_PROFILE_SELECTED`,
`NO_STORED_PROFILE`, `NO_UPDATE_FIELDS`, `NO_WEB_PAGE`,
`PROFILE_URL_LINKEDIN_ONLY`, `REJECT_TARGET_CONFLICT`, `REJECT_TARGET_REQUIRED`,
`UNKNOWN_FEED`, `UNKNOWN_FILTER_LIST`, `UNKNOWN_KEYWORD`, `USAGE_ERROR`,
`VALIDATION_ERROR`, `WATCH_REQUIRED`, `WINDOW_TOO_LARGE`

**Exit `3`** — `MISSING_API_KEY`, `NOT_LOGGED_IN`, `NO_CREDENTIALS`, `NO_PROFILES`
(the no-usable-credential family) · `CONFLICTING_CREDENTIALS`, `INVALID_API_KEY`,
`UNAUTHORIZED` (a credential exists, something else is wrong — do **not** loop
into a login)

**Exit `4`** — `KEYWORD_NOT_FOUND`, `MEMBER_NOT_FOUND`, `NOT_FOUND`,
`PROFILE_NOT_FOUND`

**Exit `5`** — `ADMIN_SCOPE_REQUIRED`, `FORBIDDEN`, `INVITER_REQUIRED`

**Exit `6`** — `PLAN_LIMIT_EXCEEDED`

**Exit `7`** — `RATE_LIMITED` (carries `retryAfterSeconds` / `resetAt` when the
server stated them)

**Exit `8`** — `CANCELLED`

**Exit `9`** — `FILTERS_ADD_PARTIALLY_REFUSED`, `FILTERS_ADD_REFUSED`,
`NOTIFICATION_TEST_FAILED`, `NOTIFICATION_TEST_PARTIAL_FAILURE`

**Exit `10`** — `RESPONSE_LOST`

**Exit derived from the API response** — `KEYWORD_LIMIT_EXCEEDED`, `ORG_NOT_FOUND`
(minted by the service), `WRITE_FAILED` (status-derived). These follow the same
mapping rules as the codes above; a `403` carrying a `*LIMIT*`/`*PLAN*` code exits
`6`, a plain `403` exits `5`.

---

## Scripting patterns

**Preflight, then work.** One cheap call decides whether the rest can run:

```bash
octolens whoami --json > /dev/null 2>&1
[ $? -eq 3 ] && { echo "set OCTOLENS_API_KEY" >&2; exit 1; }
```

**Branch on codes, never on messages.**

```bash
out=$(octolens mentions list --source reddit --limit 50 --json 2>err.json)
case $? in
  0) echo "$out" | jq -r '.data[].url' ;;
  3) echo "auth: $(jq -r .error.code err.json)" >&2; exit 3 ;;
  7) sleep "$(jq -r '.error.retryAfterSeconds // 60' err.json)"; exec "$0" ;;
  *) jq -r .error.message err.json >&2; exit 1 ;;
esac
```

**Resolve ids from names in one step** — the CLI does the lookup the REST API
makes you do yourself:

```bash
octolens mentions list --keyword 'acme corp' --sentiment negative --since 2026-06-01 --json
```

**Bulk export** — one call, no pagination loop:

```bash
octolens mentions export --source reddit --since 2026-01-01 -o mentions.csv
octolens mentions export --feed 42 --format json > feed.json
```

**Stream and act:**

```bash
octolens feeds watch --backlog none --json \
  | jq -r --unbuffered 'select(.type != "error") | .sourceId'
```

**Wire a Slack alert end to end:**

```bash
feed=$(octolens feeds create --name "Negative Reddit" --source reddit \
         --sentiment negative --json | jq -r '.id')
ch=$(octolens slack channels --search alerts --json | jq -r '.data[0].id')
notif=$(octolens notifications create --name "Neg Reddit → Slack" --feed "$feed" \
          --slack "$ch" --frequency hourly --json | jq -r '.id')
octolens notifications test "$notif"   # exit 9 = the delivery failed, not the command
```

## Gotchas

- **`--json` never prompts.** Any interactive-only input becomes an exit `2`
  naming the flag to pass. Never wait on a `--json` run for a prompt.
- **`--yes` is required headless for destructive commands** (`keywords rm`,
  `feeds rm`, `notifications rm`, `members rm`, `feedback rm`); without it the run
  exits `2`, not `8`.
- **Exit `9` ≠ failure to run.** `notifications test` and `filters add` use it to
  say "I ran; the target refused". Re-running unchanged will refuse again.
- **Exit `10` is not retryable.** Verify with the matching `list`/`get`.
- **`mentions engage` without `--engaged` toggles.** Always pass the explicit
  value in automation.
- **`analytics`/`dashboard` need `--since` and `--until` together**; `mentions`
  does not.
- **`--limit` and `--all` are mutually exclusive** everywhere, checked before any
  network call.
- **stderr is 0 bytes on success** — except for three documented cases that all
  emit valid JSON objects: `login`/`slack connect` (the authorize URL),
  `mentions export -o <non-json file> --json` (a format advisory), and
  `feeds watch --json` (`poll_failed` events). For those, branch on the exit code,
  not on stderr being non-empty.
- **A `403` is exit `5`, not `3`.** A read-scoped key calling a write command has a
  perfectly valid credential; minting a new key with `write` is the fix, not
  logging in again.
