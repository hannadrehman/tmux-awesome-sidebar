# The shell command runs from the plugin directory under TPM. It only installs
# user-table bindings and hooks; it does not alter any built-in style option.
run-shell 'key=$(tmux show-option -gqv @awesome_sidebar_key); [ -n "$key" ] || key=S; tmux bind-key -T prefix "$key" run-shell "scripts/action enter '\''#{session_id}'\'' '\''#{window_id}'\'' '\''#{pane_id}'\''"'
run-shell -b 'action="${TMUX_PLUGIN_MANAGER_PATH:-}/tmux-awesome-sidebar/scripts/action"; [ -x "$action" ] || action="${TMUX_PLUGIN_MANAGER_PATH:-}/scripts/action"; [ -x "$action" ] || action=scripts/action; "$action" auto-enable'
bind-key -T awesome-sidebar j run-shell "scripts/action navigate '#{pane_id}' down" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar k run-shell "scripts/action navigate '#{pane_id}' up" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar h run-shell "scripts/action navigate '#{pane_id}' parent" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar l run-shell "scripts/action navigate '#{pane_id}' child" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar g run-shell "scripts/action navigate '#{pane_id}' gg" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar G run-shell "scripts/action navigate '#{pane_id}' G" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar Enter run-shell "scripts/action navigate '#{pane_id}' enter" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar r run-shell "scripts/action refresh '#{session_id}'" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar a run-shell "scripts/action session-new '#{@awesome_sidebar_group}' '#{pane_current_path}' 'New session'" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar s run-shell "scripts/action session-select '#{session_id}' '#{window_id}'" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar J run-shell "scripts/action navigate '#{pane_id}' down" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar K run-shell "scripts/action navigate '#{pane_id}' up" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar / command-prompt -i -T search
bind-key -T awesome-sidebar q run-shell "scripts/action disable '#{session_id}'"
bind-key -T awesome-sidebar Escape switch-client -T prefix
bind-key -T awesome-sidebar ? display-message 'j/k move, h/l collapse, Enter select, / search, q close'
set-hook -g 'after-split-window[99]' 'run-shell -b "scripts/action refresh-from-hook"'
set-hook -g 'after-new-window[99]' 'run-shell -b "action=\"\${TMUX_PLUGIN_MANAGER_PATH:-}/tmux-awesome-sidebar/scripts/action\"; [ -x \"\$action\" ] || action=\"\${TMUX_PLUGIN_MANAGER_PATH:-}/scripts/action\"; [ -x \"\$action\" ] || action=scripts/action; \"\$action\" auto-enable"'
set-hook -g 'after-kill-pane[99]' 'run-shell -b "scripts/action refresh-from-hook"'
set-hook -g 'pane-exited[99]' 'run-shell -b "scripts/action refresh-from-hook"'
set-hook -g 'window-linked[99]' 'run-shell -b "scripts/action refresh-from-hook"'
set-hook -g 'window-renamed[99]' 'run-shell -b "scripts/action refresh-from-hook"'
set-hook -g 'session-closed[99]' 'run-shell -b "scripts/action refresh-from-hook"'
