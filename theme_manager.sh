#!/bin/bash

# Define repository list and corresponding installation commands
declare -A repos=(
    ["WhiteSur-gtk-theme"]="./install.sh --libadwaita -c light -t blue --gnome-shell --round && ./tweaks.sh -F --dash-to-dock --color light --theme blue && sudo ./tweaks.sh -g"
    ["WhiteSur-icon-theme"]="./install.sh -a -b"
    ["McMojave-cursors"]="sudo ./install.sh"
)

# Function to install or update
process_repos() {
    local action=$1
    for repo in "${!repos[@]}"; do
        if [ "$action" = "install" ] && [ ! -d "$repo" ]; then
            git clone "https://github.com/vinceliuice/$repo.git"
        elif [ "$action" = "update" ] && [ -d "$repo" ]; then
            cd "$repo" || exit 0
            git pull
            cd ..
        fi
        if [ -d "$repo" ]; then
            cd "$repo" || exit 0
            eval "${repos[$repo]}"
            cd ..
        fi
    done
}

# Check command line arguments
if [ "$1" = "--install" ]; then
    process_repos "install"
elif [ "$1" = "--update" ]; then
    process_repos "update"
else
    echo "Usage: $0 [--install|--update]"
    echo "  --install: Clone repositories and install"
    echo "  --update: Update existing repositories and reinstall"
    exit 1
fi
