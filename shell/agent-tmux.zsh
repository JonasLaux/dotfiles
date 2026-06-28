# Shared tmux launch helpers for CLI agents.
#
# Source this from ~/.zshrc. The functions open a fresh tmux session named after
# the current directory, unless already inside tmux.

if (( ! ${+CLAUDE_FLAGS} )); then
    CLAUDE_FLAGS=(--dangerously-skip-permissions)
fi

alias claude='command claude "${CLAUDE_FLAGS[@]}"'
alias claudeDash='command claude agents'

if (( ! ${+CODEX_FLAGS} )); then
    CODEX_FLAGS=()
fi

alias codex='command codex "${CODEX_FLAGS[@]}"'

_agent_tmux_launch() {
    local prefix="$1"
    shift

    if [ $# -eq 0 ]; then
        print -u2 "_agent_tmux_launch: missing command"
        return 2
    fi

    if ! command -v tmux >/dev/null 2>&1 || [ -n "${TMUX:-}" ]; then
        "$@"
        return
    fi

    local base_name
    local session_name
    local candidate
    local n=1
    local quoted_title
    local quoted_cmd

    base_name="$(basename "$PWD")"
    session_name="${prefix}-${base_name}"
    candidate="$session_name"

    while command tmux has-session -t "$candidate" 2>/dev/null; do
        n=$((n + 1))
        candidate="${session_name}-${n}"
    done

    quoted_title="$(printf '%q' "$candidate")"
    quoted_cmd="$(printf '%q ' "$@")"

    command tmux new-session -d -s "$candidate" -n "$candidate" -c "$PWD" \
        "printf '\033]0;%s\007' $quoted_title; exec $quoted_cmd"
    command tmux set-option -t "$candidate" allow-rename off
    command tmux set-option -t "$candidate" automatic-rename off
    command tmux attach -t "$candidate"
}

cc() {
    _agent_tmux_launch cc claude "${CLAUDE_FLAGS[@]}" "$@"
}

co() {
    _agent_tmux_launch co codex "${CODEX_FLAGS[@]}" "$@"
}
