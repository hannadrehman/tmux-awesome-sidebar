# tmux-awesome-sidebar

A persistent, interactive project and worktree navigator for tmux.

`tmux-awesome-sidebar` puts a narrow tree on the left of every tmux window. It
shows the session's native windows, discovers Git worktrees underneath their
project, and lets you navigate the whole workspace without opening a popup.
The sidebar is a real tmux pane: it is always visible, survives normal window
switching, and works with existing pane-navigation bindings.

The plugin is written in portable shell and awk. It does not install a binary,
replace the tmux prefix, or define colors, fonts, borders, status-line styles,
or a theme. Your terminal and tmux configuration remain the source of truth.

## Highlights

- Persistent absolute-left sidebar in every native tmux window
- Project tree built from the session's windows and `git worktree list`
- Existing worktree windows are reused instead of duplicated
- Inline fuzzy filtering across all row data
- Vim-style movement, paging, folds, and tree actions
- Viewport scrolling that keeps the selected row visible
- Two-row cursor repainting for fast, flicker-free navigation
- Asynchronously cached Git dirty, conflict, ahead, and behind indicators
- Worktree creation from an existing branch or a new branch and base ref
- Safe worktree removal using Git's normal dirty-worktree protection
- Sidebar-only aliases that do not rename unrelated tmux state
- Shell, editor, lazygit, clipboard, Finder/file-manager, and prune actions
- Optional recently-used project and worktree ordering
- Mouse selection and scrolling when tmux mouse mode is enabled
- ASCII and Nerd Font tree markers, with no bundled font dependency

## Requirements

