# marrow-bot

Default bot profile for `marrow-core`.

This repository is **not** a Python package; it behaves like a user workspace
layout that `marrow-core` can consume.

This repository provides:

- Canonical role prompts and delegation layout under `roles/`.
- Stable policy directly in role definitions and AGENTS.
- Minimal context providers under `context.d/`.
- A minimal work-item context bridge for shared intake state under `context.d/work_items.py`.
- A default `marrow.toml` configuration that wires these into `marrow-core`.
- Casting metadata in `roles.toml` for `role-forge` / OpenCode.

`marrow-core` stays profile-agnostic: it only provides the scheduler, CLI, IPC, services, and sync model. `marrow-bot` is one concrete bot that runs on top of that runtime.

## Shared work-items seam

`marrow-bot` now reads the shared `work-items/` contract via a context provider instead of redefining intake state inside the prompt tree.

## Prompt-first profile

`marrow-bot` is now prompt-first:

- stable policy lives in role definitions and AGENTS
- dynamic facts live in `context.d/`
- lifecycle bridging is externalized to `marrow-task`

`marrow-bot` itself stays read-only and prompt-first. Operational lifecycle bridging moved out so the profile repo does not become a tools or service repo.

There is intentionally **no** bot-local `claim-next` / `complete` / `block` / `fail` bridge in this repo. Use `marrow-task` or another external bridge for write-back and lifecycle operations.

Example:

```bash
uvx role-forge render --project-dir . --yes
uv run --directory ../marrow-core marrow-core validate --config ./.runtime-config.toml
# lifecycle bridge lives in marrow-task:
python -m marrow_task claim-next --workspace /Users/marrow
```

## Quick start

If `marrow-core` is checked out next to this repo, the fastest path is:

```bash
./setup.sh
uv run --directory ../marrow-core marrow-core dry-run --config ./.runtime-config.toml
```

`setup.sh` will:

- render `.opencode/agents/` from `roles/`
- generate a runnable `.runtime-config.toml`
- copy `context.d/` into the target workspace
- run `validate`, `doctor`, and `dry-run`
- render service files into `./service-out`

## Installation

1. **Prepare local prerequisites**
   You need:
   - `uv` / `uvx`
   - `opencode`
   - a local `marrow-core` checkout (default: sibling `../marrow-core`)

2. **Clone `marrow-bot` alongside `marrow-core`**

   ```bash
   git clone https://github.com/zrr1999/marrow-bot.git
   cd marrow-bot
   ```

   Or, if both repos already live under the same parent:

   ```bash
   cd /path/to/marrow-bot
   ```

3. **Run the setup helper**

   ```bash
   ./setup.sh
   ```

   Common overrides:

   ```bash
   CORE_DIR=/path/to/marrow-core WORKSPACE=/path/to/workspace ./setup.sh
   ```

4. **Inspect the generated artifacts**

   - generated config: `./.runtime-config.toml`
   - rendered roles: `./.opencode/agents/`
   - rendered services: `./service-out/`
   - copied runtime context: `<workspace>/context.d/`

5. **Run via local `marrow-core`**

   Dry-run prompt assembly:

   ```bash
   uv run --directory ../marrow-core marrow-core dry-run --config ./.runtime-config.toml
   ```

   Persistent runtime loop:

   ```bash
   uv run --directory ../marrow-core marrow-core run --config ./.runtime-config.toml
   ```

After setup, the service or CLI that runs `marrow-core` will use the `orchestrator` agent from this profile as the top-level scheduled main.

## Notes on lifecycle and sync

- `marrow-bot` is read-only and prompt-first.
- lifecycle write-back belongs outside this repo.
- default `sync` is disabled in the template because `sync-once` is maintenance-only and source-checkout-centric.

## Current shape

`marrow-bot` is intentionally small:

- `roles/`
- `roles.toml`
- `marrow.toml`
- minimal `context.d/`
- lightweight README / AGENTS
