#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
gitroot=$TMUX_TMPDIR/repo
mkdir -p "$gitroot"
git -C "$gitroot" init -q
git -C "$gitroot" config user.email test@example.invalid
git -C "$gitroot" config user.name test
git -C "$gitroot" commit --allow-empty -qm initial
git -C "$gitroot" branch 'feature/sidebar'
spaced=$TMUX_TMPDIR/'repo worktree'
git -C "$gitroot" worktree add -q "$spaced" 'feature/sidebar'
rows=$(git -C "$gitroot" worktree list --porcelain | "$PROJECT_ROOT/scripts/discover-worktrees")
assert_contains 'repo worktree' <<EOF
$rows
EOF
assert_contains 'feature/sidebar' <<EOF
$rows
EOF
assert_not_contains 'refs/heads/' <<EOF
$rows
EOF

start_tmux -c "$gitroot" sh
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable
session_id=$(tmux_test display-message -p -t test '#{session_id}')
window_id=$(tmux_test display-message -p -t test '#{window_id}')
assert_eq 'repo--master' "$(tmux_test display-message -p -t "$window_id" '#{window_name}')" "root worktree window name"
tab=$(printf '\t')
sidebar=$(tmux_test list-panes -t "$window_id" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')
[ -n "$sidebar" ]

# Reuse an existing window when its content pane already belongs to the
# selected worktree.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" activate-row "$sidebar" worktree existing "$gitroot"
assert_eq 1 "$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | wc -l | awk '{print $1}')" "existing worktree window is reused"

# A closed worktree gets one new window, and selecting it again reuses that
# same window instead of creating duplicates.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" activate-row "$sidebar" worktree new "$spaced"
assert_eq 2 "$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | wc -l | awk '{print $1}')" "closed worktree opens once"
opened_window=$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | awk -v root="$window_id" '$0!=root{print;exit}')
assert_eq 'repo--feature-sidebar' "$(tmux_test display-message -p -t "$opened_window" '#{window_name}')" "linked worktree window name"
opened_sidebar=$(tmux_test list-panes -t "$opened_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')
canonical_spaced=$(CDPATH= cd -- "$spaced" && pwd -P)
assert_eq "worktree:$canonical_spaced" "$(tmux_test show-option -p -qv -t "$opened_sidebar" @awesome_sidebar_cursor)" "opened worktree stays selected in place"

# The real tmux window is folded into the existing worktree child instead of
# appearing as a second top-level sidebar row.
tree_rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$session_id")
assert_eq 1 "$(printf '%s\n' "$tree_rows" | awk -F '\t' '$1=="session"{n++}END{print n+0}')" "opened worktree is not duplicated at the top level"
assert_eq "$opened_window" "$(printf '%s\n' "$tree_rows" | awk -F '\t' -v p="$canonical_spaced" '$1=="worktree"&&$7==p{print $11;exit}')" "worktree child targets its open window"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" activate-row "$sidebar" worktree existing "$spaced"
assert_eq 2 "$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | wc -l | awk '{print $1}')" "open worktree is reused"
