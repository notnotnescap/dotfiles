#! /bin/bash

echo "Pulling .zshrc..."
curl -f -o ~/.zshrc https://raw.githubusercontent.com/notnotnescap/dotfiles/refs/heads/master/.zshrc || echo 'Failed to fetch .zshrc'
source ~/.zshrc
echo "Done."

# more stuff will be added here

# install thefuck