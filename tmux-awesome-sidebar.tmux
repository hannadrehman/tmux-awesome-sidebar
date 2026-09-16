# The sidebar is a persistent pane. It reads navigation keys directly whenever
# it is focused, so the plugin does not install a prefix binding or key table.
run-shell -b 'plugin_dir="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar"; [ -x "$plugin_dir/scripts/action" ] || plugin_dir="${TMUX_PLUGIN_MANAGER_PATH%/}"; "$plugin_dir/scripts/action" auto-enable'

set-hook -g 'after-split-window[99]' 'run-shell -b "plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar\"; [ -x \"\$plugin_dir/scripts/action\" ] || plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}\"; \"\$plugin_dir/scripts/action\" refresh-from-hook"'
set-hook -g 'after-new-window[99]' 'run-shell -b "plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar\"; [ -x \"\$plugin_dir/scripts/action\" ] || plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}\"; \"\$plugin_dir/scripts/action\" auto-enable-window \"#{session_id}\" \"#{window_id}\""'
set-hook -g 'after-kill-pane[99]' 'run-shell -b "plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar\"; [ -x \"\$plugin_dir/scripts/action\" ] || plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}\"; \"\$plugin_dir/scripts/action\" refresh-from-hook"'
set-hook -g 'pane-exited[99]' 'run-shell -b "plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar\"; [ -x \"\$plugin_dir/scripts/action\" ] || plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}\"; \"\$plugin_dir/scripts/action\" refresh-from-hook"'
set-hook -g 'window-renamed[99]' 'run-shell -b "plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-awesome-sidebar\"; [ -x \"\$plugin_dir/scripts/action\" ] || plugin_dir=\"\${TMUX_PLUGIN_MANAGER_PATH%/}\"; \"\$plugin_dir/scripts/action\" refresh-from-hook"'
