#! /bin/zsh

# zsh settings
setopt auto_cd # automatically cd into directories
setopt auto_pushd # automatically push directories onto the stack
setopt prompt_subst # enable prompt substitution

# Load zsh theme

zmodload zsh/system
autoload -Uz is-at-least

function _register_handler {
  setopt localoptions noksharrays
  typeset -ga _async_functions
  if [[ -z "$1" ]] || (( ! ${+functions[$1]} )) || (( ${_async_functions[(Ie)$1]} )); then
    return
  fi
  _async_functions+=("$1")
  if (( ! ${precmd_functions[(Ie)_async_request]} )) && (( ${+functions[_async_request]})); then
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _async_request
  fi
}

function _async_request {
  local -i ret=$?
  typeset -gA _ASYNC_FDS _ASYNC_PIDS _ASYNC_OUTPUT
  local handler
  for handler in ${_async_functions}; do
    (( ${+functions[$handler]} )) || continue
    local fd=${_ASYNC_FDS[$handler]:--1}
    local pid=${_ASYNC_PIDS[$handler]:--1}
    if (( fd != -1 && pid != -1 )) && { true <&$fd } 2>/dev/null; then
      exec {fd}<&-
      zle -F $fd
      if [[ -o MONITOR ]]; then
        kill -TERM -$pid 2>/dev/null
      else
        kill -TERM $pid 2>/dev/null
      fi
    fi
    _ASYNC_FDS[$handler]=-1
    _ASYNC_PIDS[$handler]=-1
    exec {fd}< <(
      builtin echo ${sysparams[pid]}
      () { return $ret }
      $handler
    )
    _ASYNC_FDS[$handler]=$fd
    is-at-least 5.8 || command true
    read -u $fd "_ASYNC_PIDS[$handler]"
    zle -F "$fd" _async_callback
  done
}

function _async_callback() {
  emulate -L zsh
  local fd=$1
  local err=$2
  if [[ -z "$err" || "$err" == "hup" ]]; then
    local handler="${(k)_ASYNC_FDS[(r)$fd]}"
    local old_output="${_ASYNC_OUTPUT[$handler]}"
    IFS= read -r -u $fd -d '' "_ASYNC_OUTPUT[$handler]"
    if [[ "$old_output" != "${_ASYNC_OUTPUT[$handler]}" ]]; then
      zle .reset-prompt
      zle -R
    fi
    exec {fd}<&-
  fi
  zle -F "$fd"
  _ASYNC_FDS[$handler]=-1
  _ASYNC_PIDS[$handler]=-1
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _async_request

function __git_prompt_git() {
  GIT_OPTIONAL_LOCKS=0 command git "$@"
}

function _git_prompt_info() {
  if ! __git_prompt_git rev-parse --git-dir &> /dev/null || [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
    return 0
  fi
  local ref
  ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null) || ref=$(__git_prompt_git describe --tags --exact-match HEAD 2> /dev/null) || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) || return 0
  local upstream
  if (( ${+ZSH_THEME_GIT_SHOW_UPSTREAM} )); then
    upstream=$(__git_prompt_git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null) && upstream=" -> ${upstream}"
  fi
  echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref:gs/%/%%}${upstream:gs/%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}

function git_prompt_info() {
  if [[ -n "${_ASYNC_OUTPUT[_git_prompt_info]}" ]]; then
    echo -n "${_ASYNC_OUTPUT[_git_prompt_info]}"
  fi
}

function git_prompt_status() {
  if [[ -n "${_ASYNC_OUTPUT[_git_prompt_status]}" ]]; then
    echo -n "${_ASYNC_OUTPUT[_git_prompt_status]}"
  fi
}

