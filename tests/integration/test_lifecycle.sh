#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
start_tmux sh
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"
session_id=$(tmux_test display-message -p '#{session_id}')
window_id=$(tmux_test display-message -p '#{window_id}')
pane_id=$(tmux_test display-message -p '#{pane_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$pane_id"
assert_eq 2 "$(tmux_test list-panes -t "$window_id" | wc -l | awk '{print $1}')"
sidebar=''
for candidate in $(tmux_test list-panes -t "$window_id" -F '#{pane_id}'); do
  [ "$(tmux_test display-message -p -t "$candidate" '#{@awesome_sidebar_kind}')" = sidebar ] && { sidebar=$candidate; break; }
done
[ -n "$sidebar" ]
assert_eq 0 "$(tmux_test display-message -p -t "$sidebar" '#{pane_left}')" "sidebar is on the left"
assert_eq 1 "$(tmux_test display-message -p -t "$sidebar" '#{pane_active}')" "enter focuses the sidebar"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$window_id" "$sidebar"
assert_eq 2 "$(tmux_test list-panes -t "$window_id" | wc -l | awk '{print $1}')"
new_host_window=$(tmux_test new-window -d -t "$session_id" -P -F '#{window_id}')
new_window_ready=0
i=0
while [ "$i" -lt 20 ]; do
  if [ "$(tmux_test list-panes -t "$new_host_window" 2>/dev/null | wc -l | awk '{print $1}')" -eq 2 ]; then
    new_window_ready=1
    break
  fi
  i=$((i + 1))
  sleep 0.05
done
assert_eq 1 "$new_window_ready" "new windows are auto-enabled"
first_group=$(tmux_test show-option -qv -t "$window_id" @awesome_sidebar_group)
second_group=$(tmux_test show-option -qv -t "$new_host_window" @awesome_sidebar_group)
[ "$first_group" != "$second_group" ]
assert_eq 0 "$(tmux_test show-option -wqv -t "$window_id" @awesome_sidebar_host_index)"
assert_eq 1 "$(tmux_test show-option -wqv -t "$new_host_window" @awesome_sidebar_host_index)"
group=$(tmux_test show-option -qv -t "$session_id" @awesome_sidebar_group)
mkdir -p "$TMUX_TMPDIR/project"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" session-new "$group" "$TMUX_TMPDIR/project" 'Project One'
storage=$(tmux_test show-option -qv -t "$session_id" @awesome_sidebar_storage)
new_window=$(tmux_test list-windows -t "$storage" -F '#{window_id}	#{window_name}' | awk -F '\t' '$2=="Project One"{print $1;exit}')
[ -n "$new_window" ]
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" session-select "$group" "$new_window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" split "$group" horizontal 50
[ "$(tmux_test list-panes -t "$new_window" | wc -l | awk '{print $1}')" -ge 2 ]
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" disable "$session_id"
assert_eq 1 "$(tmux_test list-panes -t "$window_id" | wc -l | awk '{print $1}')"
