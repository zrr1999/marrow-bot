# marrow-bot Agents

`marrow-bot` is the default prompt-first profile that runs on top of `marrow-core`.

## Profile purpose

- provide stable role prompts under `roles/`
- provide stable policy in role definitions and this file
- provide minimal dynamic facts via `context.d/`
- render `.opencode/agents/` via `role-forge`
- stay free of lifecycle/operator bridge logic

The high-level architecture, filesystem layout, and CLI contracts remain documented in `marrow-core/AGENTS.md`. This file focuses on bot-specific behavior layered on top of those contracts.

`marrow-bot` is prompt-first: stable policy should live in role definitions and this file rather than a separate prompts layer.

## Allowed call graph

- `orchestrator -> directors`
- `directors -> leaders`
- `leaders -> specialists`
- `specialists -> none`

Use scoped role references such as `directors/forge` or `specialists/tester` when a bare name would be ambiguous.

## Active role inventory

- top level: `orchestrator`
- directors: `craft`, `forge`, `mind`, `sentinel`
- leaders: `archivist`, `builder`, `courier`, `evolver`, `herald`, `reviewer`, `scout`, `shaper`, `verifier`
- specialists: `analyst`, `coder`, `git-ops`, `researcher`, `tester`, `writer`

Keep the repo small:

- `roles/` and `roles.toml` are the main profile surface
- `context.d/` contains only `work_items.py`; it must stay read-only and expose only the shared `work-items/` seam
- lifecycle execution bridges belong outside this repo; use `marrow-task` or another operator/plugin repo instead

## Runtime boundary

- `marrow-bot` does not own `claim-next`, `complete`, `block`, or `fail`
- work-item write-back belongs to `marrow-task` or another external bridge
- this repo reads shared `work-items/` through `context.d/work_items.py`, but must not mutate them with local bridge scripts

## Direct-use path

Preferred local setup path:

1. run `./setup.sh`
2. let it render `.opencode/agents/`
3. use the checked-in config at `/opt/marrow-bot/marrow.toml`
4. run `uvx marrow-core dry-run --config /opt/marrow-bot/marrow.toml`
