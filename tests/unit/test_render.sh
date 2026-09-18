#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/common.sh"
. "$PROJECT_ROOT/scripts/lib/tree.sh"
rendered=$(printf 'session\t@1\t\tSessions\n' | tas_render 28 ascii '@1')
assert_contains 'Sessions' <<EOF
$rendered
EOF
filtered=$(printf '%s\n' 'pane	%1	@1	Alpha	repo	main	/path	secret-cmd	active	private' 'pane	%2	@1	Beta	repo	main	/path	other	active	public' | TAS_SEARCH_AWK="$PROJECT_ROOT/scripts/search.awk" tas_filter_rows secret | tas_render 28 ascii '' secret 1)
assert_contains 'Alpha' <<EOF
$filtered
EOF
assert_not_contains 'Beta' <<EOF
$filtered
EOF
assert_contains 'Search: secret_' <<EOF
$filtered
EOF
assert_contains "$(printf '\033[7m')" <<EOF
$rendered
EOF
assert_contains "$(printf '\033[H')" <<EOF
$rendered
EOF
assert_not_contains "$(printf '\033[2J')" <<EOF
$rendered
EOF
delta=$(printf '%s\n' \
  'session	@1		Alpha' \
  'worktree	worktree:/beta	@1	Beta' |
  tas_render 28 ascii 'worktree:/beta' '' 0 '@1')
assert_contains "$(printf '\033[2;1H')" <<EOF
$delta
EOF
assert_contains "$(printf '\033[3;1H')" <<EOF
$delta
EOF
assert_not_contains "$(printf '\033[H')" <<EOF
$delta
EOF
assert_not_contains "$(printf '\033[J')" <<EOF
$delta
EOF
long_name='hr-coding-agents(feature/a-very-long-worktree-name)'
truncated=$(printf 'session\t@1\t\t%s\n' "$long_name" | tas_render 17 ascii '@1')
assert_contains 'hr-coding-agents(feature...' <<EOF
$truncated
EOF
assert_not_contains "$long_name" <<EOF
$truncated
EOF
badged=$(printf 'worktree\tworktree:/repo\t@1\tmain\t\t\t/repo\t\tdormant\tworktree\t\t●↑2\n' | tas_render 28 ascii 'worktree:/repo')
assert_contains 'main ●↑2' <<EOF
$badged
EOF
folded=$(printf 'session\t@1\t\tProject\n' | tas_render 28 ascii '@1' '' 0 '' '@1')
assert_contains '+ Project' <<EOF
$folded
EOF
sliced=$(printf 'one\ntwo\nthree\nfour\n' | tas_slice_rows 1 2)
assert_eq "$(printf 'two\nthree')" "$sliced" "viewport slice"
