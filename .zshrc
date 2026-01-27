#! /bin/zsh

# Migrate old .zshrc_local to .zshrc.local if it exists (temporary)
if [ -f "$HOME/.zshrc_local" ]; then
    mv "$HOME/.zshrc_local" "$HOME/.zshrc.local"
    echo "Renamed $HOME/.zshrc_local to $HOME/.zshrc.local"
fi

# Load local zshrc, if the file exists
if [ -f "$HOME/.zshrc.local" ]; then
    source "$HOME/.zshrc.local"
fi

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

ZSH_THEME_GIT_PROMPT_PREFIX=" ("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# if there isn't a TAG environment variable define one
if [ -z "$TAG" ]; then
    export TAG="$"
fi

PROMPT="%(?:%{$fg_bold[green]%} ${TAG} :%{$fg_bold[red]%} ${TAG} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%} (%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%})%{$fg[yellow]%}%1{•%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# fzf theme
if command -v fzf > /dev/null; then
    export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
    --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
    --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
    --color=selected-bg:#45475A \
    --color=border:#313244,label:#CDD6F4"
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind 'ctrl-t:toggle-preview,ctrl-y:execute-silent(echo -n {} | pbcopy)'"
    source <(fzf --zsh)
fi

# Tab Completions
autoload -U compinit
compinit

# atuin
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# rbenv
if command -v rbenv &> /dev/null; then
    eval "$(rbenv init -)"
fi

# Loading plugins

# zsh-autosuggestions
# install : git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# zsh-syntax-highlighting
# install : git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Code::Stats plugin
# install : git clone https://gitlab.com/code-stats/code-stats-zsh.git ~/.zsh/code-stats-zsh

# Migrate CODESTATS_API_KEY from old file (temporary)
if [ -f "$HOME/.codestats_api_key" ]; then
    read -r "a?$HOME/.codestats_api_key file detected. Migrate to local zshrc? [y/n] "
    if [[ "$a" =~ ^[Yy]$ ]]; then
        echo "export CODESTATS_API_KEY=\"$(cat $HOME/.codestats_api_key | tr -d '\n')\"\n" >> $HOME/.zshrc.local
        rm $HOME/.codestats_api_key
        source $HOME/.zshrc
        echo "Migrated CODESTATS_API_KEY to local zshrc."
    fi
fi

if [ -n "$CODESTATS_API_KEY" ]; then
    source "${HOME}/.zsh/code-stats-zsh/codestats.plugin.zsh"
fi

# General environment variables
export PATH="$HOME/.bun/bin:$PATH" # bun
export PATH="$HOME/.pixi/bin:$PATH" # pixi
if [ -f $HOME/.local/bin/env ]; then
    source $HOME/.local/bin/env # uv
fi

# directories
export devdir="$HOME/dev"
export tmpdir="$HOME/tmp"
export ghdir="$HOME/dev/GitHub"
export dotfilesdir="$ghdir/dotfiles"
if [ -z "$ctfdir" ]; then
    # only define ctfdir if it is not already set by local zshrc
    export ctfdir="$HOME/CTF"
fi

alias ctf="cd $ctfdir; pwd"
alias dev="cd $devdir; pwd"
alias dotfiles="cd $dotfilesdir; pwd"
alias gh="cd $ghdir; pwd"
alias tmp="cd $tmpdir; pwd"

# aliases
alias b="btop" # is this too lazy?
alias c="clear"
alias cf="shuf -i 0-1 -n 1" # coin flip
alias cwd="pwd | tr -d '\n' | pbcopy; pwd"
alias d="date -u +%Y-%m-%d\ %H:%M:%S"
alias e="eza -a --icons --group-directories-first"
alias ea="eza -la --icons --group-directories-first"
alias et="eza --tree --icons --level=3"
alias f="fzf -m --height ~100% --border"
alias ff="fastfetch"
alias l="e"
alias la="ea"
alias lt="et"
alias lzshrc="ldf zshrc"
alias mip="curl https://am.i.mullvad.net/connected"
alias mkvenv="uv venv && source .venv/bin/activate"
alias ncdu="ncdu --color dark"
alias of="onefetch"
alias pf="fzf --style full --preview 'fzf-preview.sh {}' --bind 'focus:transform-header:file --brief {}'"
alias q="qalc -i"
alias q10="qalc -i -p 10"
alias q16="qalc -i -p 16"
alias q2="qalc -i -p 2"
alias sc="cd ~; clear"
alias venv="source .venv/bin/activate || source venv/bin/activate"
alias ytdl='yt-dlp -f "bv*[vcodec^=avc1][ext=mp4]+ba[ext=m4a]/b[vcodec^=avc1][ext=mp4]"'
alias ytdla="yt-dlp -x --audio-format mp3 --audio-quality 0"
alias zshrc="source ~/.zshrc"
# if the 'nf' alias is not defined, define it
if ! alias nf &> /dev/null; then
    alias nf="neofetch"
fi

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

    stat() {
        command stat -x "$@"
    }
fi