function _defer_async_git_register() {
  case "${PS1}:${PS2}:${PS3}:${PS4}:${RPROMPT}:${RPS1}:${RPS2}:${RPS3}:${RPS4}" in
  *(\$\(git_prompt_info\)|\`git_prompt_info\`)*)
    _register_handler _git_prompt_info
    ;;
  esac
  case "${PS1}:${PS2}:${PS3}:${PS4}:${RPROMPT}:${RPS1}:${RPS2}:${RPS3}:${RPS4}" in
  *(\$\(git_prompt_status\)|\`git_prompt_status\`)*)
    _register_handler _git_prompt_status
    ;;
  esac
  add-zsh-hook -d precmd _defer_async_git_register
  unset -f _defer_async_git_register
}

precmd_functions=(_defer_async_git_register $precmd_functions)

function parse_git_dirty() {
  local STATUS
  local -a FLAGS
  FLAGS=('--porcelain')
  if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-dirty)" != "1" ]]; then
    if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]; then
      FLAGS+='--untracked-files=no'
    fi
    case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
      git)
        ;;
      *)
        FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"
        ;;
    esac
    STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1)
  fi
  if [[ -n $STATUS ]]; then
    echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
  else
    echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
  fi
}

autoload -U colors && colors

ZSH_THEME_GIT_PROMPT_PREFIX="git:("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=""

PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Loading plugins

# install : git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# install : git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# Code::Stats
# Load Code::Stats API key from a separate file
if [ "$VS_CODE_TERMINAL" = "true" ]; then
    echo "\033[0;33mVS Code terminal detected, Code::Stats plugin rejected\033[0m"
else
    if [ -f "$HOME/.codestats_api_key" ]; then
        export CODESTATS_API_KEY=$(cat $HOME/.codestats_api_key)
        # local Code::Stats plugin
        # install : git clone https://gitlab.com/code-stats/code-stats-zsh.git ~/.zsh/code-stats-zsh
        source "${HOME}/.zsh/code-stats-zsh/codestats.plugin.zsh"
    fi
fi


# Settings
export MANPAGER="nvim +Man!"
HISTSIZE=15000  # keep at most 15k commands in memory
SAVEHIST=10000  # keep at most 10k commands in HISTFILE
HISTFILE=~/.zsh_history

# Keybinds
bindkey '^[[1;5C' forward-word # Ctrl + Right Arrow
bindkey '^[[1;5D' backward-word # Ctrl + Left Arrow

# directories
export tmpdir="/var/tmp"
export devdir="$HOME/dev"
export ghdir="$HOME/dev/GitHub"
export dotfilesdir="$ghdir/dotfiles"
export ctfdir="~/CTF"

alias tmp="cd $tmpdir; pwd"
alias dev="cd $devdir; pwd"
alias gh="cd $ghdir; pwd"
alias dotfiles="cd $dotfilesdir; pwd"
alias ctf="cd $ctfdir; pwd"

# aliases
alias c="clear"
alias sc="cd ~; clear"
alias ncdu="ncdu --color dark"
alias b="btop"
alias ez="eza -a --icons --group-directories-first"
alias et="eza --tree --icons"
alias e="eza -la --icons --group-directories-first"
alias ls="ez"
alias lt="et"
alias l="e"
alias cf="find . -type f -name '*.[ch]' ! \(-path '*/lib/*' -o -path '*/build/*'\) -exec clang-format --verbose -style=file -i {} \;"
alias zshrc="source ~/.zshrc"
alias testzshrc="cp ./.zshrc ~/.zshrc && source ~/.zshrc"
alias testkitty="cp ./kitty.conf ~/.config/kitty/kitty.conf"
alias mkvenv="python3 -m venv venv && source venv/bin/activate"
alias cwd="pwd | tr -d '\n' | pbcopy; pwd"

# git aliases
alias ggpur='ggu'
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias gamscp='git am --show-current-patch'
alias gams='git am --skip'
alias gap='git apply'
alias gapt='git apply --3way'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsn='git bisect new'
alias gbso='git bisect old'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gbl='git blame -w'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'

# macos specific
if [[ "$(uname)" == "Darwin" ]]; then
    alias o="open ."

    # fix cunit path
    export CPATH=/opt/homebrew/include:$CPATH
    export LIBRARY_PATH=/opt/homebrew/lib:$LIBRARY_PATH
    # fix adb path
    export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"

    # brew uu to update & upgrade faster
    brew() {
        if [ "$1" = "uu" ] || [ "$1" = "uwu" ]; then
            command brew update;
            command brew upgrade;
        else
            command brew "$@"
        fi
    }

    st() {
        command stat -x "$@"
    }
fi

# linux specific
if [[ "$(uname)" == "Linux" ]]; then
    alias pbcopy='xclip -selection clipboard'
    alias st="stat"
fi

# custom functions

# will pull certain files from the dotfiles repo
getmy() {
    if [ -z "$1" ]; then
        echo "Usage: getmy <file>
        Available files:
        - zshrc
        - clang-format cf
        - gitignore gi
        - gitconfig gc"
        return 1
    fi

    if [ "$1" = "zshrc" ]; then
        echo "Pulling .zshrc at $HOME/.zshrc..."
        curl -H 'Cache-Control: no-cache' -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.zshrc || echo 'Failed to pull .zshrc'
        echo "Running zshrc..."
        source ~/.zshrc
        echo "Done"
    fi

    if [ "$1" = "clang-format" ] || [ "$1" = "cf" ]; then
        curl -H 'Cache-Control: no-cache' -f -o .clang-format https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.clang-format || echo 'Failed to clone .clang-format'
        echo "Done"
    fi

    if [ "$1" = "gitignore" ] || [ "$1" = "gi" ]; then
        curl -H 'Cache-Control: no-cache' -f -o .gitignore https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.gitignore || echo 'Failed to clone .gitignore'
        echo "Done"
    fi

    if [ "$1" = "gitconfig" ]; then
        echo "Pulling .gitconfig at $HOME/.gitconfig..."
        curl -H 'Cache-Control: no-cache' -f -o ~/.gitconfig https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.gitconfig || echo 'Failed to pull .zshrc'
        echo "Done"
    fi

    if [ "$1" = "batconfig" ]; then
        echo "Pulling .config/bat/* at $HOME/.config/bat/..."
        mkdir -p ~/.config/bat/themes
        curl -H 'Cache-Control: no-cache' -f -o ~/.config/bat/config https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.config/bat/config || echo 'Failed to pull .config/bat/'
        curl -H 'Cache-Control: no-cache' -f -o ~/.config/bat/themes/Catppuccin\ Mocha.tmTheme https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.config/bat/themes/Catppuccin%20Mocha.tmTheme || echo 'Failed to pull .config/bat/themes/Catppuccin Mocha.tmTheme'
        bat cache --build
        echo "Done"
    fi
}

# make a dir and move into it in one command
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# move out of current dir and remove it with confirmation
rmcd() {
    local current_dir=$(pwd)
    read -r "a? Remove $current_dir ? [y/n] "
    if [[ "$a" =~ ^[Yy]$ ]]
    then
        cd ..
        if command -v trash > /dev/null 2>&1; then
            trash "$current_dir"
        else
            read -r "b? 'trash' command not found. Use 'rm -rf' instead? [y/n] "
            if [[ "$b" =~ ^[Yy]$ ]]; then
                rm -rf "$current_dir"
            else
                echo "Aborted."
            fi
        fi
    fi
}

uzip() {
    unzip $@
}

# Load local aliases (if the file exists)
if [ -f "$HOME/.zshrc_local" ]; then
    source "$HOME/.zshrc_local"
fi

# Load thefuck
eval $(thefuck --alias)

# Load zoxide
eval "$(zoxide init zsh)"
