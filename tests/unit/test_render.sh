#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/common.sh"
. "$PROJECT_ROOT/scripts/lib/tree.sh"
rendered=$(printf 'session\t@1\t\tSessions\n' | tas_render 28 ascii '@1')
assert_contains 'Sessions' <<EOF
$rendered
EOF
assert_contains "$(printf '\033[7m')" <<EOF
$rendered
EOF
