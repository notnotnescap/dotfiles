#! /bin/zsh

# General Settings
setopt auto_cd # automatically cd into directories
setopt auto_pushd # automatically push directories onto the stack
setopt prompt_subst # enable prompt substitution
setopt histignorealldups # ignore duplicate commands in history

export MANPAGER="nvim +Man!"
HISTSIZE=15000  # keep at most 15k commands in memory
SAVEHIST=10000  # keep at most 10k commands in HISTFILE
HISTFILE=~/.zsh_history
CODESTATS_ENABLED=1

# Keybinds
bindkey '^[[1;5C' forward-word # Ctrl + Right Arrow
bindkey '^[[1;5D' backward-word # Ctrl + Left Arrow

# Loading zsh theme
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

PROMPT="%(?:%{$fg_bold[green]%}%1{$%} :%{$fg_bold[red]%}%1{$%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# fzf theme
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#313244,label:#CDD6F4"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind 'ctrl-t:toggle-preview,ctrl-y:execute-silent(echo -n {} | pbcopy)'"


# Loading plugins

# zsh-autosuggestions
# install : git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# Syntax highlighting
# install : git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Code::Stats plugin
# install : git clone https://gitlab.com/code-stats/code-stats-zsh.git ~/.zsh/code-stats-zsh
if [ -f "$HOME/.codestats_api_key" ]; then
    export CODESTATS_API_KEY=$(cat $HOME/.codestats_api_key)
    source "${HOME}/.zsh/code-stats-zsh/codestats.plugin.zsh"
fi

# fzf
source <(fzf --zsh)

# General environment variables
export PATH="$HOME/.bun/bin:$PATH" # bun
export PATH="$HOME/.pixi/bin:$PATH" # pixi
source $HOME/.local/bin/env # uv

# directories
export ctfdir="~/CTF"
export devdir="$HOME/dev"
export dotfilesdir="$ghdir/dotfiles"
export ghdir="$HOME/dev/GitHub"
export tmpdir="$HOME/tmp"

alias ctf="cd $ctfdir; pwd"
alias dev="cd $devdir; pwd"
alias dotfiles="cd $dotfilesdir; pwd"
alias gh="cd $ghdir; pwd"
alias tmp="cd $tmpdir; pwd"

# aliases
alias b="btop"
alias c="clear"
alias cf="shuf -i 0-1 -n 1" # coin flip
alias cwd="pwd | tr -d '\n' | pbcopy; pwd"
alias e="eza -a --icons --group-directories-first"
alias ea="eza -la --icons --group-directories-first"
alias et="eza --tree --icons --level=3"
alias f="fzf -m --height ~100% --border"
alias ff="fzf --style full --preview 'fzf-preview.sh {}' --bind 'focus:transform-header:file --brief {}'"
alias l="e"
alias la="ea"
alias lt="et"
alias lzshrc="ldf zshrc"
alias mkvenv="uv venv && source .venv/bin/activate"
alias ncdu="ncdu --color dark"
alias nf="neofetch"
alias of="onefetch"
alias q="qalc -i"
alias q10="qalc -i -p 10"
alias q16="qalc -i -p 16"
alias q2="qalc -i -p 2"
alias sc="cd ~; clear"
alias venv="source .venv/bin/activate || source venv/bin/activate"
alias ytdl='yt-dlp -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]"'
alias ytdla="yt-dlp -x --audio-format mp3 --audio-quality 0"
alias zshrc="source ~/.zshrc"

# git aliases
alias g='git'
alias ga='git add'
alias gaa='git add --all --verbose'
alias gap='git add --patch'
alias gba='git branch --all'
alias gbD='git branch --delete --force'
alias gbd='git branch --delete'
alias gc='git commit -S'
alias gca='git commit -S -a'
alias gch='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate --all'
alias gla='git log --graph --decorate --all --stat'
alias gll='git log --oneline --graph --decorate --all --stat'
alias gph='git push'
alias gpl='git pull'
alias grs='git restore --staged'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'

# macos specific
if [[ "$(uname)" == "Darwin" ]]; then
    alias o="open ."
    alias caf="caffeinate -d"

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

