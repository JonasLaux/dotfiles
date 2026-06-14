# dotfiles

Private dotfiles and personal agent instructions.

## Agent instructions

The personal instructions live as small fragments:

- `custom/personal-operating-contract.md`
- `custom/codex-autonomy-directive.md`
- `custom/claude-global-instructions.md`

The sync script updates only personal sections. It preserves generated OMC/OMX
blocks in `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.

Preview changes:

```bash
scripts/sync-agent-instructions.sh --dry-run
```

Check for drift:

```bash
scripts/sync-agent-instructions.sh --check
```

Sync into local tools:

```bash
scripts/sync-agent-instructions.sh --to-home
```

This updates:

- `~/.codex/AGENTS.md`, replacing only the personal contract and autonomy directive markers
- `~/.claude/CLAUDE.md`, replacing only the personal contract and `<!-- User customizations -->` section

Refresh the repo fragments from the current home files:

```bash
scripts/sync-agent-instructions.sh --from-home
```

`--from-claude` is kept as a compatibility alias for `--from-home`.

The script is intended to work on macOS and Linux. It avoids in-place `sed`
differences and requires Bash plus Python 3.

Run the regression test with:

```bash
bash tests/test-sync-agent-instructions.sh
```
