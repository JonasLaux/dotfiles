# dotfiles

Private dotfiles and personal agent instructions.

## Agent instructions

The personal instructions live as small fragments:

- `custom/personal-operating-contract.md`
- `custom/codex-global-instructions.md`
- `custom/claude-global-instructions.md`
- `skills/google-developer-communication/SKILL.md`

Codex uses the standalone `custom/codex-global-instructions.md` source. Syncing
Codex replaces `~/.codex/AGENTS.md` completely, which removes stale generated
framework instructions. The shared personal contract and Claude source remain
separate.

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

Use `--check-codex` to check Codex without requiring the separate Claude file
to match its source.

Sync into local tools:

```bash
scripts/sync-agent-instructions.sh --to-codex
```

This updates:

- `~/.codex/AGENTS.md`, from the standalone Codex source
- `~/.claude/CLAUDE.md`, only when the explicit `--to-home` mode is used

Use `--to-codex` for Codex-only changes. Writes do not create backup files.

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
