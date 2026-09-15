#!/bin/sh
tas_tmux() {
  if [ -n "${TMUX_SOCKET:-}" ]; then
    command "${TMUX_BIN:-tmux}" -L "$TMUX_SOCKET" "$@"
  else
    command "${TMUX_BIN:-tmux}" "$@"
  fi
}
tas_validate_id() {
  id=${1-}; kind=${2-}
  case "$kind:$id" in pane:%[0-9]*) ;; window:@[0-9]*) ;; session:\$[0-9]*) ;; *) return 2;; esac
  case ${id#?} in *[!0-9]*|'') return 2;; esac
}
tas_validate_text() { LC_ALL=C awk 'BEGIN {v=ARGV[1]; if (v ~ /[\001-\012\013-\037\177\033]/) exit 1}' "${1-}"; }
tas_sanitize_display() { printf '%s' "${1-}" | LC_ALL=C awk '{gsub(/[\001-\011\013\014\016-\037\177\033]/, ""); printf "%s", $0}'; }
tas_clamp_width() { width=${1:-28}; case $width in *[!0-9]*|'') width=28;; esac; [ "$width" -lt 16 ] && width=16; [ "$width" -gt 80 ] && width=80; printf '%s\n' "$width"; }
tas_get_option() { tas_tmux show-option "$1" -qv -t "$2" "$3"; }
tas_set_option() { tas_validate_text "$4" || return 2; tas_tmux set-option "$1" -t "$2" "$3" "$4"; }
tas_lock_name() { printf '%s' "${1-}" | LC_ALL=C awk '{gsub(/[^A-Za-z0-9_.-]/,"_"); printf "awesome-sidebar-lock-%s",$0}'; }
tas_with_group_lock() {
  group=${1-}; shift || return 2
  tas_validate_text "$group" && [ -n "$group" ] && [ "$#" -gt 0 ] || return 2
  lock=$(tas_lock_name "$group") || return 2
  tas_tmux wait-for -L "$lock" || return 1
  trap 'tas_tmux wait-for -U "$lock" >/dev/null 2>&1 || :' EXIT HUP INT TERM
  "$@"; result=$?
  trap - EXIT HUP INT TERM
  tas_tmux wait-for -U "$lock" >/dev/null 2>&1 || :
  return "$result"
}
tas_signal_sidebar() { id=${1-}; tas_validate_id "$id" pane || return 2; tas_tmux wait-for -S "awesome-sidebar-refresh-${id#%}"; }
tas_signal_group() { group=${1-}; tas_validate_text "$group" && [ -n "$group" ] || return 2; lock=$(tas_lock_name "$group"); tas_tmux wait-for -S "$lock"; }
