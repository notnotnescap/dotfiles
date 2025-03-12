#! /bin/bash

# Setting up directories
mkdir ~/dev
mkdir ~/dev/GitHub
mkdir ~/dev/GitHub/archives

# Pulling files
echo "Pulling .zshrc..."
curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.zshrc || echo 'Failed to fetch .zshrc'
source ~/.zshrc
echo "Done."

# should be installed :
# zoxide
# thefuck
# bat
# fzf


# BAT config
# mkdir -p "$(bat --config-dir)/themes"
# wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme
# bat cache --build
# echo \"--theme="Catppuccin Mocha\"" >> ~/.config/bat/config