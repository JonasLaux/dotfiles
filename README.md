# dotfiles

Private dotfiles and personal agent instructions.

## Agent instructions

The personal instructions live as small fragments:

- `custom/personal-operating-contract.md`
- `custom/codex-autonomy-directive.md`
- `custom/codex-global-delegation-policy.md`
- `custom/claude-global-instructions.md`
- `skills/google-developer-communication/SKILL.md`

The sync script updates only managed instruction sections. It preserves generated
OMC/OMX blocks in `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.

Codex's machine-local runtime defaults are kept in `~/.codex/config.toml`:

```toml
model = "gpt-5.6-sol"

[agents]
default_subagent_model = "gpt-5.6-luna"
default_subagent_reasoning_effort = "high"
```

The config file itself is not tracked because it contains machine-local paths,
plugin state, and environment settings.

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

- `~/.codex/AGENTS.md`, replacing only the managed personal, autonomy, and Codex delegation blocks
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

## Terminal agent tmux setup

The portable `cc` / `co` setup lives in:

- `shell/agent-tmux.zsh`
- `tmux/tmux.conf`

Install or refresh it on a machine with:

```bash
scripts/sync-terminal-agent-tmux.sh --to-home
```

This updates:

- `~/.config/dotfiles/agent-tmux.zsh`, copied from the repo
- `~/.tmux.conf`, copied from `tmux/tmux.conf`
- `~/.zshrc`, adding one managed source block while preserving the rest of the file

Preview changes:

```bash
scripts/sync-terminal-agent-tmux.sh --dry-run
```

Check for drift:

```bash
scripts/sync-terminal-agent-tmux.sh --check
```

The full home `~/.zshrc` is intentionally not tracked because it can contain
tokens and machine-local environment variables.

Run the regression test with:

```bash
bash tests/test-sync-terminal-agent-tmux.sh
```
