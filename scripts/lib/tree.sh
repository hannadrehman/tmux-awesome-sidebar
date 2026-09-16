#!/bin/sh
if ! command -v tas_tmux >/dev/null 2>&1; then
  TREE_ROOT=${PROJECT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}
  . "$TREE_ROOT/scripts/lib/common.sh"
fi

tas_list_group_windows() {
  session=$1; tas_validate_id "$session" session || return 2
  tas_tmux list-windows -t "$session" -F '#{window_id}	#{session_id}	#{@awesome_sidebar_group}	#{@awesome_sidebar_kind}	#{window_index}	#{window_name}	#{pane_current_path}' |
    sort -t "$(printf '\t')" -k5,5n
}
tas_list_content_panes() {
  tas_validate_id "$1" window || return 2
  tas_tmux list-panes -t "$1" -F '#{pane_id}	#{@awesome_sidebar_kind}	#{pane_index}' | awk -F '\t' '$2!="sidebar"{print $1}'
}
tas_build_rows() {
  session=$1; tas_validate_id "$session" session || return 2; tab=$(printf '\t')
  tas_list_group_windows "$session" | while IFS="$tab" read -r wid sid wgroup kind order wname wpath; do
    [ -n "$wid" ] || continue
    name=$(tas_tmux display-message -p -t "$wid" '#{@awesome_sidebar_name}')
    [ -n "$name" ] || name=$wname
    path=$(tas_tmux display-message -p -t "$wid" '#{pane_current_path}')
    repo=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || :)
    branch=$(git -C "$path" symbolic-ref --short -q HEAD 2>/dev/null || echo '(detached)')
    cmd=$(tas_tmux display-message -p -t "$wid" '#{pane_current_command}')
    dead=$(tas_tmux display-message -p -t "$wid" '#{pane_dead}')
    tas_validate_text "$name" && tas_validate_text "$repo" && tas_validate_text "$branch" && tas_validate_text "$path" || continue
    printf 'session\t%s\t\t%s\t%s\t%s\t%s\t%s\t%s\t\n' "$wid" "$name" "$repo" "$branch" "$path" "$cmd" "$( [ "$dead" = 1 ] && echo dead || echo active )"
  done
}
tas_tree_visible() {
  collapsed=${1-}; awk -F '\t' -v c=",$collapsed," '$1=="session"{show=(index(c,","$2",")==0);print;next}show&&$1!="sidebar"{print}'
}
tas_cursor_move() {
  current=${1-}; direction=${2-}
  awk -F '\t' -v id="$current" -v d="$direction" '{if($1!="sidebar")a[++n]=$2} END{p=1;for(i=1;i<=n;i++)if(a[i]==id)p=i;if(d=="down"&&p<n)p++;if(d=="up"&&p>1)p--;if(d=="end"||d=="G")p=n;if(d=="home"||d=="gg")p=1;if(n)print a[p]}'
}
tas_parent_for_row() { awk -F '\t' -v id="$1" '$2==id{print $3;exit}'; }
tas_build_search_index() { tas_build_rows "$1"; }
tas_render() {
  width=$(tas_clamp_width "$1"); icons=$2; cursor=$3; query=${4-}
  printf '\033[2J\033[H'
  search_awk=${TAS_SEARCH_AWK:-${PROJECT_ROOT:-.}/scripts/search.awk}
  if [ -n "$query" ]; then
    awk -v query="$query" -f "$search_awk" | awk -F '\t' '{sub(/^[^\t]*\t/, ""); print}'
  else
    cat
  fi | awk -F '\t' -v w="$width" -v i="$icons" -v c="$cursor" '
  BEGIN { e=sprintf("%c",27) }
  function shorten(s,n) { return substr(s,1,n) }
  {
    prefix=(i=="nerd" ? ($1=="session" ? "◆ " : "╰─ ") : ($1=="session" ? "+ " : "  "))
    text=prefix shorten($4,w-length(prefix))
    if ($1=="session") text=e "[1m" text e "[22m"
    if ($2==c) text=e "[7m" text e "[0m"
    if ($9=="dead") text=e "[2m" text e "[22m"
    print text
  }'
}
