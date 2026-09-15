# Native tmux configuration. TPM changes directory to this plugin before sourcing it.
bind-key -T prefix S run-shell "scripts/action enter '#{session_id}' '#{window_id}' '#{pane_id}'"
bind-key -T awesome-sidebar j run-shell "scripts/action navigate '#{pane_id}' down" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar k run-shell "scripts/action navigate '#{pane_id}' up" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar h run-shell "scripts/action navigate '#{pane_id}' parent" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar l run-shell "scripts/action navigate '#{pane_id}' child" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar g run-shell "scripts/action navigate '#{pane_id}' home" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar G run-shell "scripts/action navigate '#{pane_id}' end" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar Enter run-shell "scripts/action navigate '#{pane_id}' enter" \; switch-client -T awesome-sidebar
bind-key -T awesome-sidebar q run-shell "scripts/action disable '#{session_id}'"
bind-key -T awesome-sidebar Escape switch-client -T prefix
bind-key -T awesome-sidebar / command-prompt -i -T search
set-hook -g 'after-split-window[99]' 'run-shell "scripts/action refresh-from-hook"'
set-hook -g 'after-kill-pane[99]' 'run-shell "scripts/action refresh-from-hook"'
set-hook -g 'pane-exited[99]' 'run-shell "scripts/action refresh-from-hook"'
set-hook -g 'window-linked[99]' 'run-shell "scripts/action refresh-from-hook"'
set-hook -g 'window-renamed[99]' 'run-shell "scripts/action refresh-from-hook"'
set-hook -g 'session-closed[99]' 'run-shell "scripts/action refresh-from-hook"'
