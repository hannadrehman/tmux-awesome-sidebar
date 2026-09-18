#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"
. "$PROJECT_ROOT/scripts/lib/naming.sh"
assert_eq 'API work' "$(tas_choose_name 'API work' Codex api main /src/api codex 1)"
assert_eq 'Codex · api' "$(tas_choose_name '' '' api main /src/api codex 2)"
assert_eq Shell "$(tas_tool_label zsh)"
assert_eq Tests "$(tas_tool_label 'yarn test')"
