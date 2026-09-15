#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/common.sh"
assert_success tas_validate_id '%42' pane
assert_success tas_validate_id '@7' window
assert_success tas_validate_id '$3' session
assert_failure tas_validate_id '%7;kill-server' pane
assert_failure tas_validate_text "$(printf 'bad\033name')"
assert_eq '16' "$(tas_clamp_width 4)"
assert_eq '80' "$(tas_clamp_width 120)"
