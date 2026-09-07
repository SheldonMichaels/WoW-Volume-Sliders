# Using Codex and ChatGPT with Volume Sliders

Open the repository as the Codex project and start at [AGENTS.md](../AGENTS.md). The [agent workflow](AGENT_WORKFLOW.md) applies across assistants, including Antigravity with Gemini.

## What loads where

| File or folder | Purpose |
| --- | --- |
| `AGENTS.md` | Codex project instructions; shared repository contract |
| `.agents/skills/*/SKILL.md` | Seven shared project skills already discoverable in Codex |
| `.agents/agents.md` | Written persona definitions; not native Codex subagent configuration |
| `.agents/workflows/*.md` | Antigravity workflow documents; Codex can read and follow them as procedures |
| `.cursor/rules/*.mdc` | Cursor-specific routing; not a substitute for `AGENTS.md` |
| `.cursor/mcp.json` | Cursor's optional `wow-api` server setup; do not assume another assistant has this connection |

Codex reads project `AGENTS.md` and discovers repository skills in `.agents/skills/`. See the official [instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md) and [skill discovery](https://learn.chatgpt.com/docs/build-skills) documentation. No duplicate `CODEX.md`, `.codex/skills/`, or model-specific policy is needed for this repository.

## Starting a task

For example: "Use $wow-validation to review this checkout. Follow AGENTS.md and report automated checks separately from in-game testing."

For maintenance while a WoW client is unavailable: "Follow docs/OFFLINE_MAINTENANCE.md. Review documentation and add regression tests for existing behavior."

Ask the assistant to identify the loaded project instructions and available `wow-*` skills if discovery seems incomplete. If skills are missing, check the project location and restart the session. The role names in `.agents/agents.md` describe phases one assistant can perform sequentially; they do not create agents or require parallel work.

Ordinary ChatGPT conversations without repository access need the relevant files supplied explicitly. Do not assume that attaching one guide also supplies all linked files, editor settings, MCP tools, or local notes.

## Local configuration and overrides

Keep machine-specific paths, credentials, and tool connections local. `.cursor/mcp.json` launches `wow-api-mcp` through `npx`; its presence proves configuration exists, not that the server is installed, callable, or current. Check the active assistant's actual tools before API research. No new server installation is required for documentation or unit-test maintenance.

`AGENTS.local.md` is a repository convention for explicitly requested private context, not Codex's default instruction filename. Codex recognizes `AGENTS.override.md`, which takes precedence over `AGENTS.md` at the same directory level. It is ignored here to prevent accidental commits; avoid using it to hide the tracked contract.

See [ANTIGRAVITY_GUIDE.md](ANTIGRAVITY_GUIDE.md) for the existing Gemini workflow and [OFFLINE_MAINTENANCE.md](OFFLINE_MAINTENANCE.md) for the repository configuration audit.
