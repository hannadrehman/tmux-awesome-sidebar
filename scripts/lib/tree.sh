#!/bin/sh
if ! command -v tas_tmux >/dev/null 2>&1; then
  TREE_ROOT=${PROJECT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}
  . "$TREE_ROOT/scripts/lib/common.sh"
fi

tas_list_group_windows() {
  session=$1; tas_validate_id "$session" session || return 2
  tab=$(printf '\t')
  tas_tmux list-windows -t "$session" -F "#{window_id}${tab}#{window_index}${tab}#{window_name}${tab}#{@awesome_sidebar_name}${tab}#{@awesome_sidebar_worktree_path}" |
    awk -F '\t' 'BEGIN{OFS="|"}{for(i=1;i<=5;i++)gsub(/\|/,"",$i);print $1,$2,$3,$4,$5}' |
    sort -t '|' -k2,2n
}

tas_window_content_details() {
  window=$1; tas_validate_id "$window" window || return 2
  tab=$(printf '\t')
  tas_tmux list-panes -t "$window" -F "#{pane_id}${tab}#{@awesome_sidebar_kind}${tab}#{pane_active}${tab}#{pane_current_path}${tab}#{pane_current_command}${tab}#{pane_dead}" |
    awk -F '\t' '
      $2!="sidebar" {
        for(i=4;i<=6;i++)gsub(/\|/,"",$i)
        row=$4 "|" $5 "|" $6
        if($3==1){print row; chosen=1; exit}
        if(first=="")first=row
      }
      END{if(!chosen && first!="")print first}
    '
}

tas_list_content_panes() {
  tas_validate_id "$1" window || return 2
  tas_tmux list-panes -t "$1" -F '#{pane_id}	#{@awesome_sidebar_kind}	#{pane_index}' |
    awk -F '\t' '$2!="sidebar"{print $1}'
}

