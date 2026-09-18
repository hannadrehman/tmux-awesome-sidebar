#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
output=$(TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/doctor")
assert_contains 'tmux: ok' <<EOF
$output
EOF
assert_contains 'style interference: none' <<EOF
$output
EOF
