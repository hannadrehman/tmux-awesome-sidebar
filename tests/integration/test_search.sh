#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
result=$(printf '%s\n' 'pane	%4	@2	feature/sidebar › Tests	repo	feature/sidebar	/src	yarn test	active	test' | awk -v query='side test' -f "$PROJECT_ROOT/scripts/search.awk")
assert_contains '%4' <<EOF
$result
EOF

alpha=$TMUX_TMPDIR/alpha
beta=$TMUX_TMPDIR/beta
mkdir -p "$alpha" "$beta"
start_tmux -c "$alpha" sh
beta_window=$(tmux_test new-window -d -t test -c "$beta" -P -F '#{window_id}')
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable
first_window=$(tmux_test list-windows -t test -F '#{window_id}' | sed -n '1p')
tab=$(printf '\t')
sidebar=$(tmux_test list-panes -t "$first_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')
sleep 0.5
tmux_test send-keys -t "$sidebar" '/'
tmux_test send-keys -t "$sidebar" -l beta
sleep 0.2
tmux_test send-keys -t "$sidebar" Enter
sleep 0.2
assert_eq beta "$(tmux_test show-option -p -qv -t "$sidebar" @awesome_sidebar_query)" "search query is retained"
assert_eq "$beta_window" "$(tmux_test show-option -p -qv -t "$sidebar" @awesome_sidebar_cursor)" "search selects the first visible match"
tmux_test capture-pane -p -t "$sidebar" | assert_contains 'Search: beta'