tas_build_rows() {
  session=$1; tas_validate_id "$session" session || return 2
  tab=$(printf '\t')
  key_sep=$(printf '\035')
  window_records=$(tas_list_group_windows "$session")
  enriched=''
  visible_repositories=''
  open_windows=''

  while IFS='|' read -r wid index wname manual managed; do
    [ -n "$wid" ] || continue
    details=$(tas_window_content_details "$wid")
    IFS='|' read -r raw_wpath command dead <<EOF
$details
EOF
    repo=$(git -C "$raw_wpath" rev-parse --show-toplevel 2>/dev/null || :)
    common=''; folder=''; worktree=''
    if [ -n "$repo" ]; then
      repo=$(CDPATH= cd -- "$repo" 2>/dev/null && pwd -P || :)
      # Older plugin versions recorded only the folder name when they opened a
      # worktree. Treat those windows as managed so upgrades fold them into the
      # existing child row instead of preserving a duplicate top-level row.
      if [ -z "$managed" ] && [ "$manual" = "$(basename "$raw_wpath")" ]; then
        managed=$repo
      fi
      common=$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || :)
      case "$common" in /*) ;; *) common=$repo/$common ;; esac
      common=$(CDPATH= cd -- "$common" 2>/dev/null && pwd -P || :)
      if [ "$(basename "$common")" = .git ]; then
        folder=$(basename "$(dirname "$common")")
      else
        folder=$(basename "$repo")
      fi
      worktree=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || basename "$repo")
      worktree=$(tas_sanitize_display "$worktree" | awk '{gsub(/\|/,"");print}')
      open_windows=$(printf '%s\n%s|%s' "$open_windows" "$repo" "$wid")
      if [ -z "$managed" ]; then
        visible_repositories=$visible_repositories$key_sep$common$key_sep
      fi
    fi
    line=$(printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s' \
      "$wid" "$index" "$wname" "$manual" "$managed" "$raw_wpath" "$command" "$dead" "$repo" "$common" "$folder" "$worktree")
    enriched=$(printf '%s\n%s' "$enriched" "$line")
  done <<EOF
$window_records
EOF

  seen_repositories=''
  promoted_managed=''
  while IFS='|' read -r wid index wname manual managed raw_wpath command dead repo common folder worktree; do
    [ -n "$wid" ] || continue
    hidden=0
    if [ -n "$managed" ] && [ -n "$common" ]; then
      case "$visible_repositories$promoted_managed" in
        *"$key_sep$common$key_sep"*) hidden=1 ;;
        *) promoted_managed=$promoted_managed$key_sep$common$key_sep ;;
      esac
    fi
    [ "$hidden" -eq 0 ] || continue

    if [ -n "$repo" ]; then name=$folder'('$worktree')'
    else name=$manual; [ -n "$name" ] || name=$(basename "$raw_wpath")-$index
    fi
    name=$(tas_sanitize_display "$name")
    wpath=$(tas_sanitize_display "$raw_wpath")
    command=$(tas_sanitize_display "$command")
    [ "$dead" = 1 ] && status=dead || status=active
    printf 'session\t%s\t\t%s\t\t\t%s\t%s\t%s\t\n' "$wid" "$name" "$wpath" "$command" "$status"

    [ -n "$repo" ] && [ -n "$common" ] || continue
    case "$seen_repositories" in
      *"$key_sep$common$key_sep"*) continue ;;
    esac
    seen_repositories=$seen_repositories$key_sep$common$key_sep
    git -C "$repo" worktree list --porcelain 2>/dev/null |
      awk '
        function emit() {
          if (path == "") return
          if (branch == "") branch="(detached)"
          print branch "\t" path
          path=""; branch=""
        }
        /^worktree / { emit(); path=substr($0,10); next }
        /^branch / { branch=substr($0,8); sub(/^refs\/heads\//,"",branch); next }
        /^$/ { emit(); next }
        END { emit() }
      ' | while IFS="$tab" read -r branch wtpath; do
        [ -n "$wtpath" ] || continue
        branch=$(tas_sanitize_display "$branch")
        wtpath=$(tas_sanitize_display "$wtpath")
        canonical=$(CDPATH= cd -- "$wtpath" 2>/dev/null && pwd -P || printf '%s' "$wtpath")
        open_window=$(printf '%s' "$open_windows" | awk -F '|' -v p="$canonical" '$1==p{print $2;exit}')
        label=$branch; child_status=dormant
        if [ -n "$open_window" ]; then label="$label *"; child_status=active; fi
        printf 'worktree\tworktree:%s\t%s\t%s\t%s\t%s\t%s\t\t%s\tworktree\t%s\n' \
          "$wtpath" "$wid" "$label" "$folder" "$branch" "$wtpath" "$child_status" "$open_window"
      done
  done <<EOF
$enriched
EOF
}

tas_tree_visible() {
  collapsed=${1-}
  awk -F '\t' -v c=",$collapsed," '$1=="session"{show=(index(c,","$2",")==0);print;next}show&&$1!="sidebar"{print}'
}

tas_cursor_move() {
  current=${1-}; direction=${2-}; step=${3:-1}
  awk -F '\t' -v id="$current" -v d="$direction" -v s="$step" '
    {if($1!="sidebar")a[++n]=$2}
    END {
      p=1
      for(i=1;i<=n;i++)if(a[i]==id)p=i
      if(s<1)s=1
      if(d=="down"&&p<n)p++
      if(d=="up"&&p>1)p--
      if(d=="page-down"){p+=s;if(p>n)p=n}
      if(d=="page-up"){p-=s;if(p<1)p=1}
      if(d=="end"||d=="G")p=n
      if(d=="home"||d=="gg")p=1
      if(n)print a[p]
    }'
}

tas_parent_for_row() { awk -F '\t' -v id="$1" '$2==id{print $3;exit}'; }
tas_build_search_index() { tas_build_rows "$1"; }

tas_filter_rows() {
  query=${1-}
  if [ -z "$query" ]; then
    cat
  else
    search_awk=${TAS_SEARCH_AWK:-${PROJECT_ROOT:-.}/scripts/search.awk}
    awk -v query="$query" -f "$search_awk" | awk -F '\t' '{sub(/^[^\t]*\t/, ""); print}'
  fi
}

tas_render() {
  width=$(tas_clamp_width "$1"); icons=$2; cursor=$3; query=${4-}; search_mode=${5:-0}; previous=${6-}
  # Repaint in place. Clearing the entire terminal here causes a visible blank
  # frame between every cursor movement in tmux.
  if [ -z "$previous" ]; then
    if [ "$search_mode" -eq 1 ]; then suffix=_; else suffix=''; fi
    printf '\033[H\033[2KSearch: %s%s\n' "$query" "$suffix"
  fi
  awk -F '\t' -v w="$width" -v i="$icons" -v c="$cursor" -v p="$previous" '
  BEGIN { e=sprintf("%c",27) }
  function truncate(s,n) { return length(s)>n ? substr(s,1,n) "..." : s }
  {
    if ($1=="session") prefix=(i=="nerd" ? "◆ " : "+ ")
    else prefix=(i=="nerd" ? "  ├─ " : "  |- ")
    text=prefix truncate($4,24)
    if ($1=="session") text=e "[1m" text e "[22m"
    if ($2==c) text=e "[7m" text e "[0m"
    if ($9=="dead") text=e "[2m" text e "[22m"
    if (p!="") {
      if ($2==p || $2==c) printf e "[%d;1H" e "[2K%s", NR+1, text
      next
    }
    print e "[2K" text
  }
  END { if (p=="") printf e "[J" }
  '
}
