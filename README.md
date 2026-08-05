# Octolens Skill

[![skills.sh](https://skills.sh/b/octolens/skill)](https://skills.sh/octolens/skill)

Query and manage [Octolens](https://octolens.com) social-listening data — brand
mentions, keyword tracking, feeds, analytics, and Slack/email/webhook
notifications across Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky,
Hacker News, GitHub, news, podcasts, and the open web.

## Install

```bash
npx skills add octolens/skill
```

Or browse it on [skills.sh](https://skills.sh/octolens/skill).

## Three ways to connect

**MCP** — for interactive agent work. Self-documenting tools, OAuth login, no API
key to manage:

```bash
claude mcp add --transport http octolens "https://app.octolens.com/api/mcp/v2"
```

**CLI** — for shell scripts, CI jobs, terminal work, and bulk export. Stable exit
codes, pure `--json` on stdout, automatic `Retry-After` retries:

```bash
npm install -g octolens          # Node 20+, or `npx octolens <cmd>`
export OCTOLENS_API_KEY=ak_...   # or: octolens login
octolens mentions list --source reddit --sentiment negative --json
```

**REST API v2** — for raw programmatic access and non-Node environments. Base URL
`https://app.octolens.com/api/v2`, Bearer auth with an Octolens API key.
Interactive docs at `https://app.octolens.com/api/v2/docs`.

## Files

- [SKILL.md](SKILL.md) — which path to use, auth, mention filtering, gotchas.
- [references/CLI.md](references/CLI.md) — complete command, exit-code, and error-code reference.
- [references/REST-API.md](references/REST-API.md) — complete endpoint catalog.

## Requirements

- An Octolens plan with API access (Pro, Scale, or Enterprise).
- For MCP: an MCP-capable agent. For the CLI: Node.js 20+ and an API key (or
  `octolens login`). For REST: an API key (Settings → API).

No scripts are bundled — use MCP, the `octolens` CLI, or call the API directly
via `curl`/`fetch`.
