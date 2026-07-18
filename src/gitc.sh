#!/bin/zsh
# MIT License
# 
# Copyright (c) 2026 MrurBo
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
setopt NULL_GLOB
zmodload zsh/datetime
ROOT_DIR=/var/www/cgi-bin/
source ${ROOT_DIR}config

typeset -F START_TIME=$EPOCHREALTIME

page=(${(s:/:)PATH_INFO})

is_git_repo() {
  local dir=$1
  local result
  result=$($GIT_BIN -C "$dir" rev-parse --is-bare-repository 2>/dev/null)
  [ "$result" = "true" ]
}

html_escape() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  print -r -- "$s"
}

send_header() {
  local cache=${1:-"no-cache"}
  echo "Content-type: text/html; charset=utf-8"
  echo "Cache-Control: $cache"
  echo
}

render_index() {
  send_header
  header "/" "index"
  if [ -f "${GIT_REPOS_PATH}/README.md" ]; then
    render_markdown "${GIT_REPOS_PATH}/README.md"
  fi
  echo "<ul>"
  _walk "$GIT_REPOS_PATH/"
  echo "</ul>"
  footer "/" "0"
}

_walk() {
  local base=$1 repo rel
  for repo in "$base"*/(N); do
    if is_git_repo "$repo"; then
      rel=${repo#$GIT_REPOS_PATH/}
      rel=${rel%/}
      echo "<li><a href=\"/$(html_escape "$rel")\">$(html_escape "$rel")</a></li>"
    else
      _walk "$repo"
    fi
  done
}

page_head() {
  local rel=$1
  local name=$2
  echo "<!DOCTYPE html>"
  echo "<html>"
  echo "<head>"
  echo "<meta charset=\"utf-8\">"
  echo "<style>"
  echo $(<${ROOT_DIR}style.css)
  echo "</style>"
  echo "<title>$title - $rel | $name</title>"
  echo "</head>"
  echo "<body>"
}

foot() {
  echo "</body></html>"
}

header() {
  local rel=$1
  local name=$2
  local erel=$(html_escape "$rel")
  page_head ${rel} ${name}
  echo "<h1><a href=\"/$erel\">$erel</a> — $name</h1>" # e.g. MrurBo/test2 - commits
}

footer() {
  local rel=$1
  local nav=${2:-1}
  echo "<footer>"
  if [ "$nav" = "1" ]; then
    navigation ${rel}
  fi
  local elapsed
  elapsed=$(( EPOCHREALTIME - START_TIME ))
  local ms
  ms=$(( elapsed * 1000 ))
  printf '<small>rendered by gitc @ %s in %.1f ms</small>\n' $(/bin/date +%H:%M:%S) $ms
  echo "</footer>"
  foot
}

navigation() {
  local rel=$1
  local erel=$(html_escape "$rel")
  echo "<nav>"
  echo "<a href=\"/\">index</a>"
  echo " | <a href=\"/$erel\">summary</a>"
  echo " | <a href=\"/$erel/commits\">commits</a>"
  echo " | <a href=\"/$erel/tree\">tree</a>"
  echo "</nav>"
}

render_markdown() {
  $CMARK_BIN "$@"
}

render_repo() {
  local rel=$1
  local dir="$GIT_REPOS_PATH/$rel"
  send_header
  header ${rel} "index"
  if [ -f "$dir/description" ]; then
    local desc
    desc=$(<"$dir/description")
    echo "<small>"
    case "$desc" in
      "Unnamed repository"*) ;;
      *) echo "<p>$(html_escape "$desc")</p>" ;;
    esac
    echo "</small>"
  fi
  echo "<div class=\"md\">"
  local content
  if content=$($GIT_BIN -C "$dir" show HEAD:README.md 2>/dev/null); then
    print -r -- "$content" | render_markdown /dev/stdin
  fi
  echo "</div>"
  footer ${rel}
}

render_404() {
  echo "Status: 404 Not Found"
  echo "Content-type: text/html; charset=utf-8"
  echo
  echo "<!DOCTYPE html><html><body><h1>404 Not Found</h1></body></html>"
}

render_commits() {
  local rel=$1 dir=$2
  send_header
  header ${rel} "commits"
  echo "<ul>"
  local hash subject author date
  $GIT_BIN -C "$dir" log -n 100 --format='%h%x1f%s%x1f%an%x1f%ar' 2>/dev/null | \
  while IFS=$'\x1f' read -r hash subject author date; do
    echo "<li><a href=\"$BASE/$(html_escape "$rel")/commit/$(html_escape "$hash")\"><code>$(html_escape "$hash")</code></a> — $(html_escape "$subject") <small>($(html_escape "$author"), $(html_escape "$date"))</small></li>"
  done
  echo "</ul>"
  footer "${rel}"
}