# pull dotfiles from the github repo
pulldf() {
    if [ -z "$1" ]; then
        echo "Usage: pulldf <file>
        Pull any of these files from the repo:
        - zshrc
        - clang-format cf
        - gitignore gi
        - gitconfig gc"
        return 1
    fi

    if [ "$1" = "zshrc" ]; then
        echo "Pulling .zshrc at $HOME/.zshrc"
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
        echo "Pulling .gitconfig at $HOME/.gitconfig"
        curl -H 'Cache-Control: no-cache' -f -o ~/.gitconfig https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.gitconfig || echo 'Failed to pull .zshrc'
        echo "Pulling .gitconfig-github at $HOME/.gitconfig-github..."
        curl -H 'Cache-Control: no-cache' -f -o ~/.gitconfig-github https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.gitconfig-github || echo 'Failed to pull .gitconfig-github'
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

# copies certain files from the local dotfiles repo
ldf() {
    if [ -z "$1" ]; then
        echo "Usage: getdf <file>
        Get any of these files from the repo:
        - zshrc
        - clang-format cf
        - gitignore gi
        - gitconfig gc"
        - kittyconfig kc
        return 1
    fi

    if [ "$1" = "zshrc" ]; then
        echo "Copying .zshrc to $HOME/.zshrc"
        cp $dotfilesdir/.zshrc $HOME/.zshrc || echo 'Failed to copy .zshrc'
        echo "Running zshrc..."
        source $HOME/.zshrc
        echo "Done"
    fi

    if [ "$1" = "clang-format" ] || [ "$1" = "cf" ]; then
        cp $dotfilesdir/.clang-format . || echo 'Failed to copy .clang-format'
        echo "Done"
    fi

    if [ "$1" = "gitignore" ] || [ "$1" = "gi" ]; then
        cp $dotfilesdir/.gitignore . || echo 'Failed to copy .gitignore'
        echo "Done"
    fi

    if [ "$1" = "gitconfig" ]; then
        echo "Copying .gitconfig to $HOME/.gitconfig"
        cp $dotfilesdir/.gitconfig $HOME/.gitconfig || echo 'Failed to copy .gitconfig'
        echo "Copying .gitconfig-github to $HOME/.gitconfig-github..."
        cp $dotfilesdir/.gitconfig-github $HOME/.gitconfig-github || echo 'Failed to copy .gitconfig-github'
        echo "Done"
    fi

    if [ "$1" = "batconfig" ]; then
        echo "Copying .config/bat/* to $HOME/.config/bat/..."
        mkdir -p ~/.config/bat/themes
        cp $dotfilesdir/.config/bat/config ~/.config/bat/config || echo 'Failed to copy .config/bat/config'
        cp $dotfilesdir/.config/bat/themes/Catppuccin\ Mocha.tmTheme ~/.config/bat/themes/Catppuccin\ Mocha.tmTheme || echo 'Failed to copy .config/bat/themes/Catppuccin Mocha.tmTheme'
        bat cache --build
        echo "Done"
    fi

    if [ "$1" = "kittyconfig" ] || [ "$1" = "kc" ]; then
        echo "Copying kitty config to $HOME/.config/kitty/kitty.conf"
        mkdir -p $HOME/.config/kitty
        cp $dotfilesdir/.config/kitty/kitty.conf $HOME/.config/kitty/kitty.conf || echo 'Failed to copy kitty config'
        echo "Done"
    fi
}

codestats() {
    if [ -z "$1" ]; then
        echo "Usage: codestats <on|off|status>"
        return 1
    fi
    if [ "$1" = "on" ]; then
        echo "Code::Stats plugin enabled"
        export CODESTATS_ENABLED=1
        export CODESTATS_API_KEY=$(cat $HOME/.codestats_api_key)
    elif [ "$1" = "off" ]; then
        echo "Code::Stats plugin disabled"
        export CODESTATS_ENABLED=0
        export CODESTATS_API_KEY=""
    elif [ "$1" = "status" ]; then
        if [ "$CODESTATS_ENABLED" = "1" ]; then
            echo "Code::Stats plugin is enabled"
        else
            echo "Code::Stats plugin is disabled"
        fi
    else
        echo "Usage: codestats <on|off|status>"
    fi
}

# cd to selected directory from fzf
fd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf +m --height ~100% --border) &&
  cd "$dir"
}

# make a dir and move into it in one command
mkcd() {
    local dir_name="$1"
    if [ -z "$dir_name" ]; then
        # no args is a quick way to create a temporary directory
        local count
        count=$(find . -maxdepth 1 -type d -name "tmp-*" 2>/dev/null | wc -l | tr -d '[:space:]')
        dir_name="tmp-${count:-0}"
    fi

    # prevent accidental removal of existing directories
    if [ -e "$dir_name" ] && [ ! -d "$dir_name" ]; then
        echo "mkcd: error: '$dir_name' exists but is not a directory." >&2
        return 1
    fi

    mkdir -p -- "$dir_name" || {
        echo "mkcd: error: failed to create directory '$dir_name'." >&2
        return 1
    }
    cd -- "$dir_name" || {
        echo "mkcd: error: failed to change to directory '$dir_name'." >&2
        return 1
    }
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

chx() {
    sudo chmod +x $1
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
