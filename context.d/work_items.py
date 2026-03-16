#!/usr/bin/env python3
"""Work-item context provider for shared gateway/dashboard seams.

This keeps bot awareness of shared intake state without moving bot semantics into core.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

MAX_ITEMS = 10


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


def _load_items() -> list[dict]:
    work_items_dir = _workspace() / "work-items"
    if not work_items_dir.is_dir():
        return []
    items: list[dict] = []
    for path in sorted(work_items_dir.glob("*.json"), reverse=True)[:MAX_ITEMS]:
        try:
            items.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    return items


def main() -> None:
    items = _load_items()
    if not items:
        return

    print(
        "Shared work-items are available in work-items/ as gateway/dashboard/core contracts."
    )
    print(
        "Use them as intake signals or status context; do not rewrite the contract in prompt space."
    )
    print()
    print(f"Recent work-items ({len(items)} shown):")

    for item in items:
        source = item.get("source") or {}
        payload = item.get("payload") or {}
        print(
            "- "
            f"[{item.get('status', 'unknown')}] "
            f"{payload.get('title', '(untitled)')} "
            f"(channel={source.get('channel', '')}, kind={item.get('kind', '')}, id={item.get('item_id', '')})"
        )


if __name__ == "__main__":
    main()
