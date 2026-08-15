#! /bin/zsh

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
SAVEHIST=15000  # keep at most 15k commands in HISTFILE
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
    [[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"
    eval "$(atuin init zsh)"
fi

# rbenv
if command -v rbenv &> /dev/null; then
    eval "$(rbenv init -)"
fi

# Loading plugins

# zsh-autosuggestions
# install : git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
[[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# zsh-syntax-highlighting
# install : git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
[[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Code::Stats plugin
# install : git clone https://gitlab.com/code-stats/code-stats-zsh.git ~/.zsh/code-stats-zsh

if [ -n "$CODESTATS_API_KEY" ] && [[ -f "${HOME}/.zsh/code-stats-zsh/codestats.plugin.zsh" ]]; then
    source "${HOME}/.zsh/code-stats-zsh/codestats.plugin.zsh"
fi

# General environment variables
export PATH="$HOME/.bun/bin:$PATH" # bun
export PATH="$HOME/.pixi/bin:$PATH" # pixi
if [ -f $HOME/.local/bin/env ]; then
    source $HOME/.local/bin/env # uv
fi

# directories
export devd="$HOME/dev"
export tmpd="$HOME/tmp"
export ghd="$HOME/dev/GitHub"
export dfd="$ghd/dotfiles"
if [ -z "$ctfd" ]; then
    # only define ctfdir if it is not already set by local zshrc
    export ctfd="$HOME/CTF"
fi

alias ctfd="cd $ctfd; pwd"
alias devd="cd $devdir; pwd"
alias dfd="cd $dfd; pwd"
alias ghd="cd $ghd; pwd"
alias tmpd="cd $tmpd; pwd"

# aliases
alias c="clear"
alias cf="shuf -i 0-1 -n 1" # coin flip
alias d="date -u +%Y-%m-%d\ %H:%M:%S"
alias e="eza -a --icons --group-directories-first"
alias ea="eza -la --icons --group-directories-first"
alias et="eza --tree --icons --level=3"
alias f="fzf -m --height ~100% --border"
alias ff="fastfetch"
alias gdfz="gdf z"
alias gdfzr="gdf z -r"
alias gz="gdf zshrc"
alias l="e"
alias la="ea"
alias lt="et"
alias lzshrc="gdf zshrc"
alias mip="curl https://am.i.mullvad.net/connected"
alias mkvenv="uv venv && source .venv/bin/activate"
alias ncdu="ncdu --color dark"
alias of="onefetch"
alias pf="fzf --style full --preview 'fzf-preview.sh {}' --bind 'focus:transform-header:file --brief {}'"
alias pwd="pwd | tr -d '\n' | pbcopy; pwd"
alias q="qalc -i"
alias q10="qalc -i -p 10"
alias q16="qalc -i -p 16"
alias q2="qalc -i -p 2"
alias sc="cd ~; clear"
alias uz="unzip"
alias uuv="uv tool upgrade --all"
alias venv="source .venv/bin/activate || source venv/bin/activate"
alias yda="yt-dlp -x --audio-format mp3 --audio-quality 0"
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
alias gst='git status'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias lzg='lazygit'

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

# get dotfile - copies from local repo (default) or pulls from remote (-r)
# usage: gdf <file> [-r|--remote]
#         gdf gi [type]  — gitignore with optional project type (python, node, rust, go, c, java, latex)
gdf() {
    local remote=0
    local file=""
    local gi_type=""

    # parse args
    for arg in "$@"; do
        case "$arg" in
            -r|--remote) remote=1 ;;
            *)
                if [ -z "$file" ]; then
                    file="$arg"
                else
                    gi_type="$arg"
                fi
                ;;
        esac
    done

    if [ -z "$file" ]; then
        echo "Usage: gdf [-r] <file> [type]
    Get dotfiles from the local repo (default) or remote (-r).
    Files:
        zshrc (z)       clang-format (cf)    gitignore (gi [type])
        gitconfig (gc)  kittyconfig (kc)     ruff
        batconfig       atuin
    Gitignore types: python, node, rust, go, c, java, latex"
        return 1
    fi

    # strip leading dot
    [[ "$file" == .* ]] && file="${file#.}"

    local repo_url="https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main"

    # helper: get a file from local or remote
    _gdf_get() {
        local src="$1" dst="$2"
        if [ "$remote" -eq 1 ]; then
            curl -sS -H 'Cache-Control: no-cache' -f -o "$dst" "$repo_url/$src" || { echo "Failed to pull $src"; return 1; }
        else
            if [ ! -d "$dfd" ] || [ -z "$(ls -A "$dfd")" ]; then
                echo "Error: Local dotfiles directory '$dfd' does not exist or is empty. Use -r to pull from remote."
                return 1
            fi
            cp "$dfd/$src" "$dst" || { echo "Failed to copy $src"; return 1; }
        fi
    }

    case "$file" in
        zshrc|z)
            echo "Getting .zshrc → $HOME/.zshrc"
            _gdf_get ".zshrc" "$HOME/.zshrc" && { echo "Reloading..."; source "$HOME/.zshrc"; }
            ;;
        clang-format|cf)
            _gdf_get ".clang-format" "./.clang-format"
            ;;
        gitignore|gi)
            if [ -n "$gi_type" ]; then
                _gdf_gitignore "$gi_type"
                return $?
            fi
            _gdf_get ".gitignore" "./.gitignore"
            ;;
        gitconfig|gc)
            echo "Getting .gitconfig → $HOME/.gitconfig"
            _gdf_get ".gitconfig" "$HOME/.gitconfig"
            ;;
        kittyconfig|kc)
            echo "Getting kitty.conf → $HOME/.config/kitty/kitty.conf"
            mkdir -p "$HOME/.config/kitty"
            _gdf_get ".config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
            ;;
        ruff)
            echo "Getting ruff.toml → $HOME/.config/ruff/ruff.toml"
            mkdir -p "$HOME/.config/ruff"
            _gdf_get ".config/ruff/ruff.toml" "$HOME/.config/ruff/ruff.toml"
            ;;
        batconfig)
            echo "Getting bat config → $HOME/.config/bat/"
            mkdir -p "$HOME/.config/bat/themes"
            _gdf_get ".config/bat/config" "$HOME/.config/bat/config"
            _gdf_get ".config/bat/themes/Catppuccin Mocha.tmTheme" "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme"
            bat cache --build
            ;;
        atuin)
            echo "Getting atuin config → $HOME/.config/atuin/config.toml"
            mkdir -p "$HOME/.config/atuin"
            _gdf_get ".config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
            ;;
        *)
            echo "Error: Unknown file '$file'"
            return 1
            ;;
    esac

    echo "Done"
}

