#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-agent-instructions.sh [--to-home|--to-codex|--check|--check-codex|--dry-run]

--to-home      Sync repo fragments into ~/.codex/AGENTS.md and ~/.claude/CLAUDE.md
--to-codex     Sync repo fragments into ~/.codex/AGENTS.md only
--check        Exit non-zero when home files differ from repo fragments
--check-codex  Exit non-zero when ~/.codex/AGENTS.md differs from its source
--dry-run      Print unified diffs without writing
USAGE
}

mode="${1:---to-codex}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$mode" in
  --to-home|--to-codex|--check|--check-codex|--dry-run)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

find_python() {
  local candidate
  if [[ -n "${PYTHON:-}" ]]; then
    candidate="$PYTHON"
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  fi

  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

python_bin="$(find_python)" || {
  echo "python3 is required for marker-aware sync" >&2
  exit 1
}

"$python_bin" - "$mode" "$repo_root" "${HOME:?HOME is required}" <<'PY'
import difflib
import os
import sys
from pathlib import Path

mode = sys.argv[1]
repo_root = Path(sys.argv[2])
home = Path(sys.argv[3]).expanduser()

custom_dir = repo_root / "custom"
codex_global_path = custom_dir / "codex-global-instructions.md"
claude_custom_path = custom_dir / "claude-global-instructions.md"

codex_path = home / ".codex" / "AGENTS.md"
claude_path = home / ".claude" / "CLAUDE.md"

def read_text(path):
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def normalized_file(path):
    if not path.exists():
        raise SystemExit(f"Missing {path}")
    return read_text(path).strip() + "\n"


def build_codex(existing):
    return normalized_file(codex_global_path)


def build_claude(existing):
    return normalized_file(claude_custom_path)


def desired_files():
    return {
        codex_path: build_codex(read_text(codex_path)),
        claude_path: build_claude(read_text(claude_path)),
    }


def diff_text(path, current, desired):
    return "".join(
        difflib.unified_diff(
            current.splitlines(keepends=True),
            desired.splitlines(keepends=True),
            fromfile=f"{path} (current)",
            tofile=f"{path} (desired)",
        )
    )


def write_if_changed(path, desired):
    current = read_text(path)
    if current == desired:
        print(f"unchanged {path}")
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    tmp.write_text(desired, encoding="utf-8")
    os.replace(tmp, path)
    print(f"updated {path}")
    return True


if mode == "--check-codex":
    desired = build_codex(read_text(codex_path))
    if read_text(codex_path) != desired:
        print(f"Agent instructions are out of sync: {codex_path}")
        raise SystemExit(1)
    print("Codex agent instructions are in sync")
elif mode == "--check":
    drifted = []
    for path, desired in desired_files().items():
        if read_text(path) != desired:
            drifted.append(path)
    if drifted:
        print("Agent instructions are out of sync:")
        for path in drifted:
            print(f"  {path}")
        raise SystemExit(1)
    print("Agent instructions are in sync")
elif mode == "--dry-run":
    changed = False
    for path, desired in desired_files().items():
        current = read_text(path)
        if current != desired:
            changed = True
            print(diff_text(path, current, desired), end="")
    if not changed:
        print("Agent instructions are in sync")
elif mode == "--to-home":
    changed = False
    for path, desired in desired_files().items():
        changed = write_if_changed(path, desired) or changed
    if not changed:
        print("Agent instructions are already in sync")
elif mode == "--to-codex":
    write_if_changed(codex_path, build_codex(read_text(codex_path)))
else:
    raise SystemExit(f"Unsupported mode: {mode}")
PY
