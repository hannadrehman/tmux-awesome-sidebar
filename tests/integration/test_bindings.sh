#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
tmux_test set-option -g prefix C-a
tmux_test set-option -g status-style default
tmux_test set-option -g pane-border-style default
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
before=$(tmux_test show-options -gv prefix)
status_before=$(tmux_test show-options -gv status-style)
border_before=$(tmux_test show-options -gv pane-border-style)

tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
session_id=$(tmux_test display-message -p -t test '#{session_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable

assert_eq "$before" "$(tmux_test show-options -gv prefix)"
assert_eq "$status_before" "$(tmux_test show-options -gv status-style)"
assert_eq "$border_before" "$(tmux_test show-options -gv pane-border-style)"
assert_file_not_contains "$PROJECT_ROOT/tmux-awesome-sidebar.tmux" 'bind-key'
assert_file_not_contains "$PROJECT_ROOT/tmux-awesome-sidebar.tmux" '@awesome_sidebar_key'
tmux_test show-hooks -g | assert_contains 'after-new-window'
tmux_test show-hooks -g | assert_contains 'auto-enable-window'
[ -x "$PROJECT_ROOT/scripts/sidebar-view" ]
assert_eq 0 "$(tmux_test list-sessions -F '#{session_name}' | awk '/^__awesome_sidebar_/{n++} END{print n+0}')" "no hidden storage sessions"
assert_eq "session-${session_id#\$}" "$(tmux_test show-option -qv -t "$session_id" @awesome_sidebar_group)"

assert_file_contains "$PROJECT_ROOT/README.md" "set -g @plugin 'hannadrehman/tmux-awesome-sidebar'"
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_width'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_icons'
assert_file_not_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_key'
assert_file_not_contains "$PROJECT_ROOT/README.md" 'set -g prefix C-a'
assert_file_not_contains "$PROJECT_ROOT/README.md" '@dracula'