# gitignore generator — fetches from github/gitignore templates
_gdf_gitignore() {
    local lang="$1"
    local url=""
    case "$lang" in
        python|py)   url="https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore" ;;
        node|js|ts)  url="https://raw.githubusercontent.com/github/gitignore/main/Node.gitignore" ;;
        rust|rs)     url="https://raw.githubusercontent.com/github/gitignore/main/Rust.gitignore" ;;
        go)          url="https://raw.githubusercontent.com/github/gitignore/main/Go.gitignore" ;;
        c|cpp|c++)   url="https://raw.githubusercontent.com/github/gitignore/main/C.gitignore" ;;
        java)        url="https://raw.githubusercontent.com/github/gitignore/main/Java.gitignore" ;;
        latex|tex)   url="https://raw.githubusercontent.com/github/gitignore/main/TeX.gitignore" ;;
        *)
            echo "Unknown gitignore type '$lang'. Available: python, node, rust, go, c, java, latex"
            return 1
            ;;
    esac
    echo "Fetching $lang .gitignore..."
    curl -sS -f -o .gitignore "$url" || { echo "Failed to fetch gitignore"; return 1; }
    echo "Created .gitignore for $lang"
}

_gdf_completion() {
    local -a options
    options=(
        'zshrc' 'z'
        'clang-format' 'cf'
        'gitignore' 'gi'
        'gitconfig' 'gc'
        'kittyconfig' 'kc'
        'ruff'
        'batconfig'
        'atuin'
        '-r' '--remote'
    )
    _describe 'gdf options' options
}

