# Using Google Antigravity with Volume Sliders

This guide explains how to effectively use the Google Antigravity AI assistant with the Volume Sliders project. The project is pre-configured with a suite of AI "stuff" (workflows, skills, and personas) designed to safely and effectively develop, debug, and release updates.

## The AI Infrastructure

The AI assistance for this project is built on three main concepts, all stored in the `.agents/` directory:

1. **Workflows**: Guided, step-by-step processes for common tasks (e.g., adding a feature, fixing a bug, cutting a release).
2. **Skills**: Specialized knowledge sets the AI can automatically pull from to perform specific tasks (e.g., researching WoW APIs, running validation tests).
3. **Personas**: Distinct roles the AI adopts during different phases of development (e.g., Planner, Implementer, Validator).

All of these are bound by the universal rules defined in `AGENTS.md` and the detailed workflow contract in `docs/AGENT_WORKFLOW.md`.

---

## 1. Workflows (Slash Commands)

Workflows are the best way to kick off a new session or a major piece of work. You can invoke them using slash commands in the Antigravity chat interface.

### Available Workflows

- **/Volume Sliders Feature Cycle**
  Use this when you want to add a non-trivial new feature. The AI will guide you through planning, API research, implementation, validation, and documentation.
- **/Volume Sliders Bugfix Cycle**
  Use this for diagnosing a bug report, applying a targeted fix, and ensuring regressions are validated.
- **/Volume Sliders Validation**
  Use this to simply run the repository validation checklist (linting, tests, migration checks) and get a summary.
- **/Volume Sliders Release PR**
  Use this when you are ready to prepare a new release. The AI will help update versions, sync changelogs, run tests, and prepare a PR.

*Note: Workflows automatically orchestrate the different Personas and utilize the necessary Skills under the hood.*

---

## 2. Personas (Roles)

Under the hood, Antigravity uses distinct personas to separate concerns and maintain high code quality. While you don't typically need to invoke these manually, understanding them helps you know what the AI is trying to accomplish at any given time.

- **@planner**: Analyzes your request and builds an architecture plan before any code is written. It respects existing module boundaries.
- **@api-researcher**: Verifies WoW Retail APIs, event payloads, CVar behavior, and taint risks before implementation begins.
- **@implementer**: Writes the actual Lua/XML code based on the approved plan and API research.
- **@validator**: Runs the static checks (`luacheck`) and behavioral specs (`busted`) to prove the changes work.
- **@debugger**: Diagnoses and surgical fixes failures discovered during validation or from user reports.
- **@release-manager**: Prepares PR-based releases, keeping version metadata strictly synchronized.

---

## 3. Skills (Automated Capabilities)

Skills are folders of instructions and resources that extend Antigravity's capabilities. If a task requires a specific skill, Antigravity will automatically load and use it. 

- **wow-planning**: Used when planning non-trivial changes or architecture decisions.
- **wow-api-discovery**: Used to verify WoW Retail API signatures and avoid taint issues before implementing new addon behavior.
- **wow-implementation**: Used to safely write Lua 5.1 and XML changes respecting project boundaries.
- **wow-validation**: Used to run linting, Busted tests, migration checks, and documentation verification.
- **wow-debugging**: Used to diagnose bugs and CI failures with minimal, targeted changes.
- **wow-release**: Used to prepare PRs, update versions, and sync changelogs.
- **wow-docs-overhaul**: Used when modifying the AI documentation (`AGENTS.md`, `.agents/`, etc.) itself.

---

## Best Practices for Human Users

1. **Use Slash Commands for Big Tasks**: If you want to build a feature or fix a bug, start your prompt with the appropriate slash command (e.g., `/Volume Sliders Feature Cycle Let's add a master volume slider.`). This sets the AI on the right tracked path immediately.
2. **Review the Plans**: When the AI enters the "Planning" phase, it will often generate an `implementation_plan.md` artifact and ask for your approval. Review this carefully before saying "go ahead"—this prevents the AI from writing code that strays outside established boundaries.
3. **Let the AI Validate**: The AI is instructed to run `luacheck` and `busted` tests automatically during the Validation phase. If it forgets, you can remind it, or just run `/Volume Sliders Validation`.
4. **Agent Cannot Merge**: The AI is strictly forbidden from merging Pull Requests or pushing release tags without explicit permission. You remain the final gatekeeper for releases.
5. **Private Notes**: If you have scratch files or personal notes you want the AI to read but not commit, put them in the `local_dev_assets/` folder, which is git-ignored.
