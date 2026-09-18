#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/common.sh"
. "$PROJECT_ROOT/scripts/lib/tree.sh"
rows=$(printf '%s' 'session	@2		Claude UI	ui		/src/ui	claude	idle	
pane	%4	@2	Tests	ui		/src/ui	yarn	active	
')
visible=$(printf '%s' "$rows" | tas_tree_visible '')
assert_contains 'Claude UI' <<EOF
$visible
EOF
assert_not_contains 'Sidebar' <<EOF
$visible
EOF
assert_eq '%4' "$(printf '%s' "$rows" | tas_cursor_move '@2' end)"

page_rows=$(printf 'session\t@%s\t\tWindow %s\n' 1 1 2 2 3 3 4 4 5 5 6 6)
assert_eq '@5' "$(printf '%s' "$page_rows" | tas_cursor_move '@2' page-down 3)" "page down"
assert_eq '@1' "$(printf '%s' "$page_rows" | tas_cursor_move '@4' page-up 3)" "page up"
