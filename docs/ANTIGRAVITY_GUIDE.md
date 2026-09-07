# Using Google Antigravity with Volume Sliders

This guide describes the repository's Google Antigravity workflow, previously used with Gemini. Start by asking the assistant to read `AGENTS.md` and `docs/AGENT_WORKFLOW.md`. For Codex, see [CODEX_GUIDE.md](CODEX_GUIDE.md). When client testing is unavailable, follow [OFFLINE_MAINTENANCE.md](OFFLINE_MAINTENANCE.md).

## The AI Infrastructure

The AI assistance for this project is built on three main concepts, all stored in the `.agents/` directory:

1. **Workflows**: Guided, step-by-step processes for common tasks (e.g., adding a feature, fixing a bug, cutting a release).
2. **Skills**: Specialized knowledge sets the AI can automatically pull from to perform specific tasks (e.g., researching WoW APIs, running validation tests).
3. **Personas**: Distinct roles the AI adopts during different phases of development (e.g., Planner, Implementer, Validator).

All of these are bound by the universal rules defined in `AGENTS.md` and the detailed workflow contract in `docs/AGENT_WORKFLOW.md`.

---

## 1. Workflows (Slash Commands)

Workflow files are tracked under `.agents/workflows/`. Confirm which commands your installed Antigravity version discovers; display names and folder support must be checked locally. If discovery fails, ask the assistant to read the relevant file directly. If the installation expects `.agent/`, see [.agents/README.md](../.agents/README.md) for the ignored compatibility option.

### Available Workflows

- **Feature Cycle** (`.agents/workflows/feature-cycle.md`)
  Use this when you want to add a non-trivial new feature. The AI will guide you through planning, API research, implementation, validation, and documentation.
- **Bugfix Cycle** (`.agents/workflows/bugfix-cycle.md`)
  Use this for diagnosing a bug report, applying a targeted fix, and ensuring regressions are validated.
- **Validation** (`.agents/workflows/validate.md`)
  Use this to simply run the repository validation checklist (linting, tests, migration checks) and get a summary.
- **Release PR** (`.agents/workflows/release-pr.md`)
  Use this when you are ready to prepare a new release. The AI will help update versions, sync changelogs, run tests, and prepare a PR.

These documents instruct an assistant to adopt the listed roles and use relevant skills. They do not by themselves register separate agents or guarantee automatic orchestration.

---

## 2. Personas (Roles)

The repository defines the following personas in `.agents/agents.md`. They are written role descriptions that one assistant can follow sequentially.

- **@planner**: Analyzes your request and builds an architecture plan before any code is written. It respects existing module boundaries.
- **@api-researcher**: Verifies WoW Retail APIs, event payloads, CVar behavior, and taint risks before implementation begins.
- **@implementer**: Writes the actual Lua/XML code based on the approved plan and API research.
- **@validator**: Runs static checks (`luacheck`) and mocked behavioral specs (`busted`), and identifies remaining in-game checks.
- **@debugger**: Diagnoses and makes targeted fixes for failures discovered during validation or from user reports.
- **@release-manager**: Prepares PR-based releases, keeping version metadata strictly synchronized.

---

## 3. Skills (Automated Capabilities)

Skills are folders of instructions and resources. Verify they appear in the active assistant's skill list; otherwise ask it to read the relevant `SKILL.md` explicitly. These same project skills are available to Codex through `.agents/skills/`.

- **wow-planning**: Used when planning non-trivial changes or architecture decisions.
- **wow-api-discovery**: Used to verify WoW Retail API signatures and avoid taint issues before implementing new addon behavior.
- **wow-implementation**: Used to safely write Lua 5.1 and XML changes respecting project boundaries.
- **wow-validation**: Used to run linting, Busted tests, migration checks, and documentation verification.
- **wow-debugging**: Used to diagnose bugs and CI failures with minimal, targeted changes.
- **wow-release**: Used to prepare PRs, update versions, and sync changelogs.
- **wow-docs-overhaul**: Used when modifying the AI documentation (`AGENTS.md`, `.agents/`, etc.) itself.

---

## Best Practices for Human Users

1. **Choose a Workflow**: Use a discovered command or ask the assistant to follow `.agents/workflows/validate.md`, for example. State your scope and testing limitations.
2. **Review Plans**: Complex plans belong in `.agents/artifacts/Architecture_Design_Artifact.md`. The assistant should resolve routine choices within your request and ask about consequential ambiguities.
3. **Check Validation Evidence**: Request lint/test results separately from in-game checks. Tests do not prove live client compatibility.
4. **Human Merge Gate**: Only the human maintainer may merge PRs. Creating or pushing a release tag requires explicit permission for the exact version.
5. **Private Notes**: If you have scratch files or personal notes you want the AI to read but not commit, put them in the `local_dev_assets/` folder, which is git-ignored.