- tmux 3.3 or newer
- Git
- A POSIX-compatible `/bin/sh`
- POSIX `awk`, `sed`, `cksum`, and standard Unix utilities
- [TPM](https://github.com/tmux-plugins/tpm) for the recommended installation

`lazygit`, an editor, and a desktop file opener are optional and are only used
by their corresponding actions.

## Installation

Add the plugin to `~/.tmux.conf` before the TPM initialization line:

```tmux
set -g @plugin 'hannadrehman/tmux-awesome-sidebar'

# Optional. These are the defaults.
set -g @awesome_sidebar_width 17
set -g @awesome_sidebar_icons ascii
```

Reload tmux, then install TPM plugins with `prefix + I`.

For a local checkout:

```sh
git clone https://github.com/hannadrehman/tmux-awesome-sidebar.git
ln -s "$PWD/tmux-awesome-sidebar" ~/.tmux/plugins/tmux-awesome-sidebar
```

Then source `tmux-awesome-sidebar.tmux` from your tmux configuration or keep
the normal TPM plugin declaration.

## What the tree represents

Every top-level row represents a real window in the current tmux session.
When a window is inside a Git repository, the repository's worktrees appear as
children of its first project row. Other windows from the same worktree are
folded into that child instead of being repeated at the top level.

Git-backed windows use the tmux name `folder--worktree-name`. Non-Git windows
use `folder-index`. Project labels show the active branch, for example
`tmux-awesome-sidebar(main)`. Long labels are shortened after 24 characters;
sidebar-only aliases can provide a more useful name.

The active window or worktree is selected in the tree. Pressing Enter on an
already-open item switches to it. Pressing Enter on a dormant worktree creates
one tmux window rooted in that worktree and selects it.

## Key bindings

Focus the sidebar with your normal tmux pane-navigation binding or by clicking
it. Keys are read directly by the sidebar; no prefix binding is installed.

| Key | Action |
| --- | --- |
| `j`, `k`, arrows | Move down or up |
| `gg`, `G` | Jump to first or last item |
| `Ctrl-u`, `Ctrl-d` | Move half a page |
| `Ctrl-b`, `Ctrl-f` | Move a full page |
| `h`, `l` | Collapse, move to parent, expand, or move to first child |
| `za` | Toggle the selected project fold |
| `zM`, `zR` | Collapse or expand every project |
| `Enter` | Open or focus the selected window/worktree |
| `/` | Edit the fuzzy-search input |
| `a` | Add a worktree beneath the selected project |
| `r` | Remove a worktree or close a project's windows |
| `R` | Rename or reset the selected sidebar label |
| `n` | Open/focus the selected item's shell window |
| `e` | Open the configured editor at the selected path |
| `g` | Open the configured Git UI; a second `g` jumps to the top |
| `y` | Copy the selected path into the tmux paste buffer |
| `o` | Reveal the selected path with `open` or `xdg-open` |
| `p` | Prune stale worktree metadata for the selected repository |
| `Ctrl-l` | Refresh the tree and Git-status cache |
| `?` | Show the in-sidebar key reference |
| `q`, `Escape` | Return to the first content pane |

During search, printable characters update results immediately. Backspace
edits the query, `Ctrl-u` clears it, Enter keeps the current filter, and Escape
clears the filter and restores the previous selection.

### Mouse

With `set -g mouse on` in your tmux configuration, clicking a tree row selects
and opens it. The wheel moves the selection. The plugin enables mouse reporting
only inside its own sidebar process and does not change the global tmux mouse
setting.

## Worktree workflow

Press `a` on a project row. The sidebar asks for:

1. A branch name. Existing branches are checked out directly; blank creates a
   stable `worktree-N` branch.
2. A base ref for a new branch. Blank uses the repository's current `HEAD`.

Worktrees are created alongside the repository under
`.worktrees/<repository>/<branch>`. The new row is selected without opening a
window. Press Enter when you want to open it.

Press `r` on a worktree to remove it and close associated tmux windows. Git
refuses the operation when the worktree has changes that require force, so the
plugin does not silently discard work. Pressing `r` on a project row closes
that project's tmux windows but never deletes the repository.

## Git indicators

Worktree labels can include:

| Marker | Meaning |
| --- | --- |
| `●` | Modified, staged, or untracked files |
| `!` | Unmerged/conflicting files |
| `↑N` | Commits ahead of the upstream branch |
| `↓N` | Commits behind the upstream branch |

Git status is calculated outside the navigation loop and stored in
`${XDG_CACHE_HOME:-~/.cache}/tmux-awesome-sidebar/status`. Cache entries are
refreshed when the tree refreshes, with a five-second minimum cache lifetime.
This keeps `j/k` navigation independent of Git performance. Use `Ctrl-l` to
request a fresh tree after repository changes.

## Configuration

```tmux
# Sidebar width as a percentage of the tmux window (10-80).
set -g @awesome_sidebar_width 17

# `ascii` works everywhere; `nerd` uses tree glyphs.
set -g @awesome_sidebar_icons nerd

# Native window order is the default. Use recently activated items instead.
set -g @awesome_sidebar_sort recent

# Commands launched by `e` and `g`.
set -g @awesome_sidebar_editor nvim
set -g @awesome_sidebar_git_ui lazygit
```

The plugin deliberately has no options for colors, status style, pane border
style, font, terminal features, or prefix. Configure those globally in tmux and
your terminal as usual.

## Architecture

Each tmux window owns one tagged sidebar pane at `pane_left=0`. Hooks keep new
windows covered and synchronize the selected tree row when tmux focus changes.
The sidebar process reads raw key bytes and renders ANSI attributes already
supported by the terminal; it does not scrape pane contents.

Navigation updates only the old and new rows. Structural operations—search,
folding, adding/removing worktrees, resizing, or refreshing—rebuild the visible
viewport. Git status work runs through a small lock-protected cache so multiple
window sidebars do not execute the same expensive query concurrently.

## Troubleshooting

Run the bundled doctor:

```sh
~/.tmux/plugins/tmux-awesome-sidebar/scripts/doctor
```

If no sidebar appears, confirm that TPM resolves the plugin directory and then
reload the plugin:

```sh
~/.tmux/plugins/tmux-awesome-sidebar/scripts/action auto-enable
```

Useful checks:

```sh
tmux list-panes -a -F '#{pane_id} #{@awesome_sidebar_kind} #{pane_dead}'
tmux show-hooks -g | grep awesome-sidebar
```

If mouse clicks only focus the pane, enable tmux mouse support with
`set -g mouse on`. If an editor or Git UI action exits immediately, verify that
the configured command is installed and available in tmux's server `PATH`.

## Development

```sh
make lint
make test
make security
```

Or run the portable test entrypoint directly:

```sh
tests/run unit
tests/run integration
```

The test suite creates isolated tmux servers and temporary Git repositories.
It covers lifecycle hooks, window/worktree reuse, navigation, rendering,
search, creation/removal safety, startup recovery, and input sanitization.

## License

[MIT](LICENSE)
