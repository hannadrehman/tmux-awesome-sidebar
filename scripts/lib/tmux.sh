#!/bin/sh
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)/common.sh"
tas_list_group_windows() { group=${1-}; tas_validate_text "$group" || return 2; tab=$(printf '\t'); tas_tmux list-windows -a -F "#{window_id}${tab}#{session_id}${tab}#{@awesome_sidebar_group}${tab}#{@awesome_sidebar_kind}${tab}#{@awesome_sidebar_order}${tab}#{window_name}" | awk -F '\t' -v g="$group" '$3==g && $4!="sidebar" {print}' | sort -t '	' -k5,5n -k1,1n; }
tas_list_content_panes() { window_id=$1; tas_validate_id "$window_id" window || return 2; tab=$(printf '\t'); tas_tmux list-panes -t "$window_id" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}" | awk -F '\t' '$2!="sidebar" {print $1}'; }
tas_option_rows() { tab=$(printf '\t'); tas_tmux list-panes -a -F "#{pane_id}${tab}#{window_id}${tab}#{session_id}${tab}#{@awesome_sidebar_kind}${tab}#{@awesome_sidebar_name}${tab}#{pane_title}${tab}#{pane_current_path}${tab}#{pane_current_command}${tab}#{pane_index}${tab}#{pane_dead}"; }