render_blob() {
    local rel=$1 dir=$2 path=$3
    send_header
    header "${rel}" "$(html_escape "$path") | <a href=\"/$rel/raw/$path\">raw</a> | <a href=\"/$rel/download/$path\">download</a>"

    local otype
    otype=$($GIT_BIN -C "$dir" cat-file -t "HEAD:$path" 2>/dev/null)
    if [ "$otype" != "blob" ]; then
        echo "<h2>404 Not Found</h2>"
        footer "$rel"
        return
    fi

    case "$path" in
        *.md|*.markdown)
            echo "<div class=\"md\">"
            $GIT_BIN -C "$dir" show "HEAD:$path" 2>/dev/null | render_markdown /dev/stdin
            echo "</div>"
            ;;
        *)
            echo "<pre>"
            $GIT_BIN -C "$dir" show "HEAD:$path" 2>/dev/null \
                | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
            echo "</pre>"
            ;;
    esac

    footer "$rel"
}

render_raw() {
  local rel=$1 dir=$2 path=$3
  local otype
  otype=$($GIT_BIN -C "$dir" cat-file -t "HEAD:$path" 2>/dev/null)
  if [ "$otype" != "blob" ]; then
    render_404
    return
  fi
  echo "Content-type: text/plain"
  echo "Cache-Control: no-cache"
  echo
  $GIT_BIN -C "$dir" show "HEAD:$path" 2>/dev/null
}

render_download() {
  local rel=$1 dir=$2 path=$3
  local otype
  otype=$($GIT_BIN -C "$dir" cat-file -t "HEAD:$path" 2>/dev/null)
  if [ "$otype" != "blob" ]; then
    render_404
    return
  fi
  local fname=${path##*/}
  echo "Content-type: application/octet-stream"
  echo "Content-Disposition: attachment; filename=\"$(html_escape "$fname")\""
  echo "Cache-Control: no-cache"
  echo
  $GIT_BIN -C "$dir" show "HEAD:$path" 2>/dev/null
}

render_tree() {
  local rel=$1 dir=$2 path=$3
  send_header
  header ${rel} "tree /$(html_escape "$path")"
  local erel=$(html_escape "$rel")
  echo "<ul>"
  local mode type obj name
  local ref="HEAD"
  [ -n "$path" ] && ref="HEAD:$path"
  $GIT_BIN -C "$dir" ls-tree "$ref" 2>/dev/null | \
  while read -r mode type obj name; do
    local full="$name"
    [ -n "$path" ] && full="$path/$name"
    local efull=$(html_escape "$full")
    local ename=$(html_escape "$name")
    local url=""
    if [ "$type" = "tree" ]; then
      url="/$erel/tree/$efull"
    else
      url="/$erel/blob/$efull"
    fi
    echo "<li><code>$(html_escape "$type")</code> <a class=\"$type\" href=\"$url\">$ename</a></li>"
  done
  echo "</ul>"
  footer "$rel"
}

render_commit() {
  local rel=$1 dir=$2 hash=$3
  local line cls
  send_header
  page_head
  echo "<h1><a href=\"/$(html_escape "$rel")\">$(html_escape "$rel")</a> — commit $(html_escape "$hash")</h1>"
  echo "<div class=\"diff\">"
  $GIT_BIN -C "$dir" show --no-color \
    --format='commit %H%nAuthor: %an <%ae>%nDate:   %ad%n%n    %s%n%n%b' \
    "$hash" -- 2>/dev/null \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' \
    | while IFS= read -r line; do
        cls=""
        case "$line" in
          '+++'*|'---'*)       cls="meta" ;;
          '@@'*)               cls="hunk" ;;
          'diff '*|'index '*)  cls="meta" ;;
          '+'*)                cls="add"  ;;
          '-'*)                cls="del"  ;;
        esac
        if [ -n "$cls" ]; then
          echo "<span class=\"$cls\">$line</span>"
        else
          echo "$line"
        fi
      done
  echo "</div>"
  footer "$rel"
}

route() {
  if [ ${#page} -eq 0 ]; then
    render_index
    return
  fi

  local seg
  for seg in "$page[@]"; do
    case "$seg" in
      *..*) render_404; return ;;
    esac
  done

  local i rel="" repo_rel="" split=0
  for (( i = 1; i <= ${#page}; i++ )); do
    if [ -z "$rel" ]; then rel="$page[i]"; else rel="$rel/$page[i]"; fi
    if is_git_repo "$GIT_REPOS_PATH/$rel"; then
      repo_rel="$rel"
      split=$i
    fi
  done

  if [ -z "$repo_rel" ]; then
    render_404
    return
  fi

  local action=(${page[$((split+1)),-1]})
  local dir="$GIT_REPOS_PATH/$repo_rel"

  case "$action[1]" in
    ""|summary) render_repo    "$repo_rel" "$dir" ;;
    commits)    render_commits "$repo_rel" "$dir" ;;
    tree)       render_tree    "$repo_rel" "$dir" "${(j:/:)action[2,-1]}" ;;
    blob)       render_blob    "$repo_rel" "$dir" "${(j:/:)action[2,-1]}" ;;
    raw)        render_raw     "$repo_rel" "$dir" "${(j:/:)action[2,-1]}" ;;
    download)   render_download "$repo_rel" "$dir" "${(j:/:)action[2,-1]}" ;;
    commit)     render_commit  "$repo_rel" "$dir" "$action[2]" ;;
    *)          render_404 ;;
  esac
}

main() {
  mkdir -p "$GIT_REPOS_PATH"
  route
}

main b/test2/test
