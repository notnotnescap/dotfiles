#! /bin/bash

# Setting up directories
mkdir $HOME/tmp
mkdir -p $HOME/dev/GitHub/archives

# .zshrc
if [[ ! -f $HOME/.zshrc ]]; then
    echo "Getting .zshrc from GitHub..."
    curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.zshrc || echo 'Failed to fetch .zshrc'
else
    read -r "a?a .zshrc file already exists. Overwrite it? [y/N] "
    if [[ "$a" =~ ^[Yy]$ ]]; then
        curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.zshrc || echo 'Failed to fetch .zshrc'
        echo "Overwrote existing .zshrc"
    else
        echo "Keeping the existing .zshrc file"
    fi
fi

# .zshrc.local
read -r "a?Create a .zshrc.local template? [Y/n] "
if [[ "$a" =~ ^[Yy]$ || -z "$a" ]]; then
    echo "Creating .zshrc.local template..."
    curl -f -o ~/.zshrc.local https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.zshrc.local || echo 'Failed to fetch .zshrc.local'
    echo "Created ~/.zshrc.local"
fi

# Setting up zsh plugins
# check if git is installed
if [[ ! $(command -v git) ]]; then
    echo "Git is not installed. Please install git and rerun the script."
    exit 1
fi

read -r "a?Intall zsh-autosuggestions and zsh-syntax-highlighting? [Y/n] "
if [[ "$a" =~ ^[Yy]$ || -z "$a" ]]; then
    echo "Installing zsh-autosuggestions and zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
    echo "Installed zsh plugins."
fi
read -r "a?Intall code-stats-zsh plugin? [Y/n] "
if [[ "$a" =~ ^[Yy]$ || -z "$a" ]]; then
    echo "Installing code-stats-zsh plugin..."
    git clone https://gitlab.com/code-stats/code-stats-zsh.git ~/.zsh/code-stats-zsh
    echo "Installed code-stats-zsh plugin."
fi
source ~/.zshrc
echo "Done."

# to be installed :
#  exa
#  fd
#  fzf
#  thefuck
#  zoxide
#  zsh-autosuggestions
#  zsh-syntax-highlighting

# optional tools:
#  bat
#  ripgrep
#  ruff
#  uv

# BAT theme setup
# mkdir -p "$(bat --config-dir)/themes"
# wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme
# bat cache --build
# echo \"--theme="Catppuccin Mocha\"" >> ~/.config/bat/config
