#!/bin/sh
set -eu
. "$(dirname -- "$0")/../testlib.sh"

gitroot=$TMUX_TMPDIR/repo
mkdir -p "$gitroot"
git -C "$gitroot" init -q
git -C "$gitroot" config user.email test@example.invalid
git -C "$gitroot" config user.name test
git -C "$gitroot" commit --allow-empty -qm initial

start_tmux -c "$gitroot" sh
tmux_test set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PROJECT_ROOT"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" auto-enable
session_id=$(tmux_test display-message -p -t test '#{session_id}')
root_window=$(tmux_test display-message -p -t test '#{window_id}')
tab=$(printf '\t')
sidebar=$(tmux_test list-panes -t "$root_window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2=="sidebar"{print $1;exit}')

# Sidebar-only aliases do not change the actual tmux window name.
original_window_name=$(tmux_test display-message -p -t "$root_window" '#{window_name}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" rename-row "$sidebar" session "$root_window" "$gitroot" 'My project'
rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$session_id")
assert_eq 'My project' "$(printf '%s\n' "$rows" | awk -F '\t' '$1=="session"{print $4;exit}')" "custom tree label"
assert_eq "$original_window_name" "$(tmux_test display-message -p -t "$root_window" '#{window_name}')" "alias leaves tmux window name alone"

# Blank input receives a stable generated name and appears in git's worktree
# list without opening another tmux window.
created_output=$(TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" worktree-add "$sidebar" "$gitroot" '')
created=$(git -C "$gitroot" worktree list --porcelain | awk '/^worktree /{path=substr($0,10)}/^branch refs\/heads\/worktree-1$/{print path;exit}')
[ -n "$created" ]
[ -d "$created" ]
assert_eq "$created" "$created_output" "creation returns the new worktree row path"
assert_eq 1 "$(tmux_test list-windows -t "$session_id" -F '#{window_id}' | wc -l | awk '{print $1}')" "adding an entry does not open a tab"

# A new branch can be based on an explicit ref.
git -C "$gitroot" branch base-for-sidebar
based_output=$(TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" worktree-add "$sidebar" "$gitroot" based-worktree base-for-sidebar)
assert_eq "$(git -C "$gitroot" rev-parse base-for-sidebar)" "$(git -C "$based_output" rev-parse HEAD)" "new worktree uses requested base"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" rename-row "$sidebar" worktree "worktree:$based_output" "$based_output" 'Review branch'
rows=$(env PROJECT_ROOT="$PROJECT_ROOT" TMUX_SOCKET="$TEST_SOCKET" sh -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/tree.sh"; tas_build_rows "$2"' sh "$PROJECT_ROOT" "$session_id")
assert_eq 'Review branch' "$(printf '%s\n' "$rows" | awk -F '\t' -v p="$based_output" '$1=="worktree"&&$7==p{print $4;exit}')" "worktree alias"
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" remove-row "$sidebar" worktree "$based_output"

# Removing a clean linked worktree removes its entry and closes any associated
# tabs. Git's normal safety checks remain in force.
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" remove-row "$sidebar" worktree "$created"
[ ! -e "$created" ]
git -C "$gitroot" worktree list --porcelain | assert_not_contains 'refs/heads/worktree-1'

# Removing a project row closes all of that project's windows without deleting
# the repository itself or unrelated windows.
other=$TMUX_TMPDIR/other
mkdir -p "$other"
other_window=$(tmux_test new-window -d -t "$session_id" -n other -c "$other" -P -F '#{window_id}')
TMUX_SOCKET=$TEST_SOCKET "$PROJECT_ROOT/scripts/action" remove-row "$sidebar" session "$gitroot" || :
assert_eq "$other_window" "$(tmux_test list-windows -t "$session_id" -F '#{window_id}')" "project tabs are closed"
[ -d "$gitroot/.git" ]
