#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
gitroot=$TMUX_TMPDIR/repo
mkdir -p "$gitroot"
git -C "$gitroot" init -q
git -C "$gitroot" config user.email test@example.invalid
git -C "$gitroot" config user.name test
git -C "$gitroot" commit --allow-empty -qm initial
git -C "$gitroot" worktree list --porcelain | "$PROJECT_ROOT/scripts/discover-worktrees" >/dev/null
