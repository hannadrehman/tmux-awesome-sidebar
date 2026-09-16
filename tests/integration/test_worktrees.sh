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
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" activate-row "$sidebar" worktree existing "$spaced"
assert_eq 2 "$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | wc -l | awk '{print $1}')" "open worktree is reused"
