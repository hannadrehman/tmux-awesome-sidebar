#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
result=$(printf '%s\n' 'pane	%4	@2	feature/sidebar › Tests	repo	feature/sidebar	/src	yarn test	active	test' | awk -v query='side test' -f "$PROJECT_ROOT/scripts/search.awk")
assert_contains '%4' <<EOF
$result
EOF
