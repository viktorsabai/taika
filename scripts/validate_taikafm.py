#!/usr/bin/env python3
"""Validate taikafm.json against TaikaFMScope keys in the app."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = REPO_ROOT / "taikafm.json"

REQUIRED_SCOPES = [
    "main",
    "course",
    "resume",
    "scenarios",
    "dictionary",
    "mine",
    "lessons",
    "step",
    "fav",
    "speaker",
    "profile",
    "games",
]

ACCENT_OPEN = re.compile(r"\[\[")
ACCENT_CLOSE = re.compile(r"\]\]")


def check_accent_syntax(text: str, path: str) -> list[str]:
    errors: list[str] = []
    opens = len(ACCENT_OPEN.findall(text))
    closes = len(ACCENT_CLOSE.findall(text))
    if opens != closes:
        errors.append(f"{path}: unbalanced [[ ]] ({opens} opens, {closes} closes)")
    return errors


def main() -> int:
    if not JSON_PATH.exists():
        print(f"ERROR: missing {JSON_PATH}")
        return 1

    try:
        data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON: {exc}")
        return 1

    errors: list[str] = []
    warnings: list[str] = []

    if "version" not in data:
        warnings.append("missing top-level 'version'")

    for scope in REQUIRED_SCOPES:
        block = data.get(scope)
        if block is None:
            errors.append(f"missing scope '{scope}'")
            continue
        if not isinstance(block, dict):
            errors.append(f"scope '{scope}' must be an object")
            continue
        messages = block.get("messages")
        reactions = block.get("reactions")
        if not isinstance(messages, list):
            errors.append(f"{scope}.messages must be an array")
            continue
        if not isinstance(reactions, list):
            errors.append(f"{scope}.reactions must be an array")
            continue
        if len(messages) == 0:
            warnings.append(f"{scope}: empty messages[]")
        for i, msg in enumerate(messages):
            if not isinstance(msg, str) or not msg.strip():
                errors.append(f"{scope}.messages[{i}]: empty or non-string")
            else:
                errors.extend(check_accent_syntax(msg, f"{scope}.messages[{i}]"))

    extra_keys = set(data.keys()) - set(REQUIRED_SCOPES) - {"version"}
    if extra_keys:
        warnings.append(f"unknown top-level keys: {sorted(extra_keys)}")

    print(f"taikafm.json — {JSON_PATH}")
    print(f"version: {data.get('version', '?')}")
    print()
    for scope in REQUIRED_SCOPES:
        if scope in data and isinstance(data[scope], dict):
            msgs = data[scope].get("messages", [])
            reacts = data[scope].get("reactions", [])
            print(f"  {scope:12} {len(msgs):3} messages, {len(reacts)} reactions")

    if warnings:
        print("\nWarnings:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("\nErrors:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
