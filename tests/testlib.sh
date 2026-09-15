#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
TEST_SOCKET="tas-$$"
TMUX_TMPDIR=${TMPDIR:-/tmp}/tas-$$-$(date +%s)
TMUX_SOCKET=$TEST_SOCKET
export PROJECT_ROOT TEST_SOCKET TMUX_SOCKET TMUX_TMPDIR
mkdir -p "$TMUX_TMPDIR"
TMUX_BIN=${TMUX_BIN:-tmux}; export TMUX_BIN
tmux_test() { TMUX_TMPDIR=$TMUX_TMPDIR "$TMUX_BIN" -L "$TEST_SOCKET" -f /dev/null "$@"; }
cleanup() { "$TMUX_BIN" -L "$TEST_SOCKET" kill-server >/dev/null 2>&1 || :; rm -rf "$TMUX_TMPDIR"; }
trap cleanup EXIT HUP INT TERM
assert_eq() { [ "$1" = "$2" ] || { echo "assert_eq: ${3:-values}: '$1' != '$2'" >&2; return 1; }; }
assert_success() { "$@" || return 1; }
assert_failure() { if "$@"; then return 1; fi; }
assert_contains() { needle=$1; haystack=$(cat); case $haystack in *"$needle"*) ;; *) return 1;; esac; }
assert_not_contains() { needle=$1; haystack=$(cat); case $haystack in *"$needle"*) return 1;; esac; }
start_tmux() { tmux_test new-session -d -s test "$@"; }
assert_file_contains() { file=$1; needle=$2; rg -F "$needle" "$file" >/dev/null; }
assert_file_not_contains() { file=$1; needle=$2; ! rg -F "$needle" "$file" >/dev/null; }
assert_max_display_width() { max=$1; awk -v m="$max" 'length($0)>m{exit 1}'; }
assert_snapshot() { name=$1; actual=$2; expected=$PROJECT_ROOT/tests/snapshots/$name.txt; assert_eq "$(cat "$expected")" "$actual" "snapshot $name"; }
