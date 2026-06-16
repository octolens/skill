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

## Two ways to connect

**MCP (preferred)** — self-documenting tools, OAuth login, no API key to manage:

```bash
claude mcp add --transport http octolens "https://app.octolens.com/api/mcp/v2"
```

**REST API v2** — for scripting, CSV/JSON export, or non-MCP agents. Base URL
`https://app.octolens.com/api/v2`, Bearer auth with an Octolens API key.
Interactive docs at `https://app.octolens.com/api/v2/docs`.

## Files

- [SKILL.md](SKILL.md) — when to use MCP vs REST, auth, mention filtering, gotchas.
- [references/REST-API.md](references/REST-API.md) — complete endpoint catalog.

## Requirements

- An Octolens plan with API access (Pro, Scale, or Enterprise).
- For REST: an API key (Settings → API). For MCP: an MCP-capable agent.

No scripts are bundled — call the API directly via `curl`/`fetch`, or use MCP.
