#! /bin/zsh

# Path to oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# Load zsh theme
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# command auto-correction (will for example correct 'sl' to 'ls')
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"


# Loading plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Code::Stats
# Load Code::Stats API key from a separate file
if [ "$VS_CODE_TERMINAL" != "true" ]; then
    if [ -f "$HOME/.codestats_api_key" ]; then
        export CODESTATS_API_KEY=$(cat $HOME/.codestats_api_key)
    fi
else
    echo "\033[0;33mVS Code terminal detected, Code::Stats plugin rejected\033[0m"
fi

# load zgen
source "${HOME}/.zgen/zgen.zsh"
# if the init script doesn't exist
if ! zgen saved; then
    # Code::Stats plugin
    zgen load git@gitlab.com:code-stats/code-stats-zsh.git

    # load oh-my-zsh
    zgen oh-my-zsh
    zgen oh-my-zsh plugins/git
    zgen oh-my-zsh plugins/zsh-autosuggestions
    zgen oh-my-zsh plugins/zsh-syntax-highlighting
    zgen oh-my-zsh plugins/web-search

    # generate the init script from plugins above
    zgen save
fi

# export MANPATH="/usr/local/man:$MANPATH"
export MANPAGER="nvim +Man!"

# aliases
alias cf="find . -type f -name '*.[ch]' -exec clang-format --verbose -style=file -i {} \;"
alias zshrc="source ~/.zshrc"
alias testzshrc="cp ./.zshrc ~/.zshrc && source ~/.zshrc"
alias mkvenv="python3 -m venv venv && source venv/bin/activate"

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


# Load local aliases (if the file exists)
if [ -f "$HOME/.zshrc_local" ]; then
    source "$HOME/.zshrc_local"
fi

# Load thefuck
eval $(thefuck --alias)
