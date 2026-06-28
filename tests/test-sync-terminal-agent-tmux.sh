#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/sync-terminal-agent-tmux.sh"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-terminal-sync.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    printf '--- %s ---\n' "$file" >&2
    sed -n '1,220p' "$file" >&2
    fail "expected $file to contain: $needle"
  fi
}

cat > "$home/.zshrc" <<'EOF_ZSHRC'
# existing local shell config
export KEEP_ME=1
EOF_ZSHRC

cat > "$home/.tmux.conf" <<'EOF_TMUX'
# stale tmux config
set -g mouse off
EOF_TMUX

if HOME="$home" "$script" --check >"$tmpdir/check.out" 2>&1; then
  fail '--check should fail before syncing stale files'
fi

before_zshrc="$(cksum "$home/.zshrc")"
HOME="$home" "$script" --dry-run >"$tmpdir/dry-run.out"
after_zshrc="$(cksum "$home/.zshrc")"
[[ "$before_zshrc" == "$after_zshrc" ]] || fail '--dry-run mutated the zshrc file'
assert_contains "$tmpdir/dry-run.out" '.config/dotfiles/agent-tmux.zsh'
assert_contains "$tmpdir/dry-run.out" '.tmux.conf'

HOME="$home" "$script" --to-home
HOME="$home" "$script" --check

assert_contains "$home/.zshrc" '# existing local shell config'
assert_contains "$home/.zshrc" '# >>> dotfiles agent tmux launchers >>>'
assert_contains "$home/.zshrc" 'source "$HOME/.config/dotfiles/agent-tmux.zsh"'
assert_contains "$home/.config/dotfiles/agent-tmux.zsh" 'cc()'
assert_contains "$home/.config/dotfiles/agent-tmux.zsh" 'co()'
assert_contains "$home/.config/dotfiles/agent-tmux.zsh" 'CLAUDE_FLAGS=(--dangerously-skip-permissions)'
assert_contains "$home/.tmux.conf" 'set -g focus-events on'
assert_contains "$home/.tmux.conf" 'set -g mouse on'

before_all="$(find "$home" -type f -print0 | sort -z | xargs -0 cksum)"
HOME="$home" "$script" --to-home >"$tmpdir/second-sync.out"
after_all="$(find "$home" -type f -print0 | sort -z | xargs -0 cksum)"
[[ "$before_all" == "$after_all" ]] || fail '--to-home should be idempotent'

printf 'sync-terminal-agent-tmux tests passed\n'
