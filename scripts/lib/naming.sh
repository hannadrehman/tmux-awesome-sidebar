#!/bin/sh
tas_tool_label() { case ${1-} in zsh|bash|fish) echo Shell;; nvim|vim) echo Neovim;; codex) echo Codex;; claude) echo Claude;; ssh) echo SSH;; 'go test'*|'npm test'|'yarn test'|'pnpm test'|'bun test'|*' test') echo Tests;; 'npm run dev'|'yarn dev'|'pnpm dev'|'bun dev') echo Server;; *) echo "${1:-Shell}";; esac; }
tas_choose_name() { manual=$1; title=$2; repo=$3; branch=$4; path=$5; command=$6; confidence=$7; if [ -n "$manual" ]; then printf '%s\n' "$manual"; elif [ -n "$title" ] && [ "$title" != localhost ]; then printf '%s\n' "$title"; elif [ -n "$repo" ] && [ -n "$branch" ]; then printf '%s · %s\n' "$(tas_tool_label "$command")" "$repo"; elif [ -n "$branch" ]; then printf '%s\n' "$branch"; else tas_tool_label "$command"; fi; }
tas_disambiguate_names() { awk -F '\t' '{n[$1]++; name[$1]=$1; id[$1]=id[$1] SUBSEP $2} END {for (x in n) if(n[x]>1){split(id[x],a,SUBSEP); for(i=2;i<=n[x]+1;i++) print a[i]"\t"x" "i-1}}'; }
tas_set_manual_name() { tas_validate_text "$2" || return 2; tas_tmux set-option -p -t "$1" @awesome_sidebar_name "$2"; }
tas_clear_manual_name() { tas_tmux set-option -pu -t "$1" @awesome_sidebar_name; }

tas_smart_window_name() {
  path=$1; index=${2:-0}
  repo=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || :)
  if [ -n "$repo" ]; then
    common=$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || :)
    case "$common" in /*) ;; *) common=$repo/$common ;; esac
    common=$(CDPATH= cd -- "$common" 2>/dev/null && pwd -P || :)
    if [ "$(basename "$common")" = .git ]; then
      folder=$(basename "$(dirname "$common")")
    else
      folder=$(basename "$repo")
    fi
    worktree=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || basename "$repo")
    worktree=$(printf '%s' "$worktree" | awk '{gsub(/[^[:alnum:]_.-]+/,"-");print}')
    printf '%s--%s\n' "$folder" "$worktree"
    return 0
  fi
  folder=$(basename "$path")
  [ -n "$folder" ] || folder=window
  printf '%s-%s\n' "$folder" "$index"
}

tas_sidebar_project_label() {
  path=$1
  repo=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || :)
  [ -n "$repo" ] || return 1
  common=$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || :)
  case "$common" in /*) ;; *) common=$repo/$common ;; esac
  common=$(CDPATH= cd -- "$common" 2>/dev/null && pwd -P || :)
  if [ "$(basename "$common")" = .git ]; then folder=$(basename "$(dirname "$common")"); else folder=$(basename "$repo"); fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || basename "$repo")
  folder=$(tas_sanitize_display "$folder"); branch=$(tas_sanitize_display "$branch")
  printf '%s(%s)\n' "$folder" "$branch"
}
