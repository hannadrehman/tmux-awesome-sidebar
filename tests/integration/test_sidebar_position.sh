#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
session_id=$(tmux_test display-message -p '#{session_id}')
window_id=$(tmux_test display-message -p '#{window_id}')
content_pane=$(tmux_test display-message -p '#{pane_id}')

legacy_sidebar=$(tmux_test split-window -d -h -p 28 -t "$window_id" -P -F '#{pane_id}')
tmux_test set-option -p -t "$legacy_sidebar" @awesome_sidebar_kind sidebar
tmux_test set-option -p -t "$legacy_sidebar" @awesome_sidebar_cursor '@remembered'
[ "$(tmux_test display-message -p -t "$legacy_sidebar" '#{pane_left}')" -gt 0 ]

TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$content_pane"

tab=$(printf '\t')
sidebar=$(tmux_test list-panes -t "$window_id" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" |
  awk -F '\t' '$2=="sidebar"{print $1;exit}')
[ -n "$sidebar" ]
assert_eq 0 "$(tmux_test display-message -p -t "$sidebar" '#{pane_left}')" "legacy sidebar migrates left"
assert_eq '@remembered' "$(tmux_test show-option -p -qv -t "$sidebar" @awesome_sidebar_cursor)" "cursor survives migration"
assert_eq 1 "$(tmux_test display-message -p -t "$sidebar" '#{pane_active}')" "migrated sidebar is focused"
