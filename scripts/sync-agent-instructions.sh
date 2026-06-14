#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-agent-instructions.sh [--to-home|--from-claude]

--to-home      Install custom/agent-instructions.md into ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md (default)
--from-claude  Refresh custom/agent-instructions.md from the "<!-- User customizations -->" section of ~/.claude/CLAUDE.md
USAGE
}

mode="${1:---to-home}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
custom_file="$repo_root/custom/agent-instructions.md"
claude_file="$HOME/.claude/CLAUDE.md"
codex_file="$HOME/.codex/AGENTS.md"
marker='<!-- User customizations -->'

case "$mode" in
  --from-claude)
    mkdir -p "$(dirname "$custom_file")"
    if [[ ! -f "$claude_file" ]]; then
      echo "Missing $claude_file" >&2
      exit 1
    fi
    python - "$claude_file" "$custom_file" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
marker = '<!-- User customizations -->'
text = src.read_text()
if marker not in text:
    raise SystemExit(f'Marker not found in {src}')
dst.write_text(text.split(marker, 1)[1].strip() + '\n')
PY
    echo "Updated $custom_file from $claude_file"
    ;;
  --to-home)
    if [[ ! -f "$custom_file" ]]; then
      echo "Missing $custom_file" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$claude_file")" "$(dirname "$codex_file")"
    python - "$custom_file" "$claude_file" <<'PY'
from pathlib import Path
import sys
custom = Path(sys.argv[1]).read_text().strip() + '\n'
claude = Path(sys.argv[2])
marker = '<!-- User customizations -->'
if claude.exists():
    text = claude.read_text()
    prefix = text.split(marker, 1)[0].rstrip() if marker in text else text.rstrip()
else:
    prefix = '# User-Level Claude Code Instructions'
claude.write_text(prefix + '\n\n' + marker + '\n' + custom)
PY
    cat > "$codex_file" <<EOF2
# User-Level Codex Instructions

<!-- Synced from dotfiles/custom/agent-instructions.md. Edit there, then run scripts/sync-agent-instructions.sh --to-home. -->

$(cat "$custom_file")
EOF2
    echo "Synced custom agent instructions to:"
    echo "  $claude_file"
    echo "  $codex_file"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
