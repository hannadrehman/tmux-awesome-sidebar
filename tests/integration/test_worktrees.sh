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
