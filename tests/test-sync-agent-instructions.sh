#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/sync-agent-instructions.sh"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-agent-sync.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home/.codex" "$home/.claude"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    printf -- '--- %s ---\n' "$file" >&2
    sed -n '1,220p' "$file" >&2
    fail "expected $file to contain: $needle"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    printf -- '--- %s ---\n' "$file" >&2
    sed -n '1,220p' "$file" >&2
    fail "expected $file not to contain: $needle"
  fi
}

cat > "$home/.codex/AGENTS.md" <<'EOF_Codex'
<!-- PERSONAL OPERATING CONTRACT — PREPEND AND PRESERVE -->
old codex personal block
<!-- END PERSONAL OPERATING CONTRACT -->

<!-- AUTONOMY DIRECTIVE — DO NOT REMOVE -->
old autonomy block
<!-- END AUTONOMY DIRECTIVE -->
<!-- CODEX GLOBAL DELEGATION POLICY -->
old delegation block
<!-- END CODEX GLOBAL DELEGATION POLICY -->
<!-- omx:generated:agents-md -->

# Generated Codex Body

KEEP OMX GENERATED CONTENT
EOF_Codex

cat > "$home/.claude/CLAUDE.md" <<'EOF_Claude'
<!-- PERSONAL OPERATING CONTRACT — PREPEND AND PRESERVE -->
old claude personal block
<!-- END PERSONAL OPERATING CONTRACT -->

<!-- OMC:START -->
# Generated Claude Body

KEEP OMC GENERATED CONTENT
<!-- OMC:END -->

<!-- User customizations -->
old claude user customizations
EOF_Claude

if HOME="$home" "$script" --check >/tmp/dotfiles-agent-check.out 2>&1; then
  fail '--check should fail before syncing stale files'
fi

before_codex="$(cksum "$home/.codex/AGENTS.md")"
HOME="$home" "$script" --dry-run >/tmp/dotfiles-agent-dry-run.out
after_codex="$(cksum "$home/.codex/AGENTS.md")"
[[ "$before_codex" == "$after_codex" ]] || fail '--dry-run mutated the Codex file'
assert_contains /tmp/dotfiles-agent-dry-run.out '.codex/AGENTS.md'

HOME="$home" "$script" --to-home
HOME="$home" "$script" --check

assert_contains "$home/.codex/AGENTS.md" 'Default to zoomed-out, high-level, simplified explanations.'
assert_contains "$home/.codex/AGENTS.md" '## ADHD-Friendly Communication Default'
assert_contains "$home/.codex/AGENTS.md" '**Problem:**'
assert_contains "$home/.codex/AGENTS.md" 'When work is unfinished, end with one concrete next action.'
assert_contains "$home/.codex/AGENTS.md" 'YOU ARE AN AUTONOMOUS CODING AGENT.'
assert_contains "$home/.codex/AGENTS.md" 'The main thread is the Sol orchestrator.'
assert_contains "$home/.codex/AGENTS.md" 'KEEP OMX GENERATED CONTENT'
assert_not_contains "$home/.codex/AGENTS.md" 'old codex personal block'
assert_not_contains "$home/.codex/AGENTS.md" 'old autonomy block'
assert_not_contains "$home/.codex/AGENTS.md" 'old delegation block'

assert_contains "$home/.claude/CLAUDE.md" 'Default to zoomed-out, high-level, simplified explanations.'
assert_contains "$home/.claude/CLAUDE.md" '## ADHD-Friendly Communication Default'
assert_contains "$home/.claude/CLAUDE.md" '**Need from you:**'
assert_contains "$home/.claude/CLAUDE.md" 'When work is unfinished, end with one concrete next action.'
assert_contains "$home/.claude/CLAUDE.md" 'Never use em dashes'
assert_contains "$home/.claude/CLAUDE.md" 'KEEP OMC GENERATED CONTENT'
assert_not_contains "$home/.claude/CLAUDE.md" 'old claude personal block'
assert_not_contains "$home/.claude/CLAUDE.md" 'old claude user customizations'

printf 'sync-agent-instructions tests passed\n'

codex_only_home="$tmpdir/codex-only-home"
mkdir -p "$codex_only_home/.codex" "$codex_only_home/.claude"
cp "$home/.codex/AGENTS.md" "$codex_only_home/.codex/AGENTS.md"
cp "$home/.claude/CLAUDE.md" "$codex_only_home/.claude/CLAUDE.md"
printf '\nCLAUDE ONLY SENTINEL\n' >> "$codex_only_home/.claude/CLAUDE.md"
HOME="$codex_only_home" "$script" --to-codex
assert_contains "$codex_only_home/.codex/AGENTS.md" 'The main thread is the Sol orchestrator.'
assert_contains "$codex_only_home/.claude/CLAUDE.md" 'CLAUDE ONLY SENTINEL'

printf 'codex-only sync test passed\n'
