# marrow-bot Agents

This document will describe the concrete roles, delegation boundaries, and workflows for the default bot profile that runs on top of `marrow-core`.

Planned contents:

- Role inventory (directors, leaders, specialists, orchestrator).
- Delegation rules and allowed call graph.
- Handoff directory semantics under `runtime/handoff/*`.
- Example human <-> agent collaboration flows.

The high-level architecture, filesystem layout, and CLI contracts remain documented in `marrow-core/AGENTS.md`. This file focuses on bot-specific behavior layered on top of those contracts.

