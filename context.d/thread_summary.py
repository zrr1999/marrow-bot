#!/usr/bin/env python3
"""Expose bot-local persistent thread summaries to prompt context."""

from __future__ import annotations

import json
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
    threads_dir = _workspace() / "runtime" / "state" / "threads"
    if not threads_dir.is_dir():
        return
    threads: list[dict] = []
    for path in sorted(threads_dir.glob("*.json"), reverse=True)[:10]:
        try:
            threads.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    if not threads:
        return
    print("Persistent bot-local threads:")
    for thread in threads:
        print(
            f"- {thread.get('thread_id', '')} [{thread.get('status', '')}] {thread.get('title', '')} "
            f"| items={len(thread.get('source_item_ids', []))} tasks={len(thread.get('task_files', []))} "
            f"| note={thread.get('last_note', '')}"
        )


if __name__ == "__main__":
    main()
