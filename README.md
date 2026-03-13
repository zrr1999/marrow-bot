# marrow-bot

Default bot profile for `marrow-core`.

This repository is **not** a Python package; it behaves like a user workspace
layout that `marrow-core` can consume.

This repository provides:

- Canonical role prompts and delegation layout under `roles/`.
- Stable global policy under `prompts/rules.md`.
- Context providers for queue and workspace state under `context.d/`.
- A default `marrow.toml` configuration that wires these into `marrow-core`.
- Casting metadata in `roles.toml` for `role-forge` / OpenCode.

`marrow-core` stays profile-agnostic: it only provides the scheduler, CLI, IPC, services, and sync model. `marrow-bot` is one concrete bot that runs on top of that runtime.

## Installation

1. **Install `marrow-core` (runtime only)**  
   Follow `marrow-core`’s README to:
   - clone and install `/opt/marrow-core`
   - run its `setup.sh` to create the venv and install the heartbeat service

2. **Clone `marrow-bot` alongside `marrow-core`**

   ```bash
   sudo git clone https://github.com/zrr1999/marrow-bot.git /opt/marrow-bot
   cd /opt/marrow-bot
   ```

3. **Cast roles into `.opencode/agents/`**

   Using `uvx` (recommended) or any other way to invoke the `role-forge` CLI:

   ```bash
   uvx role-forge cast --config roles.toml
   ```

   This will project the canonical roles under `roles/` into the OpenCode runtime layout, typically under `/Users/marrow/.opencode/agents/`.

4. **Wire up the profile config**

   Copy or link this profile’s `marrow.toml` to where you want `marrow-core` to read it from (for a default install, `/opt/marrow-core/marrow.toml`):

   ```bash
   sudo cp marrow.toml /opt/marrow-core/marrow.toml
   ```

5. **Validate and install services via `marrow-core`**

   Use the `marrow` CLI (installed by `marrow-core`) instead of calling Python directly:

   ```bash
   cd /opt/marrow-core
   sudo uvx marrow validate --config marrow.toml
   sudo uvx marrow install-service --config marrow.toml --platform auto --output-dir ./service-out
   ```

After this, the systemd/launchd service that runs `marrow run` will use the `orchestrator` agent from this profile as the top-level scheduled main.

## Status

This repository is being bootstrapped as part of the decoupling described in:

- `marrow-core/docs/plans/2026-03-13-marrow-bot-decoupling-design.md`
- `marrow-core/docs/plans/2026-03-13-marrow-bot-decoupling-implementation.md`

Initial steps:

- Establish repo structure and basic metadata.
- Move non-core prompt, role, and context content out of `marrow-core`.
- Provide a clear installation path for new users.

Later steps will refine:

- Higher-level workflows and examples in `AGENTS.md`.
- A `setup-bot.sh` helper that automates casting, config placement, and validation.