compdef _gdf_completion gdf

codestats() {
    if [ -z "$1" ]; then
        echo "Usage: codestats <on|off|status>"
        return 1
    fi
    if [ "$1" = "on" ]; then
        if [ -z "$CODESTATS_API_KEY" ]; then
            echo "Error: CODESTATS_API_KEY is not set. Add it to ~/.zshrc.local"
            return 1
        fi
        echo "Code::Stats plugin enabled"
        export CODESTATS_ENABLED=1
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

# Load thefuck if it is installed
if command -v thefuck &> /dev/null; then
    eval "$(thefuck --alias)"
fi

# Load zoxide if it is installed
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Video re-encoding function for macOS/Windows compatibility
# Usage: rc <input_video> [output_name]
# Defaults to H.264 + AAC in MP4 container (most compatible)
rc() {
    local input="$1"
    local output="$2"
    local codec="h264"
    
    if [[ -z "$input" ]]; then
        echo "Usage: reencode <input_video> [output_name]"
        echo "Re-encodes video to widely compatible codecs (H.264 + AAC)"
        return 1
    fi
    
    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi
    
    # Get filename without extension
    local basename="${input%.*}"
    
    # Use provided name or generate one
    if [[ -z "$output" ]]; then
        output="${basename}_(h264).mp4"
    else
        # Add codec suffix if not present
        if [[ "$output" != *"_("*")"* ]]; then
            output="${output}_(h264)"
        fi
        # Ensure .mp4 extension
        [[ "$output" != *.mp4 ]] && output="${output}.mp4"
    fi
    
    echo "Re-encoding '$input' -> '$output' (H.264 + AAC)"
    
    ffmpeg -i "$input" -c:v libx264 -preset medium -crf 23 \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        -y "$output"
    
    if [[ $? -eq 0 ]]; then
        echo "Done. Output: $output"
    else
        echo "Error during re-encoding"
        return 1
    fi
}

# Usage: yd <url> [output_name]
yd() {
    if [[ -z "$1" ]]; then
        echo "Usage: yd <url> [output_name]"
        return 1
    fi
    local url="$1"
    local out="${2:+$2.%(ext)s}"
    yt-dlp \
        -f "bv+ba/b" \
        --merge-output-format mp4 \
        --recode-video mp4 \
        --postprocessor-args "ffmpeg:-c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k -movflags +faststart" \
        --no-embed-thumbnail \
        ${out:+-o "$out"} \
        "$url"
}

ff.videotogif() {
    local input="$1"
    local output="$2"
    local fps="${3:-15}"
    local width="${4:-640}"

    if [[ -z "$input" ]]; then
        echo "Usage: ff.videotogif <input_video> [output_name] [fps] [width]"
        echo "  fps    — frames per second (default: 15)"
        echo "  width  — output width in pixels (default: 640, height auto-scaled)"
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    local basename="${input%.*}"
    [[ -z "$output" ]] && output="${basename}.gif"
    [[ "$output" != *.gif ]] && output="${output}.gif"

    echo "Converting '$input' -> '$output' (fps=$fps, width=$width)"

    # Two-pass palette approach for best quality
    local palette="/tmp/togif_palette_$$.png"

    ffmpeg -hide_banner -v warning -stats -i "$input" \
        -vf "fps=${fps},scale=${width}:-1:flags=lanczos,palettegen=stats_mode=diff" \
        -y "$palette" && \
    ffmpeg -hide_banner -v warning -stats -i "$input" -i "$palette" \
        -lavfi "fps=${fps},scale=${width}:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -y "$output"

    local ret=$?
    rm -f "$palette"

    if [[ $ret -eq 0 ]]; then
        local size=$(du -sh "$output" | cut -f1)
        echo "Done. Output: $output ($size)"
    else
        echo "Error during conversion"
        return 1
    fi
}

ff.compress() {
    local input=""
    local output=""
    local crf="28"
    local compress_all=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: ff.compress [options]"
                echo "Options:"
                echo "  -a, --all             Compress all videos in the current directory"
                echo "  -i, --input <file>    Input video file (can alternatively be a positional argument)"
                echo "  -o, --output <file>   Output video file (default: <input>_compressed.<ext>)"
                echo "  --crf <value>         Quality level (lower is better, default: 28)"
                echo "  -h, --help            Show this help message"
                return 0
                ;;
            -a|--all)
                compress_all=1
                shift
                ;;
            -i|--input)
                input="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            --crf)
                crf="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                    shift
                else
                    echo "Unknown argument: $1"
                    return 1
                fi
                ;;
        esac
    done

    if [[ $compress_all -eq 1 ]]; then
        setopt localoptions nullglob
        local files=(*.{mp4,MP4,mkv,mov,avi,webm})
        local target_files=()
        
        for f in $files; do
            if [[ "$f" != *_compressed.* ]]; then
                target_files+=("$f")
            fi
        done

        local total=${#target_files[@]}
        if [[ $total -eq 0 ]]; then
            echo "No video files found to compress."
            return 0
        fi

        local current=0
        for f in "${target_files[@]}"; do
            ((current++))
            local percent=$(( current * 100 / total ))
            local basename="${f%.*}"
            local ext="${f##*.}"
            local out="${basename}_compressed.${ext}"

            echo -e "\n[$current/$total ($percent%)] Compressing '$f' -> '$out' (CRF=$crf)"

            # < /dev/null prevents ffmpeg from eating stdin in the loop
            ffmpeg -hide_banner -v warning -stats -i "$f" \
                -vcodec libx264 -crf "$crf" -preset fast -c:a copy \
                -y "$out" < /dev/null

            local ret=$?
            if [[ $ret -eq 255 || $ret -eq 130 ]]; then
                echo -e "\nBatch compression canceled."
                rm -f "$out" # Clean up the incomplete file
                return 1
            elif [[ $ret -eq 0 ]]; then
                local orig_size=$(du -sh "$f" | cut -f1)
                local new_size=$(du -sh "$out" | cut -f1)
                echo "Done: $out ($new_size, was $orig_size)"
            else
                echo "Error compressing $f"
            fi
        done
        echo -e "\nBatch compression complete."
        return 0
    fi

    if [[ -z "$input" ]]; then
        echo "Error: No input file provided. Use -h for help."
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    # Determine fallback output name if none is provided
    local basename="${input%.*}"
    local ext="${input##*.}"
    if [[ -z "$output" ]]; then
        output="${basename}_compressed.${ext}"
    fi

    echo "Compressing '$input' -> '$output' (CRF=$crf)"

    # Compress video using libx264 and fast preset, copy audio track, show progress (-stats)
    ffmpeg -hide_banner -v warning -stats -i "$input" \
        -vcodec libx264 -crf "$crf" -preset fast -c:a copy \
        -y "$output"

    local ret=$?

    if [[ $ret -eq 0 ]]; then
        local orig_size=$(du -sh "$input" | cut -f1)
        local new_size=$(du -sh "$output" | cut -f1)
        echo -e "\nDone. Output: $output ($new_size, was $orig_size)"
    else
        echo -e "\nError during compression"
        return 1
    fi
}

