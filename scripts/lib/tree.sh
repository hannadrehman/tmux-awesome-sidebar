#!/bin/sh
tas_build_rows() {
  group=$1
  tab=$(printf '\t')
  tas_tmux list-panes -a -F "#{pane_id}${tab}#{window_id}${tab}#{@awesome_sidebar_group}${tab}#{@awesome_sidebar_kind}${tab}#{@awesome_sidebar_name}${tab}#{pane_title}${tab}#{pane_current_path}${tab}#{pane_current_command}${tab}#{pane_index}${tab}#{pane_dead}" | awk -F '\t' -v g="$group" 'function base(p){n=split(p,a,"/");return a[n]} $3==g && $4!="sidebar" {k=($4=="session"?"session":"pane"); p=(k=="pane"?$2:""); n=$5; if(n=="")n=$6; if(n=="")n=base($7); print k "\t" (k=="session"?$2:$1) "\t" p "\t" n "\t" base($7) "\t\t" $7 "\t" $8 "\t" ($10=="1"?"dead":"active") "\t"}'
}
tas_tree_visible() { collapsed=${1-}; awk -F '\t' -v c=",$collapsed," '$1=="session"{show=(index(c,","$2",")==0); print; next} show && $1!="sidebar"{print}'; }
tas_cursor_move() { current=${1-}; direction=${2-}; awk -F '\t' -v id="$current" -v d="$direction" 'BEGIN{n=0}{if($1!="sidebar")a[++n]=$2}END{p=1;for(i=1;i<=n;i++)if(a[i]==id)p=i;if(d=="down"&&p<n)p++;if(d=="up"&&p>1)p--;if(d=="end")p=n;if(d=="home"||d=="gg")p=1;if(n)print a[p]}'; }
tas_parent_for_row() { awk -F '\t' -v id="$1" '$2==id{print $3;exit}'; }
tas_build_search_index() { tas_build_rows "${1-}"; }
tas_render() { width=$(tas_clamp_width "$1"); icons=$2; cursor=$3; printf '\033[2J\033[H'; awk -F '\t' -v w="$width" -v i="$icons" -v c="$cursor" 'function trim(s,n){n=w-length(g);if(n<0)n=0;return substr(s,1,n)}{$1=$1;g=(i=="nerd"?($1=="session"?"◆ ":"╰─ "):($1=="session"?"+ ":"  "));x=g trim($4);if($1=="session")x="\033[1m" x "\033[22m";if($2==c)x="\033[7m" x "\033[0m";if($9=="dead")x="\033[2m" x "\033[22m";print x}'; }
