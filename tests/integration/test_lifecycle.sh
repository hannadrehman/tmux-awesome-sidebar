#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
tmux_test rename-window -t test:0 frontend
tmux_test new-window -d -t test -n backend
tmux_test new-window -d -t test -n tests
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable

session_id=$(tmux_test display-message -p -t test '#{session_id}')
tab=$(printf '\t')
windows=$(tmux_test list-windows -t "$session_id" -F '#{window_id}')
for window in $windows; do
  sidebar=$(tmux_test list-panes -t "$window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" |
    awk -F '\t' '$2=="sidebar"{print $1;exit}')
  [ -n "$sidebar" ]
  assert_eq 0 "$(tmux_test display-message -p -t "$sidebar" '#{pane_left}')" "sidebar is leftmost"
  assert_eq 0 "$(tmux_test display-message -p -t "$sidebar" '#{pane_dead}')" "sidebar process is running"
done

rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$session_id")
assert_eq 3 "$(printf '%s\n' "$rows" | awk -F '\t' '$1=="session"{n++} END{print n+0}')" "all windows are listed"

first_window=$(printf '%s\n' "$windows" | sed -n '1p')
second_window=$(printf '%s\n' "$windows" | sed -n '2p')
first_sidebar=$(tmux_test list-panes -t "$first_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')
tmux_test set-option -p -t "$first_sidebar" @awesome_sidebar_cursor "$first_window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$first_sidebar" down
[ "$(tmux_test show-option -p -qv -t "$first_sidebar" @awesome_sidebar_cursor)" != "$first_window" ]

tmux_test set-option -p -t "$first_sidebar" @awesome_sidebar_cursor "$second_window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$first_sidebar" enter
active=$(tmux_test list-windows -t "$session_id" -F "#{window_id}${tab}#{window_active}" | awk -F '\t' '$2==1{print $1}')
assert_eq "$second_window" "$active" "Enter selects the highlighted window"
active_sidebar=$(tmux_test list-panes -t "$second_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')
[ -n "$active_sidebar" ]
active_content=$(tmux_test list-panes -t "$second_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}${tab}#{pane_active}" | awk -F '\t' '$2!="sidebar"&&$3==1{print $1;exit}')
[ -n "$active_content" ]
tmux_test set-option -p -t "$active_sidebar" @awesome_sidebar_cursor "$first_window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" sync-active "$second_window"
content_path=$(tmux_test list-panes -t "$second_window" -F '#{@awesome_sidebar_kind}|#{pane_current_path}' | awk -F '|' '$1!="sidebar"{print $2;exit}')
worktree_path=$(git -C "$content_path" rev-parse --show-toplevel 2>/dev/null || :)
if [ -n "$worktree_path" ]; then expected_cursor=worktree:$(CDPATH= cd -- "$worktree_path" && pwd -P); else expected_cursor=$second_window; fi
assert_eq "$expected_cursor" "$(tmux_test show-option -p -qv -t "$active_sidebar" @awesome_sidebar_cursor)" "focused tab row is highlighted"
assert_file_contains "$PROJECT_ROOT/scripts/sidebar-view" '106) move_cursor down'
assert_file_contains "$PROJECT_ROOT/scripts/sidebar-view" '10|13) activate_cursor'
assert_file_contains "$PROJECT_ROOT/scripts/sidebar-view" "trap 'exit 0' HUP INT TERM"

new_window=$(tmux_test new-window -d -t "$session_id" -n later -P -F '#{window_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable-window "$session_id" "$new_window"
assert_eq 0 "$(tmux_test list-panes -t "$new_window" -F '#{pane_left} #{@awesome_sidebar_kind}' | awk '$2=="sidebar"{print $1}')" "new window sidebar is leftmost"
