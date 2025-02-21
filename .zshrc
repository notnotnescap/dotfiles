#! /bin/zsh

# Path to oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# Load zsh theme
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Loading plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

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

# load zgen
source "${HOME}/.zgen/zgen.zsh"
# if the init script doesn't exist
if ! zgen saved; then
    # Code::Stats plugin
    # zgen load git@gitlab.com:code-stats/code-stats-zsh.git

    # load oh-my-zsh
    zgen oh-my-zsh
    zgen oh-my-zsh plugins/git
    zgen oh-my-zsh plugins/zsh-autosuggestions
    zgen oh-my-zsh plugins/zsh-syntax-highlighting
    zgen oh-my-zsh plugins/web-search

    # generate the init script from plugins above
    zgen save
fi
# local Code::Stats plugin (for hopefully faster loading)
source "${HOME}/.zsh/plugins/codestats.zsh"

# Settings
export MANPAGER="nvim +Man!"
HISTSIZE=15000  # keep at most 15k commands in memory
SAVEHIST=10000  # keep at most 10k commands in HISTFILE
HISTFILE=~/.zsh_history

# directories
export tempdir="$HOME/Downloads/temp"
export ghdir="$HOME/Documents/Github"
export dotfilesdir="$ghdir/dotfiles"

alias gh="cd $ghdir; pwd"
alias temp="cd $tempdir; pwd"
alias dotfiles="cd $dotfilesdir; pwd"

# aliases
alias cf="find . -type f -name '*.[ch]' ! \(-path '*/lib/*' -o -path '*/build/*'\) -exec clang-format --verbose -style=file -i {} \;"
alias zshrc="source ~/.zshrc"
alias mkvenv="python3 -m venv venv ; source venv/bin/activate"
alias gen-cf="curl -f -o .clang-format https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.clang-format || echo 'Failed to fetch .clang-format'"
alias testzshrc="cp ./.zshrc ~/.zshrc && source ~/.zshrc"
alias mkvenv="python3 -m venv venv && source venv/bin/activate"
alias cwd="pwd | tr -d '\n' | pbcopy; pwd"

# custom functions

# will pull certain files from the dotfiles repo
getmy() {
    if [ -z "$1" ]; then
        echo "Usage: getmy <file>
        Available files:
        - zshrc
        - clang-format cf
        - gitignore gi)"
        return 1
    fi

    if [ "$1" = "zshrc" ]; then
        echo "Pulling .zshrc at $HOME/.zshrc..."
        curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.zshrc || echo 'Failed to pull .zshrc'
        echo "Running zshrc..."
        source ~/.zshrc
        echo "Done."
    fi

    if [ "$1" = "clang-format" ] || [ "$1" = "cf" ]; then
        curl -f -o .clang-format https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.clang-format || echo 'Failed to clone .clang-format'
        echo "Done."
    fi

    if [ "$1" = "gitignore" ] || [ "$1" = "gi" ]; then
        curl -f -o .gitignore https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.gitignore || echo 'Failed to clone .gitignore'
        echo "Done."
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
