#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
start_tmux sh
tmux_test set-option -g prefix C-a
tmux_test set-option -g status-style default
tmux_test set-option -g pane-border-style default
before=$(tmux_test show-options -gv prefix)
status_before=$(tmux_test show-options -gv status-style)
border_before=$(tmux_test show-options -gv pane-border-style)
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
assert_eq "$before" "$(tmux_test show-options -gv prefix)"
assert_eq "$status_before" "$(tmux_test show-options -gv status-style)"
assert_eq "$border_before" "$(tmux_test show-options -gv pane-border-style)"
tmux_test list-keys -T prefix S | assert_contains 'scripts/action enter'
tmux_test list-keys -T prefix | assert_not_contains 'set-option -g prefix'
tmux_test list-keys -T awesome-sidebar | assert_contains 'navigate'
tmux_test list-keys -T awesome-sidebar | assert_contains 'down'
assert_success "$PROJECT_ROOT/scripts/action" enter '$1' '@1' '%1'
assert_file_contains "$PROJECT_ROOT/README.md" "set -g @plugin 'hannadrehman/tmux-awesome-sidebar'"
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_worktree_roots'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_width'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_icons'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_key'
assert_file_not_contains "$PROJECT_ROOT/README.md" 'set -g prefix C-a'
assert_file_not_contains "$PROJECT_ROOT/README.md" '@dracula'
tmux_test set-option -g @awesome_sidebar_key X
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
tmux_test list-keys -T prefix X | assert_contains 'scripts/action enter'
