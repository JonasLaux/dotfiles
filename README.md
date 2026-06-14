# dotfiles

Private dotfiles and personal agent instructions.

## Agent instructions

The shared custom instructions live in:

- `custom/agent-instructions.md`

Sync them into local tools with:

```bash
scripts/sync-agent-instructions.sh --to-home
```

This updates:

- `~/.claude/CLAUDE.md` after the `<!-- User customizations -->` marker, preserving managed content above it
- `~/.codex/AGENTS.md`

Refresh the repo copy from Claude Code with:

```bash
scripts/sync-agent-instructions.sh --from-claude
```