# linux specific
if [[ "$(uname)" == "Linux" ]]; then
    alias pbcopy="xclip -selection clipboard"
    alias trash="gio trash"
fi

# custom functions

# pull dotfiles from the github repo
pulldf() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: pulldf <file>
        Pull any of these files from the repo:
        - zshrc (z)
        - clang-format (cf)
        - gitignore (gi)
        - gitconfig (gc)
        - kittyconfig (kc)
        - ruff
        - batconfig
        - atuin"
        return 1
    fi

    # if file starts with a dot, remove it
    if [[ "$file" == .* ]]; then
        file="${file#.}"
    fi

    local repo_url="https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main"

    case "$file" in
        zshrc|z)
            echo "Pulling .zshrc at $HOME/.zshrc"
            curl -H 'Cache-Control: no-cache' -f -o ~/.zshrc "$repo_url/.zshrc" || echo 'Failed to pull .zshrc'
            echo "Running zshrc..."
            source ~/.zshrc
            ;;
        clang-format|cf)
            curl -H 'Cache-Control: no-cache' -f -o .clang-format "$repo_url/.clang-format" || echo 'Failed to clone .clang-format'
            ;;
        gitignore|gi)
            curl -H 'Cache-Control: no-cache' -f -o .gitignore "$repo_url/.gitignore" || echo 'Failed to clone .gitignore'
            ;;
        gitconfig|gc)
            echo "Pulling .gitconfig at $HOME/.gitconfig"
            curl -H 'Cache-Control: no-cache' -f -o ~/.gitconfig "$repo_url/.gitconfig" || echo 'Failed to pull .gitconfig'
            echo "Pulling .gitconfig-github at $HOME/.gitconfig-github..."
            curl -H 'Cache-Control: no-cache' -f -o ~/.gitconfig-github "$repo_url/.gitconfig-github" || echo 'Failed to pull .gitconfig-github'
            ;;
        kittyconfig|kc)
            echo "Pulling kitty config at $HOME/.config/kitty/kitty.conf"
            mkdir -p $HOME/.config/kitty
            curl -H 'Cache-Control: no-cache' -f -o $HOME/.config/kitty/kitty.conf "$repo_url/.config/kitty/kitty.conf" || echo 'Failed to pull kitty config'
            ;;
        ruff)
            echo "Pulling ruff.toml at $HOME/.config/ruff/ruff.toml..."
            mkdir -p $HOME/.config/ruff
            curl -H 'Cache-Control: no-cache' -f -o $HOME/.config/ruff/ruff.toml "$repo_url/.config/ruff/ruff.toml" || echo 'Failed to pull ruff.toml'
            ;;
        batconfig)
            echo "Pulling .config/bat/* at $HOME/.config/bat/..."
            mkdir -p ~/.config/bat/themes
            curl -H 'Cache-Control: no-cache' -f -o ~/.config/bat/config "$repo_url/.config/bat/config" || echo 'Failed to pull .config/bat/'
            curl -H 'Cache-Control: no-cache' -f -o ~/.config/bat/themes/Catppuccin\ Mocha.tmTheme "$repo_url/.config/bat/themes/Catppuccin%20Mocha.tmTheme" || echo 'Failed to pull .config/bat/themes/Catppuccin Mocha.tmTheme'
            bat cache --build
            ;;
        atuin)
            echo "Pulling atuin config at $HOME/.config/atuin/config.toml..."
            mkdir -p $HOME/.config/atuin
            curl -H 'Cache-Control: no-cache' -f -o $HOME/.config/atuin/config.toml "$repo_url/.config/atuin/config.toml" || echo 'Failed to pull atuin config'
            ;;
        *)
            echo "Error: Unknown file '$file'"
            return 1
            ;;
    esac

    echo "Done"
}

_pulldf_completion() {
    local -a options
    options=(
        'zshrc'
        'z'
        'clang-format'
        'cf'
        'gitignore'
        'gi'
        'gitconfig'
        'gc'
        'kittyconfig'
        'kc'
        'ruff'
        'batconfig'
        'atuin'
    )
    _describe 'pulldf options' options
}

compdef _pulldf_completion pulldf

