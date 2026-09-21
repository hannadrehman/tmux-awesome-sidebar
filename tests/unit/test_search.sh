#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
result=$(printf '%s\n' 'pane	%4	@2	feature/sidebar › Tests	repo	feature/sidebar	/src	yarn test	active	test' | awk -v query='side test' -f "$PROJECT_ROOT/scripts/search.awk")
assert_contains '%4' <<EOF
$result
EOF
assert_not_contains 'secret-id' <<EOF
$(printf '%s\n' 'pane\tsecret-id\t@2\tPlain Name\trepo\tbranch\t/path\tcommand\tstatus\ttags' | awk -v query='secret' -f "$PROJECT_ROOT/scripts/search.awk")
EOF
assert_not_contains 'other' <<EOF
$(printf '%s\n' 'pane\t%1\t@1\tName\trepo\tbranch\t/path\tcommand\tstatus\ttags\npane\t%2\t@1\tOther\trepo\tbranch\t/path\tcommand\tstatus\ttags' | awk -v query='@1' -f "$PROJECT_ROOT/scripts/search.awk")
EOF
assert_eq '' "$(printf '%s\n' 'pane\t%1\t@1\tName\trepo\tbranch\t/path\tcommand\tstatus\ttags' | awk -v query='absent' -f "$PROJECT_ROOT/scripts/search.awk")"
