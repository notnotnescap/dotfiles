#! /bin/zsh

# Path to oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# Load zsh theme
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Loading plugins

# install : git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# install : git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source $ZSH/oh-my-zsh.sh

# Code::Stats
# Load Code::Stats API key from a separate file
if [ "$VS_CODE_TERMINAL" = "true" ]; then
    echo "\033[0;33mVS Code terminal detected, Code::Stats plugin rejected\033[0m"
else
    if [ -f "$HOME/.codestats_api_key" ]; then
        export CODESTATS_API_KEY=$(cat $HOME/.codestats_api_key)
    fi
fi

# local Code::Stats plugin
source "${HOME}/.zsh/plugins/codestats.zsh"

# Settings
export MANPAGER="nvim +Man!"
HISTSIZE=15000  # keep at most 15k commands in memory
SAVEHIST=10000  # keep at most 10k commands in HISTFILE
HISTFILE=~/.zsh_history

# directories
export tmpdir="/var/tmp"
export devdir="$HOME/dev"
export ghdir="$HOME/dev/GitHub"
export dotfilesdir="$ghdir/dotfiles"

alias tmp="cd $tmpdir; pwd"
alias dev="cd $devdir; pwd"
alias gh="cd $ghdir; pwd"
alias dotfiles="cd $dotfilesdir; pwd"

# aliases
alias c="clear"
alias sc="cd ~; clear"
alias ncdu="ncdu --color dark"
alias n="ncdu --color dark"
alias b="btop"
alias ez="eza -a --group-directories-first"
alias e="eza -la --group-directories-first"
alias ls="ez"
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
fi

# linux specific
if [[ "$(uname)" == "Linux" ]]; then
    alias pbcopy='xclip -selection clipboard'
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
        curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.zshrc || echo 'Failed to pull .zshrc'
        echo "Running zshrc..."
        source ~/.zshrc
        echo "Done"
    fi

    if [ "$1" = "clang-format" ] || [ "$1" = "cf" ]; then
        curl -f -o .clang-format https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.clang-format || echo 'Failed to clone .clang-format'
        echo "Done"
    fi

    if [ "$1" = "gitignore" ] || [ "$1" = "gi" ]; then
        curl -f -o .gitignore https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.gitignore || echo 'Failed to clone .gitignore'
        echo "Done"
    fi

    if [ "$1" = "gitconfig"] || [ "$1" = "gc" ]; then
        echo "Pulling .gitconfig at $HOME/.gitconfig..."
        curl -f -o ~/.gitconfig https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.gitconfig || echo 'Failed to pull .zshrc'
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


# Load local aliases (if the file exists)
if [ -f "$HOME/.zshrc_local" ]; then
    source "$HOME/.zshrc_local"
fi

# Load thefuck
eval $(thefuck --alias)

# Load zoxide
eval "$(zoxide init zsh)"
