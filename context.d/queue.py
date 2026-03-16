#!/usr/bin/env python3
"""Queue context provider — reads task files and outputs them as prompt text.

This is a context.d script. It simply prints text to stdout.
marrow-core will inject the output into the agent's prompt.
"""

from __future__ import annotations

import os
from pathlib import Path


def _workspace() -> Path:
    explicit = os.environ.get("MARROW_WORKSPACE")
    if explicit:
        return Path(explicit)
    script_dir = Path(__file__).resolve().parent
    if script_dir.name == "context.d":
        return script_dir.parent
    home = os.environ.get("HOME")
    if home:
        return Path(home)
    return Path("/Users/marrow")


def main() -> None:
    queue_dir = _workspace() / "tasks" / "queue"
    if not queue_dir.is_dir():
        return

    files = sorted(p for p in queue_dir.iterdir() if p.is_file())
    if not files:
        return

    print("Task queue lives in tasks/queue/. Completed tasks go to tasks/done/.")
    print("Process the following task queue files (full paths):\n")

    for f in files:
        print(f.resolve())


if __name__ == "__main__":
    main()