ff.trim() {
    local input=""
    local start=""
    local end=""
    local output=""
    local accurate=0
    local fade_in=0
    local fade_out=0
    local fade_in_dur="2"
    local fade_out_dur="2"

    # helper: convert HH:MM:SS or MM:SS or seconds to decimal seconds
    _ts2sec() {
        local t="$1"
        if [[ "$t" == *:* ]]; then
            local parts=(${(s/:/)t})
            if [[ ${#parts} -eq 3 ]]; then
                awk "BEGIN {print ${parts[1]}*3600 + ${parts[2]}*60 + ${parts[3]}}"
            else
                awk "BEGIN {print ${parts[1]}*60 + ${parts[2]}}"
            fi
        else
            echo "$t"
        fi
    }

    # helper: get video duration in seconds via ffprobe
    _vid_dur() {
        ffprobe -v error -show_entries format=duration \
            -of csv=p=0 "$1" 2>/dev/null
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: ff.trim <input> [options] [output]"
                echo "Trim a video to a time range, optionally with fade in/out."
                echo ""
                echo "Positional:"
                echo "  input        Input video file (first positional arg)"
                echo "  output       Output file (last positional arg if no flag value follows)"
                echo "               Default: <input>_trimmed.<ext>"
                echo ""
                echo "Options:"
                echo "  -i <time>    Start timestamp (HH:MM:SS or seconds, default: 0)"
                echo "  -o <time>    End timestamp (HH:MM:SS or seconds, default: end of video)"
                echo "  --accurate   Re-encode for frame-accurate cuts"
                echo "  --fade-in[=n]   Fade in from black/silence (default: 2s)"
                echo "  --fade-out[=n]  Fade out to black/silence (default: 2s)"
                echo "               Using --fade-* forces re-encode."
                echo "  -h, --help   Show this help"
                echo ""
                echo "Examples:"
                echo "  ff.trim video.mp4 -i 00:01:30 -o 00:02:45"
                echo "  ff.trim video.mp4 -i 10 --fade-in --fade-out   # 10s → end + fades"
                echo "  ff.trim video.mp4 -o 00:05:00 clip.mp4          # start → 5:00"
                echo "  ff.trim video.mp4 --fade-in=1.5 --fade-out=3    # whole video + fades"
                return 0
                ;;
            --accurate)
                accurate=1
                shift
                ;;
            --fade-in=*)
                fade_in=1
                fade_in_dur="${1#*=}"
                shift
                ;;
            --fade-in)
                fade_in=1
                shift
                ;;
            --fade-out=*)
                fade_out=1
                fade_out_dur="${1#*=}"
                shift
                ;;
            --fade-out)
                fade_out=1
                shift
                ;;
            -i)
                start="$2"
                shift 2
                ;;
            -o)
                end="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                elif [[ -z "$output" ]]; then
                    output="$1"
                else
                    echo "Too many positional arguments: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$input" ]]; then
        echo "Error: No input file provided. Use -h for help."
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    # resolve defaults: start → 0, end → video duration
    if [[ -z "$start" ]]; then
        start="0"
    fi
    if [[ -z "$end" ]]; then
        end=$(_vid_dur "$input")
        if [[ -z "$end" ]]; then
            echo "Error: Could not determine video duration (ffprobe failed)"
            return 1
        fi
    fi

    local basename="${input%.*}"
    local ext="${input##*.}"
    [[ -z "$output" ]] && output="${basename}_trimmed.${ext}"

    # fades need re-encode (stream copy can't apply filters)
    if [[ $fade_in -eq 1 || $fade_out -eq 1 ]]; then
        accurate=1
    fi

    # build filter chains if fades are requested
    local vf=""
    local af=""

    if [[ $fade_in -eq 1 || $fade_out -eq 1 ]]; then
        local start_sec=$(_ts2sec "$start")
        local end_sec=$(_ts2sec "$end")
        local duration=$(awk "BEGIN {print $end_sec - $start_sec}")

        local vf_parts=()
        local af_parts=()

        if [[ $fade_in -eq 1 ]]; then
            vf_parts+=("fade=t=in:st=0:d=${fade_in_dur}")
            af_parts+=("afade=t=in:st=0:d=${fade_in_dur}")
        fi

        if [[ $fade_out -eq 1 ]]; then
            local fade_out_start=$(awk "BEGIN {print $duration - $fade_out_dur}")
            vf_parts+=("fade=t=out:st=${fade_out_start}:d=${fade_out_dur}")
            af_parts+=("afade=t=out:st=${fade_out_start}:d=${fade_out_dur}")
        fi

        vf="${(j:,:)vf_parts}"
        af="${(j:,:)af_parts}"
    fi

    # build mode label and time range display
    local mode="stream copy"
    local range="${start} → ${end}"
    [[ $accurate -eq 1 ]] && mode="re-encode"
    [[ -n "$vf" ]] && mode="${mode} + fades"

    # build ffmpeg seek args (only include -ss/-to if actually trimming)
    local seek_args=()
    if [[ "$start" != "0" ]]; then
        seek_args+=(-ss "$start")
    fi
    if [[ -n "$end" ]]; then
        seek_args+=(-to "$end")
    fi

    if [[ $accurate -eq 1 ]]; then
        echo "Trimming '$input' -> '$output' (${range}, ${mode})"
        local vf_opt=()
        local af_opt=()
        [[ -n "$vf" ]] && vf_opt=(-vf "$vf")
        [[ -n "$af" ]] && af_opt=(-af "$af")

        ffmpeg -hide_banner -v warning -stats -i "$input" \
            "${seek_args[@]}" \
            "${vf_opt[@]}" "${af_opt[@]}" \
            -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
            -movflags +faststart \
            -y "$output"
    else
        echo "Trimming '$input' -> '$output' (${range}, ${mode})"
        ffmpeg -hide_banner -v warning -stats "${seek_args[@]}" -i "$input" \
            -c copy -avoid_negative_ts make_zero \
            -y "$output"
    fi

    local ret=$?

    if [[ $ret -eq 0 ]]; then
        local size=$(du -sh "$output" | cut -f1)
        echo -e "\nDone. Output: $output ($size)"
    else
        echo -e "\nError during trim"
        return 1
    fi
}

