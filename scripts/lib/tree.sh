#!/bin/sh
TREE_ROOT=${TREE_ROOT:-${PROJECT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}}
if ! command -v tas_tmux >/dev/null 2>&1; then
  . "$TREE_ROOT/scripts/lib/common.sh"
fi
if ! command -v tas_path_key >/dev/null 2>&1; then
  . "$TREE_ROOT/scripts/lib/state.sh"
fi

tas_list_group_windows() {
  session=$1; tas_validate_id "$session" session || return 2
  tab=$(printf '\t')
  records=$(tas_tmux list-windows -t "$session" -F "#{window_id}${tab}#{window_index}${tab}#{window_name}${tab}#{@awesome_sidebar_name}${tab}#{@awesome_sidebar_worktree_path}${tab}#{@awesome_sidebar_recent}${tab}#{@awesome_sidebar_label}" |
    awk -F '\t' 'BEGIN{OFS="|"}{for(i=1;i<=7;i++)gsub(/\|/,"",$i);print $1,$2,$3,$4,$5,$6,$7}')
  if [ "$(tas_tmux show-option -gqv @awesome_sidebar_sort)" = recent ]; then
    printf '%s\n' "$records" | sort -t '|' -k6,6nr -k2,2n
  else
    printf '%s\n' "$records" | sort -t '|' -k2,2n
  fi
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

# Emit the worktree child rows for one repository. Kept as a separate
# function so tas_build_rows can run one background job per repository;
# the per-worktree lookups dominate the build time and parallelising them
# keeps a full tree rebuild well under a second.
tas_build_children() {
  repo=$1; wid=$2; folder=$3; group=$4; sort_mode=$5; open_windows=$6
  tab=$(printf '\t')
  children=$(git -C "$repo" worktree list --porcelain 2>/dev/null |
    awk '
      function emit() {
        if (path == "") return
        if (branch == "") branch="(detached)"
        print ++sequence "\t" branch "\t" path
        path=""; branch=""
      }
      /^worktree / { emit(); path=substr($0,10); next }
      /^branch / { branch=substr($0,8); sub(/^refs\/heads\//,"",branch); next }
      /^$/ { emit(); next }
      END { emit() }
    ')
  if [ "$sort_mode" = recent ]; then
    ranked=$(printf '%s\n' "$children" | while IFS="$tab" read -r sequence branch wtpath; do
      recent=$(tas_path_option_get recent "$wtpath")
      if ! printf '%s\n' "$recent" | awk '/^[0-9]+$/{ok=1}END{exit !ok}'; then recent=0; fi
      printf '%s\t%s\t%s\t%s\n' "$recent" "$sequence" "$branch" "$wtpath"
    done | sort -t "$tab" -k1,1nr -k2,2n)
  else
    ranked=$(printf '%s\n' "$children" | awk -F '\t' 'BEGIN{OFS="\t"}{print 0,$1,$2,$3}')
  fi
  now=$(date +%s)
  printf '%s\n' "$ranked" | while IFS="$tab" read -r recent sequence branch wtpath; do
      [ -n "$wtpath" ] || continue
      cleaned=$(printf '%s\n%s\n' "$branch" "$wtpath" | awk '{gsub(/[\001-\011\013-\014\016-\037\177\033]/,"")} NR==1{b=$0;next}{printf "%s\t%s\n", b, $0}')
      branch=${cleaned%%"$tab"*}; wtpath=${cleaned#*"$tab"}
      canonical=$(CDPATH= cd -- "$wtpath" 2>/dev/null && pwd -P || printf '%s' "$wtpath")
      key=$(tas_path_key "$canonical")
      lookup=$(tas_child_lookup "$canonical" "$key" "$open_windows")
      open_window=${lookup%%"$tab"*}; rest=${lookup#*"$tab"}
      alias=${rest%%"$tab"*}; rest=${rest#*"$tab"}
      badge=${rest%%"$tab"*}; stamp=${rest#*"$tab"}
      case $stamp in *[!0-9]*|'') stamp=0;; esac
      label=$branch; child_status=dormant
      if [ -n "$open_window" ]; then label="$label *"; child_status=active; fi
      [ -z "$alias" ] || label=$alias
      if [ $((now - stamp)) -ge 5 ] && [ -z "${TAS_SKIP_BADGES:-}" ]; then
        if [ -n "${TAS_EMIT_STALE:-}" ]; then
          printf '%s\n' "$canonical" >> "$TAS_EMIT_STALE"
        else
          tas_status_cache_refresh "$canonical" "$group"
        fi
      fi
      printf 'worktree\tworktree:%s\t%s\t%s\t%s\t%s\t%s\t\t%s\tworktree\t%s\t%s\n' \
        "$wtpath" "$wid" "$label" "$folder" "$branch" "$wtpath" "$child_status" "$open_window" "$badge"
    done
}

# Single-awk lookup for one worktree: the open window, alias label, cached
# badge and the badge cache timestamp. Collapsing these into one process
# keeps the per-worktree cost at one fork instead of a dozen.
tas_child_lookup() {
  canonical=$1; key=$2; open_windows=$3
  alias_option=@awesome_sidebar_alias_$key
  status_file=$(tas_status_cache_dir)/$key
  if [ -n "${TAS_EMIT_DUMP:-}" ] && [ -r "$TAS_EMIT_DUMP" ]; then
    TAS_CHILD_OW=$open_windows
    export TAS_CHILD_OW
    awk -v o="$alias_option" -v f="$status_file" -v p="$canonical" '
      BEGIN {
        while ((getline line < f) > 0) { if (++n == 1) stamp = line; else if (n == 2) badge = line }
        close(f)
      }
      $1 == o {
        sub(/^[^ \t]*[ \t]?/, "")
        # show-options quotes values that contain spaces; -qv does not.
        if ($0 ~ /^"[^"]*"$/) $0 = substr($0, 2, length($0) - 2)
        alias = $0
      }
      END {
        count = split(ENVIRON["TAS_CHILD_OW"], rows, "\n")
        for (i = 1; i <= count; i++) {
          split(rows[i], part, "|")
          if (part[1] == p) { win = part[2]; break }
        }
        printf "%s\t%s\t%s\t%s\n", win, alias, badge, stamp
      }' "$TAS_EMIT_DUMP"
  else
    open_window=$(printf '%s' "$open_windows" | awk -F '|' -v p="$canonical" '$1==p{print $2;exit}')
    alias=$(tas_path_option_get alias "$canonical")
    stamp=''; badge=''
    if [ -r "$status_file" ]; then
      stamp=$(sed -n '1p' "$status_file"); badge=$(sed -n '2p' "$status_file")
    fi
    printf '%s\t%s\t%s\t%s\n' "$open_window" "$alias" "$badge" "$stamp"
  fi
}

# Row emission with optional per-repository parallelism. tas_emit_reset primes a
# single show-options dump (option lookups are the most expensive per-worktree
# call) and a temp dir; tas_emit_children then runs one background job per
# repository and tas_emit_flush reassembles rows in the original order.
tas_emit_reset() {
  TAS_EMIT_TMP=''
  TAS_EMIT_EVENTS=''
  TAS_EMIT_DUMP=''
  TAS_EMIT_JOB=0
  candidate="${TMPDIR:-/tmp}/tas-build.$$"
  if mkdir -p "$candidate" 2>/dev/null && : > "$candidate/events"; then
    TAS_EMIT_TMP=$candidate
    TAS_EMIT_EVENTS=$candidate/events
    TAS_EMIT_DUMP=$candidate/dump
    printf '%s\n' "$TAS_OPTIONS_DUMP" > "$TAS_EMIT_DUMP"
    TAS_EMIT_STALE=$candidate/stale
    : > "$TAS_EMIT_STALE"
    # Safety net: if this build is killed mid-stream (e.g. a downstream awk in
    # a pipeline exits early), still remove the temp dir instead of leaking it.
    trap '' PIPE
    trap 'rm -rf "$TAS_EMIT_TMP" 2>/dev/null || :' EXIT
  fi
}

tas_emit_line() {
  if [ -n "$TAS_EMIT_EVENTS" ]; then
    printf 'S\t%s\n' "$1" >> "$TAS_EMIT_EVENTS"
  else
    printf '%s\n' "$1"
  fi
}

tas_emit_children() {
  if [ -n "$TAS_EMIT_EVENTS" ]; then
    TAS_EMIT_JOB=$((TAS_EMIT_JOB + 1))
    job_file=$TAS_EMIT_TMP/children.$TAS_EMIT_JOB
    tas_build_children "$@" > "$job_file" 2>/dev/null < /dev/null &
    printf 'C\t%s\n' "$job_file" >> "$TAS_EMIT_EVENTS"
  else
    tas_build_children "$@"
  fi
}

tas_emit_flush() {
  [ -n "$TAS_EMIT_EVENTS" ] || return 0
  wait || :
  tab=$(printf '\t')
  while IFS= read -r event_line; do
    [ -n "$event_line" ] || continue
    case $event_line in
      S*) printf '%s\n' "${event_line#S$tab}" ;;
      C*) cat "${event_line#C$tab}" 2>/dev/null || : ;;
    esac
  done < "$TAS_EMIT_EVENTS"
  # Refresh stale badges in one detached batch that signals the group once
  # when everything is done, instead of one signal (and one full rebuild)
  # per worktree completion.
  if [ -n "${TAS_EMIT_STALE:-}" ] && [ -s "$TAS_EMIT_STALE" ]; then
    stale_list=$(cat "$TAS_EMIT_STALE")
    stale_group=$group
    (
      while IFS= read -r stale_path; do
        [ -n "$stale_path" ] || continue
        tas_status_cache_refresh "$stale_path" "$stale_group" quiet
      done <<EOF
$stale_list
EOF
      wait || :
      # C-e tells the sidebar to pick up the new badges without spawning
      # another refresh batch: the batch can take longer than the cache TTL,
      # and re-spawning would loop build -> batch -> signal forever.
      tas_signal_group "$stale_group" C-e || :
    ) </dev/null >/dev/null 2>&1 &
  fi
  rm -rf "$TAS_EMIT_TMP" 2>/dev/null || :
  TAS_EMIT_EVENTS=''
  TAS_EMIT_TMP=''
  trap - EXIT PIPE
}

tas_build_rows() {
  session=$1; tas_validate_id "$session" session || return 2
  tab=$(printf '\t')
  key_sep=$(printf '\035')
  window_records=$(tas_list_group_windows "$session")
  enriched=''
  visible_repositories=''
  open_windows=''
  group=$(tas_tmux show-option -qv -t "$session" @awesome_sidebar_group)
  sort_mode=$(tas_tmux show-option -gqv @awesome_sidebar_sort)
  TAS_OPTIONS_DUMP=$(tas_tmux show-options -g)
  export TAS_OPTIONS_DUMP
  tas_emit_reset

  while IFS='|' read -r wid index wname manual managed recent alias; do
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
    line=$(printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s' \
      "$wid" "$index" "$wname" "$manual" "$managed" "$raw_wpath" "$command" "$dead" "$repo" "$common" "$folder" "$worktree" "$alias")
    enriched=$(printf '%s\n%s' "$enriched" "$line")
  done <<EOF
$window_records
EOF

  seen_repositories=''
  promoted_managed=''
  while IFS='|' read -r wid index wname manual managed raw_wpath command dead repo common folder worktree alias; do
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
    [ -z "$alias" ] || name=$alias
    clean=$(printf '%s\n%s\n%s\n' "$name" "$raw_wpath" "$command" |
      awk '{gsub(/[\001-\011\013-\014\016-\037\177\033]/,"")} NR==1{n=$0;next} NR==2{w=$0;next}{printf "%s\t%s\t%s\n",n,w,$0}')
    name=${clean%%"$tab"*}; rest=${clean#*"$tab"}
    wpath=${rest%%"$tab"*}; command=${rest#*"$tab"}
    [ "$dead" = 1 ] && status=dead || status=active
    line=$(printf 'session\t%s\t\t%s\t\t\t%s\t%s\t%s\t\n' "$wid" "$name" "$wpath" "$command" "$status")
    tas_emit_line "$line"

    [ -n "$repo" ] && [ -n "$common" ] || continue
    case "$seen_repositories" in
      *"$key_sep$common$key_sep"*) continue ;;
    esac
    seen_repositories=$seen_repositories$key_sep$common$key_sep
    tas_emit_children "$repo" "$wid" "$folder" "$group" "$sort_mode" "$open_windows"
  done <<EOF
$enriched
EOF
  tas_emit_flush
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
      if(d=="down"){p+=s;if(p>n)p=n}
      if(d=="up"){p-=s;if(p<1)p=1}
      if(d=="page-down"){p+=s;if(p>n)p=n}
      if(d=="page-up"){p-=s;if(p<1)p=1}
      if(d=="end"||d=="G")p=n
      if(d=="home"||d=="gg")p=1
      if(n)print a[p]
    }'
}

tas_parent_for_row() { awk -F '\t' -v id="$1" '$2==id && !found {print $3; found=1}'; }
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

tas_slice_rows() {
  offset=${1:-0}; limit=${2:-1}
  awk -v o="$offset" -v l="$limit" 'NR>o && NR<=o+l'
}

tas_render() {
  width=$(tas_clamp_width "$1"); icons=$2; cursor=$3; query=${4-}; search_mode=${5:-0}; previous=${6-}; collapsed=${7-}
  # Repaint in place. Clearing the entire terminal here causes a visible blank
  # frame between every cursor movement in tmux.
  if [ -z "$previous" ]; then
    if [ "$search_mode" -eq 1 ]; then suffix=_; else suffix=''; fi
    printf '\033[H\033[2KSearch: %s%s\n' "$query" "$suffix"
  fi
  awk -F '\t' -v w="$width" -v i="$icons" -v c="$cursor" -v p="$previous" -v collapsed=",$collapsed," '
  BEGIN { e=sprintf("%c",27) }
  function truncate(s,n) { return length(s)>n ? substr(s,1,n) "..." : s }
  {
    if ($1=="session") {
      closed=index(collapsed,","$2",")>0
      prefix=(i=="nerd" ? (closed ? "▸ " : "▾ ") : (closed ? "+ " : "- "))
    }
    else prefix=(i=="nerd" ? "  ├─ " : "  |- ")
    badge=$12; if (badge!="") badge=" " badge
    text=prefix truncate($4,24) badge
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
