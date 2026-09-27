[ -r /usr/share/omarchy/default/bash/env-bootstrap ] && . /usr/share/omarchy/default/bash/env-bootstrap
: "${OMARCHY_PATH:=/usr/share/omarchy}"
[ -d "$OMARCHY_PATH/default/bash" ] || return 0

_omarchy_bash="$OMARCHY_PATH/default/bash"

. "$_omarchy_bash/envs"

unalias ga gd gcm gcam open n 2>/dev/null
. "$_omarchy_bash/aliases"

() {
  local file line name
  local -a skip=(ga gd)
  for file in "$_omarchy_bash"/fns/*(N); do
    for line in "${(@f)$(<$file)}"; do
      [[ $line =~ '^([A-Za-z0-9][A-Za-z0-9_-]*)\(\) *[{(]' ]] || continue
      name=$match[1]
      (( ${skip[(Ie)$name]} )) && continue
      unalias "$name" 2>/dev/null
      eval "$name() { bash -c 'source \"\$0\"; $name \"\$@\"' ${(q)file} \"\$@\"; }"
    done
  done
}

ga() {
  [[ -z $1 ]] && { echo "Usage: ga [branch name]"; return 1; }
  local branch=$1 base=${PWD:t}
  local wt_path="../${base}--${branch}"
  git worktree add -b "$branch" "$wt_path" || return
  mise trust "$wt_path"
  cd "$wt_path"
}

gd() {
  gum confirm "Remove worktree and branch?" || return
  local cwd=$PWD worktree=${PWD:t}
  local root=${worktree%%--*} branch=${worktree#*--}
  if [[ $root != "$worktree" ]]; then
    cd "../$root"
    git worktree remove "$cwd" --force || return 1
    git branch -D "$branch"
  fi
}

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v try >/dev/null && try() {
  unfunction try
  eval "$(SHELL=${commands[zsh]} command try init ~/Work/tries)"
  try "$@"
}

_omarchy() {
  local bin=${${commands[omarchy]:A}:h} prefix=omarchy word file
  local -a next
  for word in ${words[2,CURRENT-1]}; do
    [[ $word == -* ]] || prefix+="-$word"
  done
  for file in $bin/$prefix-*(N-*); do
    next+=(${${file:t}#$prefix-})
  done
  next=(${(u)next%%-*})
  (( CURRENT == 2 )) && next+=(commands)
  (( $#next )) && compadd -a next || _files
}
(( $+functions[compdef] )) && compdef _omarchy omarchy

unset _omarchy_bash
