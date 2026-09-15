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