# take a video and convert it to mp4 with h264 + aac for maximum compatibility
ff.tomp4() {
    local input="$1"
    local output="$2"

    if [[ -z "$input" ]]; then
        echo "Usage: ff.tomp4 <input_video> [output_name]"
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    local basename="${input%.*}"
    [[ -z "$output" ]] && output="${basename}.mp4"
    [[ "$output" != *.mp4 ]] && output="${output}.mp4"

    echo "Converting '$input' -> '$output' (H.264 + AAC)"

    ffmpeg -hide_banner -v warning -stats -i "$input" \
        -c:v libx264 -preset medium -crf 23 \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        -y "$output"

    local ret=$?

    if [[ $ret -eq 0 ]]; then
        local size=$(du -sh "$output" | cut -f1)
        echo "Done. Output: $output ($size)"
    else
        echo "Error during conversion"
        return 1
    fi
}

# get total frame count of a video
ff.getframes() {
    local input="$1"

    if [[ -z "$input" ]]; then
        echo "Usage: ff.getframes <video>"
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$input"
}

# normalize audio in a video (two-pass loudness normalization)
ff.normalize() {
    local input="$1"
    local output="$2"

    if [[ -z "$input" ]]; then
        echo "Usage: ff.normalize <input_video> [output_video]"
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' not found"
        return 1
    fi

    local basename="${input%.*}"
    [[ -z "$output" ]] && output="${basename}_normalized.mp4"
    [[ "$output" != *.mp4 ]] && output="${output}.mp4"

    echo "Pass 1: Analyzing loudness..."
    local json=$(ffmpeg -i "$input" -af loudnorm=print_format=json -f null - 2>&1)

    # Parse JSON output
    local measured_I=$(echo "$json" | grep -o '"measured_I"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')
    local measured_TP=$(echo "$json" | grep -o '"measured_TP"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')
    local measured_LRA=$(echo "$json" | grep -o '"measured_LRA"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')
    local measured_thresh=$(echo "$json" | grep -o '"measured_thresh"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')

    if [[ -z "$measured_I" ]]; then
        echo "Error: Failed to analyze audio"
        return 1
    fi

    echo "  Measured: I=$measured_I, TP=$measured_TP, LRA=$measured_LRA, thresh=$measured_thresh"
    echo "Pass 2: Normalizing..."

    ffmpeg -hide_banner -v warning -stats -i "$input" \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=0.5:linear=true" \
        -ar 48000 \
        -y "$output"

    local ret=$?

    if [[ $ret -eq 0 ]]; then
        local size=$(du -sh "$output" | cut -f1)
        echo "Done. Output: $output ($size)"
    else
        echo "Error during normalization"
        return 1
    fi
}
# openclaw tui — open a TUI with an optional model alias
# usage: ot [model_alias]
#        ot          -> default model (deepseek)
#        ot opus     -> openrouter/anthropic/claude-opus-4.6
#        ot deepseek-pro -> deepseek v4 pro
ot() {
    local model="${1:-}"
    if [[ -n "$model" ]]; then
        openclaw tui --session "ot-${model}"
    else
        openclaw tui
    fi
}