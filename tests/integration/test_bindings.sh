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
assert_eq "$before" "$(tmux_test show-options -gv prefix)"
assert_eq "$status_before" "$(tmux_test show-options -gv status-style)"
assert_eq "$border_before" "$(tmux_test show-options -gv pane-border-style)"
tmux_test list-keys -T prefix S | assert_contains 'scripts/action'
tmux_test list-keys -T prefix S | assert_contains ' enter '
assert_file_contains "$PROJECT_ROOT/scripts/action" 'switch-client -T awesome-sidebar'
tmux_test list-keys -T prefix | assert_not_contains 'set-option -g prefix'
tmux_test list-keys -T awesome-sidebar | assert_contains 'navigate'
tmux_test list-keys -T awesome-sidebar | assert_contains 'down'
tmux_test list-keys -T awesome-sidebar Up | assert_contains 'navigate'
tmux_test list-keys -T awesome-sidebar Up | assert_contains 'up'
tmux_test list-keys -T awesome-sidebar Down | assert_contains 'navigate'
tmux_test list-keys -T awesome-sidebar Down | assert_contains 'down'
tmux_test list-keys -T awesome-sidebar | assert_contains 'command-prompt'
tmux_test show-hooks -g | assert_contains 'after-new-window'
tmux_test show-hooks -g | assert_contains 'auto-enable'
assert_success "$PROJECT_ROOT/scripts/action" enter '$1' '@1' '%1'
assert_file_contains "$PROJECT_ROOT/README.md" "set -g @plugin 'hannadrehman/tmux-awesome-sidebar'"
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_worktree_roots'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_width'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_icons'
assert_file_contains "$PROJECT_ROOT/README.md" '@awesome_sidebar_key'
assert_file_not_contains "$PROJECT_ROOT/README.md" 'set -g prefix C-a'
assert_file_not_contains "$PROJECT_ROOT/README.md" '@dracula'
session_id=$(tmux_test display-message -p '#{session_id}')
window_id=$(tmux_test display-message -p '#{window_id}')
pane_id=$(tmux_test display-message -p '#{pane_id}')
mkdir -p "$TMUX_TMPDIR/caller"
(cd "$TMUX_TMPDIR/caller" && TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$pane_id")
tmux_test set-option -g @awesome_sidebar_key X
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
tmux_test list-keys -T prefix X | assert_contains 'scripts/action'
tmux_test list-keys -T prefix S | assert_contains "$PROJECT_ROOT/scripts/action"
