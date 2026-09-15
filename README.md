# tmux-awesome-sidebar

`tmux-awesome-sidebar` adds a persistent, native tmux sidebar for logical
sessions, their content panes, and configured Git worktrees. It requires tmux
3.3 or newer, POSIX `/bin/sh`, POSIX `awk`, Git, and TPM.

## Installation

Add this to `.tmux.conf` and reload tmux:

```tmux
set -g @plugin 'hannadrehman/tmux-awesome-sidebar'
set -g @awesome_sidebar_worktree_roots "$HOME/src"
set -g @awesome_sidebar_width 28
set -g @awesome_sidebar_icons ascii
set -g @awesome_sidebar_key S
```

The plugin inherits the existing prefix table and never changes prefix,
status, border, terminal, font, color, or theme settings.

## How it works

Logical backing windows remain native tmux windows in a detached storage
session. A link is exposed in the host session while the sidebar pane renders
metadata from tmux user options. This preserves running processes while
switching, splitting, disabling, or recovering. Worktrees are discovered from
`git worktree list --porcelain`; dormant entries do not create a process and
are activated only when selected.

Search (`/`) uses only display names, repositories, branches, paths, commands,
statuses, and tags. It does not capture scrollback, inspect environments, or
read shell history. `Escape` clears the active query and restores navigation.

Use `S` after the prefix to focus the left sidebar. Inside it, `j/k` or the
arrow keys move through the list, and `Enter` switches to the selected window
or pane. `h/l`, `g/G`, `r`, `/`, and `q` provide the remaining navigation and actions. The `ascii` icon
mode is portable; `nerd` is an opt-in display choice. Run `scripts/doctor` to
check dependencies, hooks, links, tags, bindings, prefix inheritance, and
style interference. Disable leaves backing windows and their processes
available in the host session.
