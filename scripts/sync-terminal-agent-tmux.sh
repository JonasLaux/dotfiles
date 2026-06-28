#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-terminal-agent-tmux.sh [--to-home|--check|--dry-run]

--to-home  Install tmux config and zsh agent launchers into $HOME (default)
--check    Exit non-zero when home files differ from repo config
--dry-run  Print unified diffs without writing
USAGE
}

mode="${1:---to-home}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$mode" in
  --to-home|--check|--dry-run)
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
  echo "python3 is required for terminal agent tmux sync" >&2
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

source_fragment = repo_root / "shell" / "agent-tmux.zsh"
source_tmux = repo_root / "tmux" / "tmux.conf"

installed_fragment = home / ".config" / "dotfiles" / "agent-tmux.zsh"
zshrc = home / ".zshrc"
tmux_conf = home / ".tmux.conf"

START = "# >>> dotfiles agent tmux launchers >>>"
END = "# <<< dotfiles agent tmux launchers <<<"
SOURCE_LINE = '[[ -r "$HOME/.config/dotfiles/agent-tmux.zsh" ]] && source "$HOME/.config/dotfiles/agent-tmux.zsh"'


def read_text(path):
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def normalized_file(path):
    if not path.exists():
        raise SystemExit(f"Missing {path}")
    return read_text(path).strip() + "\n"


def zsh_source_block():
    return f"{START}\n{SOURCE_LINE}\n{END}\n"


def build_zshrc(existing):
    block = zsh_source_block()
    pattern = re.compile(re.escape(START) + r".*?" + re.escape(END) + r"\n?", re.DOTALL)
    if pattern.search(existing):
        return pattern.sub(block, existing, count=1).rstrip() + "\n"

    if existing.strip():
        return existing.rstrip() + "\n\n" + block
    return block


def desired_files():
    return {
        installed_fragment: normalized_file(source_fragment),
        tmux_conf: normalized_file(source_tmux),
        zshrc: build_zshrc(read_text(zshrc)),
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


if mode == "--check":
    drifted = []
    for path, desired in desired_files().items():
        if read_text(path) != desired:
            drifted.append(path)
    if drifted:
        print("Terminal agent tmux config is out of sync:")
        for path in drifted:
            print(f"  {path}")
        raise SystemExit(1)
    print("Terminal agent tmux config is in sync")
elif mode == "--dry-run":
    changed = False
    for path, desired in desired_files().items():
        current = read_text(path)
        if current != desired:
            changed = True
            print(diff_text(path, current, desired), end="")
    if not changed:
        print("Terminal agent tmux config is in sync")
elif mode == "--to-home":
    changed = False
    for path, desired in desired_files().items():
        changed = write_if_changed(path, desired) or changed
    if not changed:
        print("Terminal agent tmux config is already in sync")
else:
    raise SystemExit(f"Unsupported mode: {mode}")
PY
