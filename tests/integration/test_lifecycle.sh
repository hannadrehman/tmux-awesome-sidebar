#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
start_tmux sh
session_id=$(tmux_test display-message -p '#{session_id}')
window_id=$(tmux_test display-message -p '#{window_id}')
pane_id=$(tmux_test display-message -p '#{pane_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$pane_id"
assert_eq 2 "$(tmux_test list-panes -t "$window_id" | wc -l | awk '{print $1}')"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" disable "$session_id"
assert_eq 1 "$(tmux_test list-panes -t "$window_id" | wc -l | awk '{print $1}')"
