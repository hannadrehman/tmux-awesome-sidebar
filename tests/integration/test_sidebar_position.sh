#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
session_id=$(tmux_test display-message -p '#{session_id}')
window_id=$(tmux_test display-message -p '#{window_id}')
content_pane=$(tmux_test display-message -p '#{pane_id}')
extra_content=$(tmux_test split-window -d -h -p 30 -t "$window_id" -P -F '#{pane_id}')

legacy_sidebar=$(tmux_test split-window -d -h -p 28 -t "$window_id" -P -F '#{pane_id}')
tmux_test set-option -p -t "$legacy_sidebar" @awesome_sidebar_kind sidebar
tmux_test set-option -p -t "$legacy_sidebar" @awesome_sidebar_cursor '@remembered'
[ "$(tmux_test display-message -p -t "$legacy_sidebar" '#{pane_left}')" -gt 0 ]
tmux_test select-pane -t "$extra_content"

TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$content_pane"

tab=$(printf '\t')
sidebar=$(tmux_test list-panes -t "$window_id" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" |
  awk -F '\t' '$2=="sidebar"{print $1;exit}')
[ -n "$sidebar" ]
assert_eq 0 "$(tmux_test display-message -p -t "$sidebar" '#{pane_left}')" "legacy sidebar migrates left"
content_path=$(tmux_test display-message -p -t "$content_pane" '#{pane_current_path}')
worktree_path=$(git -C "$content_path" rev-parse --show-toplevel 2>/dev/null || :)
if [ -n "$worktree_path" ]; then expected_cursor=worktree:$(CDPATH= cd -- "$worktree_path" && pwd -P); else expected_cursor=$window_id; fi
assert_eq "$expected_cursor" "$(tmux_test show-option -p -qv -t "$sidebar" @awesome_sidebar_cursor)" "invalid legacy cursor resets to active tab row"
assert_eq 1 "$(tmux_test display-message -p -t "$sidebar" '#{pane_active}')" "migrated sidebar is focused"
