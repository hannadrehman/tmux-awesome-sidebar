# tmux-awesome-sidebar

`tmux-awesome-sidebar` adds a persistent, native tmux sidebar containing the
windows in the current tmux session. It requires tmux
3.3 or newer, POSIX `/bin/sh`, POSIX `awk`, Git, and TPM.

## Installation

Add this to `.tmux.conf` and reload tmux:

```tmux
set -g @plugin 'hannadrehman/tmux-awesome-sidebar'
set -g @awesome_sidebar_width 28
set -g @awesome_sidebar_icons ascii
```

The plugin inherits the existing prefix table and never changes prefix,
status, border, terminal, font, color, or theme settings.

## How it works

The sidebar lists only the real native windows in the current tmux session. Every
window receives its own absolute-left sidebar pane, so switching windows keeps
the navigation visible without detached storage sessions or linked-window
layouts. Pane children, worktrees, and search results are not included.

Focus the sidebar with your normal tmux pane-navigation binding or the mouse.
It reads keys directly: `j/k` or the arrow keys move through the list, Enter
switches to the selected window, `g/G` jump to the ends, and `q` or Escape
returns to the content area. The `ascii` icon
mode is portable; `nerd` is an opt-in display choice. Run `scripts/doctor` to
check dependencies, hooks, links, tags, bindings, prefix inheritance, and
style interference.
