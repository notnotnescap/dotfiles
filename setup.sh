#! /bin/bash

# Setting up directories
mkdir ~/tmp
mkdir ~/dev
mkdir ~/dev/GitHub
mkdir ~/dev/GitHub/archives

# Pulling files
echo "Getting .zshrc..."
curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/main/.zshrc || echo 'Failed to fetch .zshrc'
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