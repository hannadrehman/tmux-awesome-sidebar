#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/discover-worktrees"
rows=$(printf 'worktree /src/repo\nHEAD abc\nbranch refs/heads/main\n\nworktree /src/repo-sidebar\nHEAD def\nbranch refs/heads/feature/sidebar\n' | tas_parse_worktrees repo)
assert_contains '/src/repo-sidebar' <<EOF
$rows
EOF
assert_contains 'feature/sidebar' <<EOF
$rows
EOF
detached=$(printf 'worktree /src/detached\nHEAD abc\n\n' | tas_parse_worktrees repo)
assert_contains '(detached)' <<EOF
$detached
EOF