# copies certain files from the local dotfiles repo
ldf() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: ldf <file>
        Get any of these files from the repo:
        - zshrc (z)
        - clang-format (cf)
        - gitignore (gi)
        - gitconfig (gc)
        - kittyconfig (kc)
        - ruff
        - batconfig
        - atuin"
        return 1
    fi

    # check if the local dotfiles directory exists and is not empty
    if [ ! -d "$dotfilesdir" ] || [ -z "$(ls -A "$dotfilesdir")" ]; then
        echo "Error: Local dotfiles directory '$dotfilesdir' does not exist or is empty."
        return 1
    fi

    # if file starts with a dot, remove it
    if [[ "$file" == .* ]]; then
        file="${file#.}"
    fi

    case "$file" in
        zshrc|z)
            echo "Copying .zshrc to $HOME/.zshrc"
            cp "$dotfilesdir/.zshrc" "$HOME/.zshrc" || echo 'Failed to copy .zshrc'
            echo "Running zshrc..."
            source "$HOME/.zshrc"
            ;;
        clang-format|cf)
            cp "$dotfilesdir/.clang-format" . || echo 'Failed to copy .clang-format'
            ;;
        gitignore|gi)
            cp "$dotfilesdir/.gitignore" . || echo 'Failed to copy .gitignore'
            ;;
        gitconfig|gc)
            echo "Copying .gitconfig to $HOME/.gitconfig"
            cp "$dotfilesdir/.gitconfig" "$HOME/.gitconfig" || echo 'Failed to copy .gitconfig'
            echo "Copying .gitconfig-github to $HOME/.gitconfig-github..."
            cp "$dotfilesdir/.gitconfig-github" "$HOME/.gitconfig-github" || echo 'Failed to copy .gitconfig-github'
            ;;
        batconfig)
            echo "Copying .config/bat/* to $HOME/.config/bat/..."
            mkdir -p ~/.config/bat/themes
            cp "$dotfilesdir/.config/bat/config" ~/.config/bat/config || echo 'Failed to copy .config/bat/config'
            cp "$dotfilesdir/.config/bat/themes/Catppuccin Mocha.tmTheme" ~/.config/bat/themes/Catppuccin\ Mocha.tmTheme || echo 'Failed to copy .config/bat/themes/Catppuccin Mocha.tmTheme'
            bat cache --build
            ;;
        kittyconfig|kc)
            echo "Copying kitty config to $HOME/.config/kitty/kitty.conf"
            mkdir -p "$HOME/.config/kitty"
            cp "$dotfilesdir/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" || echo 'Failed to copy kitty config'
            ;;
        ruff)
            echo "Copying ruff.toml to $HOME/.config/ruff/ruff.toml"
            mkdir -p "$HOME/.config/ruff"
            cp "$dotfilesdir/.config/ruff/ruff.toml" "$HOME/.config/ruff/ruff.toml" || echo 'Failed to copy ruff.toml'
            ;;
        atuin)
            echo "Copying atuin config to $HOME/.config/atuin/config.toml"
            mkdir -p "$HOME/.config/atuin"
            cp "$dotfilesdir/.config/atuin/config.toml" "$HOME/.config/atuin/config.toml" || echo 'Failed to copy atuin config'
            ;;
        *)
            echo "Error: Unknown file '$file'"
            return 1
            ;;
    esac

    echo "Done"
}

_ldf_completion() {
    local -a options
    options=(
        'zshrc'
        'z'
        'clang-format'
        'cf'
        'gitignore'
        'gi'
        'gitconfig'
        'gc'
        'batconfig'
        'kittyconfig'
        'kc'
        'ruff'
        'batconfig'
        'atuin'
    )
    _describe 'ldf options' options
}

compdef _ldf_completion ldf

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

_codestats_completion() {
    local -a options
    options=(
        'on'
        'off'
        'status'
    )
    _describe 'codestats options' options
}

compdef _codestats_completion codestats

# cd to selected directory from fzf
cfd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf +m --height ~100% --border) &&
  cd "$dir"
  pwd
}

# combine all .md files in current directory into one
mdcombine() {
    local output_file="combined.md"
    if [ -f "$output_file" ]; then
        echo "Error: $output_file already exists. Please remove it first."
        return 1
    fi
    for file in *.md; do
        if [ -f "$file" ]; then
            cat "$file" >> "$output_file"
            echo -e "\n\n" >> "$output_file"
        fi
    done
    echo "Combined markdown files into $output_file"
}

# compress video file using ffmpeg
ffcompress() {
    if [ -z "$1" ]; then
        echo "Usage: ffcompress <input_file>"
        return 1
    fi
    local input_file="$1"
    local output_file="${input_file%.*}_compressed.${input_file##*.}"
    # ffmpeg -i "$1" -vcodec libx264 -crf 23 "$2"
    ffmpeg -i "$input_file" -vcodec libx265 -crf 28 -preset fast -acodec aac -b:a 128k "$output_file"
    echo "Compressed $input_file to $output_file"
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
    read -r "a?Remove $current_dir ? [y/n] "
    if [[ "$a" =~ ^[Yy]$ ]]
    then
        cd ..
        if command -v trash > /dev/null 2>&1; then
            trash "$current_dir"
        else
            read -r "b?'trash' command not found. Use 'rm -rf' instead? [y/n] "
            if [[ "$b" =~ ^[Yy]$ ]]; then
                rm -rf "$current_dir"
            else
                echo "Aborted."
            fi
        fi
    fi
}

# randomly choose one of the arguments
# example: pick javascript "social life and friends"
pick() {
    echo "Hmm..."
    sleep 2.1
    local choice=${@:$(shuf -i 1-$# -n 1):1}
    echo "> $choice"
}

chx() {
    sudo chmod +x $1
}

uzip() {
    unzip $@
}

# Load thefuck if it is installed
if command -v thefuck &> /dev/null; then
    eval "$(thefuck --alias)"
fi

# Load zoxide if it is installed
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi
