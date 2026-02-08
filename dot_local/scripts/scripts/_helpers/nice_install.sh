#!/bin/bash

install_package() {
    local command=$1
    shift 1  # Remove first argument
    local packages=("$@")  # Rest are packages

    local message="Install the following packages: ${packages[@]}..."
    
    local tmplog=$(mktemp)
    
    # Check if command contains sudo and authenticate upfront
    if [[ $command == *"sudo"* ]]; then
	activate_sudo "Need sudo privilages as command has sudo"
    fi
    if [[ $command == *"yay"* ]]; then sudo -v  # Prompt for password and refresh sudo timestamp
	activate_sudo "Need sudo for yay"
    fi
    
    if gum spin --spinner dot --title "$message..." -- \
        bash -c "$command ${packages[*]} &>'$tmplog'"; then
        gum style --foreground 46 "✓ $message"
    else
        gum style --foreground 196 "✗ $message"
        cat $tmplog
    fi
    
    rm -f "$tmplog"
}

activate_sudo() {
    if ! sudo -n true 2>/dev/null; then
	gum log --structured --level info "$1"
        sudo -v  # Prompt for password and refresh sudo timestamp
    fi
}
