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
assert_eq 3 "$(tmux_test list-panes -t "$second_window" | wc -l | awk '{print $1}')" "second host split"

# A window linked into both host and storage sessions is one logical row.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" refresh "$second_group" >/dev/null
rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$second_group")
assert_eq 0 "$(printf '%s\n' "$rows" | awk -F '\t' '$1=="session"{count[$2]++} END{for (id in count) if(count[id]>1) bad=1; print bad+0}')" "deduplicated session rows"

# Search must render through the installed path and Escape must restore state.
tmux_test set-option -w -t "$second_window" @awesome_sidebar_name feature/sidebar
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" gg
tmux_test set-option -p -t "$second_sidebar" @awesome_sidebar_collapsed ""
before_cursor=$(tmux_test show-option -pqv -t "$second_sidebar" @awesome_sidebar_cursor)
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" search-update "$second_group" 'feature' "$second_sidebar"
i=0
rendered=''
while [ "$i" -lt 20 ]; do
  rendered=$(tmux_test capture-pane -p -t "$second_sidebar" 2>/dev/null || :)
  case "$rendered" in *feature/sidebar*) break;; esac
  i=$((i + 1))
  sleep 0.05
done
printf '%s\n' "$rendered" | assert_contains 'feature/sidebar'
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

# q/r must carry the invoking host-window context, not only the host session.
assert_contains 'refresh' <<EOF
$(tmux_test list-keys -T awesome-sidebar r)
EOF
assert_contains '#{window_id}' <<EOF
$(tmux_test list-keys -T awesome-sidebar r)
EOF
assert_contains '#{pane_id}' <<EOF
$(tmux_test list-keys -T awesome-sidebar r)
EOF
assert_contains 'disable' <<EOF
$(tmux_test list-keys -T awesome-sidebar q)
EOF
assert_contains '#{window_id}' <<EOF
$(tmux_test list-keys -T awesome-sidebar q)
EOF
assert_contains '#{pane_id}' <<EOF
$(tmux_test list-keys -T awesome-sidebar q)
EOF

# Enter on a dormant discovered worktree must activate and select its backing
# full-page window; non-worktree rows remain handled by their existing paths.
gitroot=$TMUX_TMPDIR/repo
mkdir -p "$gitroot"
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" init -q
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" config user.email test@example.invalid
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" config user.name test
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" commit --allow-empty -qm initial
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" branch 'feature/sidebar'
worktree_path=$TMUX_TMPDIR/'repo worktree'
PATH=/opt/homebrew/bin:$PATH git -C "$gitroot" worktree add -q "$worktree_path" 'feature/sidebar'
worktree_path=$(CDPATH= cd -- "$worktree_path" && pwd -P)
tmux_test set-option -g @awesome_sidebar_worktree_roots "$gitroot"
assert_eq "$gitroot" "$(tmux_test show-option -gqv @awesome_sidebar_worktree_roots)" "worktree root configured"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" refresh "$session_id" "$second_window" "$second_sidebar"
worktree_row=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" PATH=/opt/homebrew/bin:$PATH sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$second_group" | awk -F '\t' -v p="$worktree_path" '$1=="worktree" && $7==p{print;exit}')
[ -n "$worktree_row" ]
worktree_id=$(printf '%s\n' "$worktree_row" | awk -F '\t' '{print $2}')
tmux_test set-option -p -t "$second_sidebar" @awesome_sidebar_cursor "$worktree_id"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" navigate "$second_sidebar" enter
second_storage=$(tmux_test show-option -wqv -t "$second_window" @awesome_sidebar_storage)
activated_window=$(tmux_test list-windows -t "$second_storage" -F '#{window_id}	#{window_name}' 2>/dev/null | awk -F '\t' -v n="$(basename "$worktree_path")" '$2==n{print $1;exit}')
[ -n "$activated_window" ]
assert_eq "$activated_window" "$(tmux_test display-message -p -t "$session_id" '#{window_id}')" "dormant worktree selected in invoking host context"

# Disable only the second host-window group; the first group must remain live.
first_storage=$(tmux_test show-option -qv -t "$session_id" @awesome_sidebar_storage)
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" disable "$session_id" "$second_window" "$second_sidebar"
assert_failure tmux_test has-session -t "$second_storage"
assert_success tmux_test has-session -t "$first_storage"
[ "$(tmux_test list-panes -t "$first_window" | wc -l | awk '{print $1}')" -gt 1 ]
