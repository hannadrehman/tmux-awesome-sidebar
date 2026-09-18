#!/bin/sh

tas_path_key() {
  printf '%s' "${1-}" | cksum | awk '{print $1 "_" $2}'
}

tas_path_option() {
  prefix=$1
  path=$2
  printf '@awesome_sidebar_%s_%s\n' "$prefix" "$(tas_path_key "$path")"
}

tas_path_option_get() {
  option=$(tas_path_option "$1" "$2")
  # A single show-options dump is primed by callers that do many lookups
  # (tree building); each individual tmux exec costs more than the lookup.
  if [ -n "${TAS_OPTIONS_DUMP:-}" ]; then
    printf '%s' "$TAS_OPTIONS_DUMP" | awk -v o="$option" '
      $1 == o {
        sub(/^[^ \t]*[ \t]/, "")
        # show-options quotes values that contain spaces; -qv does not.
        if ($0 ~ /^"[^"]*"$/) $0 = substr($0, 2, length($0) - 2)
        print; exit
      }'
  else
    tas_tmux show-option -gqv "$option"
  fi
}

tas_path_option_set() {
  option=$(tas_path_option "$1" "$2")
  value=${3-}
  if [ -n "$value" ]; then
    tas_validate_text "$value" || return 2
    tas_tmux set-option -g "$option" "$value"
  else
    tas_tmux set-option -gu "$option" 2>/dev/null || :
  fi
}

tas_touch_recent() {
  kind=$1
  target=$2
  path=${3-}
  stamp=$(date +%s)
  case "$kind" in
    session) tas_tmux set-option -w -t "$target" @awesome_sidebar_recent "$stamp" ;;
    worktree) tas_path_option_set recent "$path" "$stamp" ;;
    *) return 2 ;;
  esac
}

tas_status_cache_dir() {
  printf '%s/tmux-awesome-sidebar/status\n' "${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}"
}

tas_status_cache_read() {
  path=$1
  file=$(tas_status_cache_dir)/$(tas_path_key "$path")
  [ -r "$file" ] || return 0
  sed -n '2p' "$file"
}

tas_status_cache_refresh() {
  path=$1
  group=${2-}
  quiet=${3-}
  helper=${PROJECT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/git-status-cache
  [ -x "$helper" ] || return 0
  "$helper" refresh "$path" "$group" "$quiet" >/dev/null 2>&1 &
}
