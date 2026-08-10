#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-agent-instructions.sh [--to-home|--to-codex|--check|--dry-run|--from-home|--from-claude]

--to-home      Sync repo fragments into ~/.codex/AGENTS.md and ~/.claude/CLAUDE.md (default)
--to-codex     Sync repo fragments into ~/.codex/AGENTS.md only
--check        Exit non-zero when home files differ from repo fragments
--dry-run      Print unified diffs without writing
--from-home    Refresh repo fragments from current home files
--from-claude  Alias for --from-home
USAGE
}

mode="${1:---to-home}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$mode" in
  --to-home|--to-codex|--check|--dry-run|--from-home|--from-claude)
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
import datetime as _dt
import difflib
import os
import re
import shutil
import sys
from pathlib import Path

mode = sys.argv[1]
repo_root = Path(sys.argv[2])
home = Path(sys.argv[3]).expanduser()

if mode == "--from-claude":
    mode = "--from-home"

custom_dir = repo_root / "custom"
personal_path = custom_dir / "personal-operating-contract.md"
autonomy_path = custom_dir / "codex-autonomy-directive.md"
delegation_path = custom_dir / "codex-global-delegation-policy.md"
claude_custom_path = custom_dir / "claude-global-instructions.md"

codex_path = home / ".codex" / "AGENTS.md"
claude_path = home / ".claude" / "CLAUDE.md"

PERSONAL_START = "<!-- PERSONAL OPERATING CONTRACT — PREPEND AND PRESERVE -->"
PERSONAL_END = "<!-- END PERSONAL OPERATING CONTRACT -->"
AUTONOMY_START = "<!-- AUTONOMY DIRECTIVE — DO NOT REMOVE -->"
AUTONOMY_END = "<!-- END AUTONOMY DIRECTIVE -->"
DELEGATION_START = "<!-- CODEX GLOBAL DELEGATION POLICY -->"
DELEGATION_END = "<!-- END CODEX GLOBAL DELEGATION POLICY -->"
CLAUDE_USER_MARKER = "<!-- User customizations -->"


def read_text(path):
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def normalized_file(path):
    if not path.exists():
        raise SystemExit(f"Missing {path}")
    return read_text(path).strip() + "\n"


def block_regex(start, end):
    return re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.DOTALL)


def insert_after_marker(text, block, marker):
    marker_index = text.find(marker)
    if marker_index == -1:
        if text.strip():
            return text.rstrip() + "\n\n" + block.rstrip() + "\n"
        return block.rstrip() + "\n"

    line_end = text.find("\n", marker_index)
    insert_at = len(text) if line_end == -1 else line_end + 1
    while insert_at < len(text) and text[insert_at] == "\n":
        insert_at += 1

    prefix = text[:insert_at].rstrip()
    suffix = text[insert_at:].lstrip("\n")
    if suffix:
        return prefix + "\n\n" + block.rstrip() + "\n\n" + suffix
    return prefix + "\n\n" + block.rstrip() + "\n"


def replace_or_insert_block(
    text,
    block,
    start,
    end,
    *,
    insert,
    after_marker=None,
):
    replacement = block.rstrip() + "\n"
    pattern = block_regex(start, end)
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)

    if insert == "top":
        if text.strip():
            return replacement + "\n" + text.lstrip("\n")
        return replacement

    if insert == "after" and after_marker is not None:
        return insert_after_marker(text, replacement, after_marker)

    raise RuntimeError(f"Unsupported insert mode: {insert}")


def replace_claude_user_section(text, custom):
    custom = custom.rstrip() + "\n"
    if CLAUDE_USER_MARKER in text:
        prefix = text.split(CLAUDE_USER_MARKER, 1)[0].rstrip()
        return prefix + "\n\n" + CLAUDE_USER_MARKER + "\n" + custom

    if text.strip():
        return text.rstrip() + "\n\n" + CLAUDE_USER_MARKER + "\n" + custom
    return CLAUDE_USER_MARKER + "\n" + custom


def build_codex(existing):
    text = existing.rstrip() + "\n" if existing else ""
    text = replace_or_insert_block(
        text,
        normalized_file(personal_path),
        PERSONAL_START,
        PERSONAL_END,
        insert="top",
    )
    text = replace_or_insert_block(
        text,
        normalized_file(autonomy_path),
        AUTONOMY_START,
        AUTONOMY_END,
        insert="after",
        after_marker=PERSONAL_END,
    )
    text = replace_or_insert_block(
        text,
        normalized_file(delegation_path),
        DELEGATION_START,
        DELEGATION_END,
        insert="after",
        after_marker=AUTONOMY_END,
    )
    return text.rstrip() + "\n"


def build_claude(existing):
    text = existing.rstrip() + "\n" if existing else ""
    text = replace_or_insert_block(
        text,
        normalized_file(personal_path),
        PERSONAL_START,
        PERSONAL_END,
        insert="top",
    )
    text = replace_claude_user_section(text, normalized_file(claude_custom_path))
    return text.rstrip() + "\n"


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
    if path.exists():
        stamp = _dt.datetime.now().strftime("%Y%m%d%H%M%S")
        backup = path.with_name(f"{path.name}.bak.{stamp}")
        shutil.copy2(path, backup)
        print(f"backup {backup}")

    tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    tmp.write_text(desired, encoding="utf-8")
    os.replace(tmp, path)
    print(f"updated {path}")
    return True


def extract_block(text, start, end, source):
    match = block_regex(start, end).search(text)
    if not match:
        raise SystemExit(f"Could not find block {start} in {source}")
    return match.group(0).strip() + "\n"


def write_fragment(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip() + "\n", encoding="utf-8")
    print(f"updated {path}")


if mode == "--check":
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
elif mode == "--from-home":
    codex = read_text(codex_path)
    claude = read_text(claude_path)
    if not codex and not claude:
        raise SystemExit(f"Missing both {codex_path} and {claude_path}")

    personal_source = codex if PERSONAL_START in codex else claude
    personal_source_path = codex_path if PERSONAL_START in codex else claude_path
    write_fragment(
        personal_path,
        extract_block(personal_source, PERSONAL_START, PERSONAL_END, personal_source_path),
    )
    write_fragment(
        autonomy_path,
        extract_block(codex, AUTONOMY_START, AUTONOMY_END, codex_path),
    )
    write_fragment(
        delegation_path,
        extract_block(codex, DELEGATION_START, DELEGATION_END, codex_path),
    )
    if CLAUDE_USER_MARKER not in claude:
        raise SystemExit(f"Could not find {CLAUDE_USER_MARKER} in {claude_path}")
    write_fragment(claude_custom_path, claude.split(CLAUDE_USER_MARKER, 1)[1])
else:
    raise SystemExit(f"Unsupported mode: {mode}")
PY
