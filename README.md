# Octolens Skill

[![skills.sh](https://skills.sh/b/octolens/skill)](https://skills.sh/octolens/skill)

Query and manage [Octolens](https://octolens.com) social-listening data — run
one-time AI-scored searches, fetch brand mentions, and manage keyword
tracking, feeds, analytics, and Slack/email/webhook notifications across
Reddit, Twitter/X, LinkedIn, YouTube, TikTok, Bluesky, Hacker News, GitHub,
news, podcasts, and the open web. No account needed to start: `octolens
signup` creates a workspace from the terminal.

## Install

```bash
npx skills add octolens/skill
```

Or browse it on [skills.sh](https://skills.sh/octolens/skill).

## Two ways to connect

**CLI** — for shell scripts, CI jobs, terminal work, and bulk export. Stable exit
codes, pure `--json` on stdout, automatic `Retry-After` retries:

```bash
npm install -g octolens          # Node 20+, or `npx octolens <cmd>`
octolens signup                  # no account? create one from the terminal
export OCTOLENS_API_KEY=ak_...   # or: octolens login (existing workspace)
octolens search "your brand" --days 7 --json
octolens mentions list --source reddit --sentiment negative --json
```

**REST API v2** — for raw programmatic access, non-Node environments, and
anything the CLI does not cover. Base URL `https://app.octolens.com/api/v2`,
Bearer auth with an Octolens API key. Interactive docs at
`https://app.octolens.com/api/v2/docs`.

Octolens also offers an MCP server, whose tools carry their own descriptions —
docs: <https://octolens.com/docs/mcp/v2/overview>.

## Files

- [SKILL.md](SKILL.md) — CLI vs REST, auth, mention filtering, gotchas.
- [references/CLI.md](references/CLI.md) — complete command, exit-code, and error-code reference.
- [references/REST-API.md](references/REST-API.md) — complete endpoint catalog.

## Requirements

- An Octolens plan with API access (Agents, Pro, Scale, or Enterprise) — or no
  account at all: `octolens signup` creates an Agents-plan workspace from the
  terminal (50 lifetime searches + 5,000 AI-scored mentions/month), and
  `octolens upgrade` mints a signed-in upgrade link when the allowance runs out.
- For the CLI: Node.js 20+ and an API key (or `octolens login` /
  `octolens signup`). For REST: an API key (Settings → API).

No scripts are bundled — use the `octolens` CLI, or call the API directly via
`curl`/`fetch`.

## Maintained in octolens/octolens

This repository is a published projection: its source of truth is
`docs/cli/external-skill/` in the (private) `octolens/octolens` monorepo, and a
sync workflow there pushes every change here (OCT-1534). Do not edit files in
this repository directly — the next sync would overwrite them; open an issue
instead.
