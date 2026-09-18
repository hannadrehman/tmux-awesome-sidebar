#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable

session_id=$(tmux_test display-message -p -t test '#{session_id}')
window_id=$(tmux_test display-message -p -t test: '#{window_id}')
sidebar=$(tmux_test list-panes -t "$window_id" -F '#{pane_id} #{@awesome_sidebar_kind}' | awk '$2=="sidebar"{print $1;exit}')
group=$(tmux_test show-option -wqv -t "$window_id" @awesome_sidebar_group)
marker=$TMUX_TMPDIR/prompt-command-executed
payload='$(touch '"$marker"'); display-message pwned'

tmux_test set-option -p -t "$sidebar" @awesome_sidebar_pending_query "$payload"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" search-update "$group" "$sidebar"
assert_eq "$payload" "$(tmux_test show-option -pqv -t "$sidebar" @awesome_sidebar_query)" "search state"
assert_failure test -e "$marker"
assert_file_not_contains "$PROJECT_ROOT/scripts/sidebar-view" 'eval '
assert_file_not_contains "$PROJECT_ROOT/scripts/sidebar-view" 'capture-pane'
assert_file_not_contains "$PROJECT_ROOT/scripts/sidebar-view" 'show-environment'
