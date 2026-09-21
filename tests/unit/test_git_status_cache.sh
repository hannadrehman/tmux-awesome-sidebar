#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/common.sh"
. "$PROJECT_ROOT/scripts/lib/state.sh"

repo=$TMUX_TMPDIR/status-repo
cache=$TMUX_TMPDIR/cache
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name test
git -C "$repo" commit --allow-empty -qm initial

XDG_CACHE_HOME=$cache "$PROJECT_ROOT/scripts/git-status-cache" refresh "$repo" ''
assert_eq '' "$(XDG_CACHE_HOME=$cache tas_status_cache_read "$repo")" "clean repository badge"
printf dirty > "$repo/untracked"
rm -rf "$cache/tmux-awesome-sidebar/status"
XDG_CACHE_HOME=$cache "$PROJECT_ROOT/scripts/git-status-cache" refresh "$repo" ''
assert_contains '●' <<EOF
$(XDG_CACHE_HOME=$cache tas_status_cache_read "$repo")
EOF
