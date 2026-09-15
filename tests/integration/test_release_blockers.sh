#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

start_tmux sh
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
tmux_test source-file "$PROJECT_ROOT/tmux-awesome-sidebar.tmux"

session_id=$(tmux_test display-message -p '#{session_id}')
first_window=$(tmux_test display-message -p '#{window_id}')
first_pane=$(tmux_test display-message -p '#{pane_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" enter "$session_id" "$first_window" "$first_pane"
first_group=$(tmux_test show-option -wqv -t "$first_window" @awesome_sidebar_group)

second_window=$(tmux_test new-window -d -t "$session_id" -P -F '#{window_id}')
i=0
while [ "$i" -lt 20 ]; do
  second_sidebar=$(tmux_test list-panes -t "$second_window" -F '#{pane_id} #{@awesome_sidebar_kind}' | awk '$2=="sidebar"{print $1;exit}')
  [ -n "$second_sidebar" ] && break
  i=$((i + 1))
  sleep 0.05
done
second_group=$(tmux_test show-option -wqv -t "$second_window" @awesome_sidebar_group)
[ -n "$second_sidebar" ]
[ "$first_group" != "$second_group" ]

# Each host window must resolve its own storage/session for actions.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" split "$second_group" horizontal 50 "$second_sidebar"
assert_eq 2 "$(tmux_test list-panes -t "$second_window" | wc -l | awk '{print $1}')" "second host split"

# A window linked into both host and storage sessions is one logical row.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" refresh "$second_group" >/dev/null
rows=$(PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET=$TEST_SOCKET sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$second_group")
assert_eq 1 "$(printf '%s\n' "$rows" | awk -F '\t' '$1=="session"{count[$2]++} END{for (id in count) if(count[id]>1) bad=1; print bad+0}')" "deduplicated session rows"

# Search must render through the installed path and Escape must restore state.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" gg
TMUX_SOCKET=$TEST_SOCKET tmux set-option -p -t "$second_sidebar" @awesome_sidebar_collapsed ""
before_cursor=$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_cursor)
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" search-update "$second_group" 'sh' "$second_sidebar"
i=0
rendered=''
while [ "$i" -lt 20 ]; do
  rendered=$(tmux_test capture-pane -p -t "$second_sidebar" 2>/dev/null || :)
  case "$rendered" in *Sessions*) break;; esac
  i=$((i + 1))
  sleep 0.05
done
printf '%s\n' "$rendered" | assert_contains 'Sessions'
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" search-clear "$second_group" "$second_sidebar"
assert_eq '' "$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_query)" "search query cleared"
assert_eq "$before_cursor" "$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_cursor)" "cursor restored"

# h/l implement collapse and expansion, not only parent/child movement.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" gg
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" h
collapsed=$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_collapsed)
printf '%s\n' "$collapsed" | assert_contains "$second_window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" l
assert_eq '' "$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_collapsed)" "l expands session"
