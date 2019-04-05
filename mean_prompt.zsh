# mean prompt theme
# by Bryan Gilbert: https://github.com/gilbertw1/mean
#
# Based on Lean by Miek Gieben: https://github.com/miekg/lean
#   Based on Pure by Sindre Sorhus: https://github.com/sindresorhus/pure
#
# MIT License

PROMPT_MEAN_TMUX=${PROMPT_MEAN_TMUX-"t"}

MEAN_ARROW_ONE_COLOR=${MEAN_ARROW_ONE_COLOR-"12"}
MEAN_ARROW_TWO_COLOR=${MEAN_ARROW_TWO_COLOR-"5"}
MEAN_ARROW_THREE_COLOR=${MEAN_ARROW_THREE_COLOR-"10"}
MEAN_ARROW_ERR_COLOR=${MEAN_ARROW_ERR_COLOR-"red"}
MEAN_TMUX_COLOR=${MEAN_TMUX_COLOR-"11"}
MEAN_PATH_COLOR=${MEAN_PATH_COLOR-"blue"}
MEAN_VCS_BRANCH_COLOR=${MEAN_VCS_BRANCH_COLOR-"2"}
MEAN_VCS_DIRTY_COLOR=${MEAN_VCS_DIRTY_COLOR-"5"}
MEAN_LAMBDA_COLOR=${MEAN_LAMBDA_COLOR-"12"}
MEAN_HOST_COLOR=${MEAN_HOST_COLOR-"11"}

# turns seconds into human readable time, 165392 => 1d 21h 56m 32s
prompt_mean_human_time() {
    local tmp=$1
    local days=$(( tmp / 60 / 60 / 24 ))
    local hours=$(( tmp / 60 / 60 % 24 ))
    local minutes=$(( tmp / 60 % 60 ))
    local seconds=$(( tmp % 60 ))
    (( $days > 0 )) && echo -n "${days}d "
    (( $hours > 0 )) && echo -n "${hours}h "
    (( $minutes > 0 )) && echo -n "${minutes}m "
    echo "${seconds}s "
}

# fastest possible way to check if repo is dirty
prompt_mean_git_dirty() {
    # check if we're in a git repo
    command git rev-parse --verify HEAD &>/dev/null || return

    git diff-files --no-ext-diff --quiet &>/dev/null && git diff-index --no-ext-diff --quiet --cached HEAD &>/dev/null
    (($? != 0)) && echo '✱'
}

# displays the exec time of the last command if set threshold was exceeded
prompt_mean_cmd_exec_time() {
    local stop=$EPOCHSECONDS
    local start=${cmd_timestamp:-$stop}
    integer elapsed=$stop-$start
    (($elapsed > ${PROMPT_LEAN_CMD_MAX_EXEC_TIME:=5})) && prompt_mean_human_time $elapsed
}

prompt_mean_preexec() {
    cmd_timestamp=$EPOCHSECONDS

    # shows the current dir and executed command in the title when a process is active
    print -Pn "\e]0;"
    echo -nE "$PWD:t: $2"
    print -Pn "\a"
}

prompt_short_pwd() {

  local short full part cur
  local first
  local -a split    # the array we loop over

  split=(${(s:/:)${(Q)${(D)1:-$PWD}}})

  if [[ $split == "" ]]; then
    print "/"
    return 0
  fi

  if [[ $split[1] = \~* ]]; then
    first=$split[1]
    full=$~split[1]
    shift split
  fi

  if (( $#split > 0 )); then
    part=/
fi

for cur ($split[1,-2]) {
  while {
           part+=$cur[1]
           cur=$cur[2,-1]
           local -a glob
           glob=( $full/$part*(-/N) )
           # continue adding if more than one directory matches or
           # the current string is . or ..
           # but stop if there are no more characters to add
           (( $#glob > 1 )) || [[ $part == (.|..) ]] && (( $#cur > 0 ))
        } { # this is a do-while loop
  }
  full+=$part$cur
  short+=$part
  part=/
}
  print "$first$short$part$split[-1]"
  return 0
}

function prompt_mean_insert_mode () { echo "-- INSERT --" }
function prompt_mean_normal_mode () { echo "-- NORMAL --" }

prompt_mean_precmd() {
    rehash

    local jobs
    local prompt_mean_jobs
    unset jobs
    for a (${(k)jobstates}) {
        j=$jobstates[$a];i="${${(@s,:,)j}[2]}"
        jobs+=($a${i//[^+-]/})
    }
    # print with [ ] and comma separated
    prompt_mean_jobs=""
    [[ -n $jobs ]] && prompt_mean_jobs="%F{242}["${(j:,:)jobs}"] "

    vcsinfo="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [[ !  -z  $vcsinfo  ]] then
        #vcsinfo="%F{$MEAN_VCS_BRANCH_COLOR}$vcsinfo%F{$MEAN_VCS_DIRTY_COLOR}`prompt_mean_git_dirty` "
       vcsinfo="%F{$MEAN_VCS_BRANCH_COLOR}$vcsinfo "
    else
        vcsinfo=" "
    fi

    case ${KEYMAP} in
      (vicmd)
        VI_MODE="%F{blue}$(prompt_mean_normal_mode)"
        printf "\e[3 q"
        ;;
      (main|viins)
        VI_MODE="%F{2}$(prompt_mean_insert_mode)"
        printf "\e[1 q"
        ;;
      (*)
        VI_MODE="%F{2}$(prompt_mean_insert_mode)"
        printf "\e[1 q"
        ;;
    esac

    PROMPT="$prompt_mean_jobs%F{$MEAN_TMUX_COLOR}$prompt_mean_tmux `prompt_mean_cmd_exec_time`%f%F{$MEAN_PATH_COLOR}`prompt_short_pwd` %(?.%F{$MEAN_ARROW_ONE_COLOR}.%B%F{$MEAN_ARROW_ERR_COLOR})❯%(?.%F{$MEAN_ARROW_TWO_COLOR}.%B%F{$MEAN_ARROW_ERR_COLOR})❯%(?.%F{$MEAN_ARROW_THREE_COLOR}.%B%F{$MEAN_ARROW_ERR_COLOR})❯%f%b "
    RPROMPT="$vcsinfo%F{$MEAN_LAMBDA_COLOR}λ$prompt_mean_host%f"

    unset cmd_timestamp # reset value since `preexec` isn't always triggered
}

prompt_mean_setup() {
    prompt_opts=(cr subst percent)

    zmodload zsh/datetime
    autoload -Uz add-zsh-hook

    add-zsh-hook precmd prompt_mean_precmd
    add-zsh-hook preexec prompt_mean_preexec

    prompt_mean_host=" %F{11}%m%f"
    if [[ "$TMUX" != '' ]]; then
      prompt_mean_tmux=$PROMPT_MEAN_TMUX
    fi
}

function zle-line-init zle-keymap-select {
    prompt_mean_precmd
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select

prompt_mean_setup "$@"
