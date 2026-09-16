#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
tmux_test new-window -d -t test -n second
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable

session_id=$(tmux_test display-message -p -t test '#{session_id}')
tab=$(printf '\t')
second_window=$(tmux_test list-windows -t "$session_id" -F "#{window_id}${tab}#{window_name}" | awk -F '\t' '$2=="second"{print $1}')
second_sidebar=$(tmux_test list-panes -t "$second_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1}')
[ -n "$second_sidebar" ]

# Multiple content splits still leave exactly one absolute-left sidebar.
content=$(tmux_test list-panes -t "$second_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2!="sidebar"{print $1;exit}')
tmux_test split-window -d -h -t "$content"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable-window "$session_id" "$second_window"
assert_eq 1 "$(tmux_test list-panes -t "$second_window" -F '#{@awesome_sidebar_kind}' | awk '$0=="sidebar"{n++} END{print n+0}')" "one sidebar per window"
assert_eq 0 "$(tmux_test display-message -p -t "$second_sidebar" '#{pane_left}')" "sidebar remains leftmost"

# The sidebar model contains exactly one row per native tmux window and no
# pane, worktree, or other child rows.
rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$session_id")
expected=$(tmux_test list-windows -t "$session_id" | wc -l | awk '{print $1}')
assert_eq "$expected" "$(printf '%s\n' "$rows" | awk -F '\t' '$1=="session"{n++} END{print n+0}')" "one row per tmux window"
assert_eq 0 "$(printf '%s\n' "$rows" | awk -F '\t' '$1!="session"{n++} END{print n+0}')" "no child row types"
