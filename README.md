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
uv run --directory ../marrow-core marrow-core validate --config ./marrow.toml
# lifecycle bridge lives in marrow-task:
python -m marrow_task claim-next --workspace /Users/marrow
```

## Quick start

If `marrow-core` is checked out next to this repo, the fastest path is:

```bash
./setup.sh
uv run --directory ../marrow-core marrow-core dry-run --config ./marrow.toml
```

`setup.sh` will:

- render `.opencode/agents/` from `roles/`
- use the checked-in `marrow.toml`
- use `sudo` only for operations that need elevated write access under `/opt`
- run `validate`, `doctor`, and `dry-run`
- render service files into `./service-out`

## Installation

1. **Prepare local prerequisites**
   You need:
   - `uv` / `uvx`
   - `opencode`
   - a local `marrow-core` checkout (default: sibling `../marrow-core`)
   - `sudo` access for operations that write protected paths under `/opt`

2. **Clone `marrow-bot` to `/opt/marrow-bot`**

   ```bash
   sudo git clone https://github.com/zrr1999/marrow-bot.git /opt/marrow-bot
   cd /opt/marrow-bot
   ```

3. **Run the setup helper**

   ```bash
   ./setup.sh
   ```

4. **Inspect the generated artifacts**

   - config in use: `./marrow.toml`
   - rendered roles: `./.opencode/agents/`
   - rendered services: `./service-out/`

5. **Run via local `marrow-core`**

   Dry-run prompt assembly:

   ```bash
   uv run --directory ../marrow-core marrow-core dry-run --config ./marrow.toml
   ```

   Persistent runtime loop:

   ```bash
   uv run --directory ../marrow-core marrow-core run --config ./marrow.toml
   ```

After setup, the service or CLI that runs `marrow-core` will use the `orchestrator` agent from this profile as the top-level scheduled main.

## Path design

- `marrow.toml` keeps only stable, reusable values.
- `profile.root_dir` is pinned to `/opt/marrow-bot` because the profile repo owns that path.
- user-home-specific values are derived by `marrow-core` from `user = "marrow"`.
- `agent_command` uses `opencode run --agent orchestrator` instead of a machine-local absolute path, so installation depends on PATH rather than one developer workstation.

## IPC and permissions

- `setup.sh` may call `sudo` for protected writes, but does not need to be launched as root.
- the runtime itself is still configured for `user = "marrow"`.
- `marrow-core` should derive the workspace from that user, place the IPC socket under the user-owned runtime tree, and keep `task add` / `task list` usable without root.

## Notes on lifecycle and sync

- `marrow-bot` is read-only and prompt-first.
- lifecycle write-back belongs outside this repo.
- default `sync` is disabled in the template because `sync-once` is maintenance-only and source-checkout-centric.
- setup may elevate selected install steps, but normal runtime and IPC usage should stay available to the configured bot user for `task add` / `task list`.

## Current shape

`marrow-bot` is intentionally small:

- `roles/`
- `roles.toml`
- `marrow.toml`
- minimal `context.d/`
- lightweight README / AGENTS
