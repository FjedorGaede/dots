#!/usr/bin/env bash

switch_to() {
    if [[ -z $TMUX ]]; then
        tmux attach-session -t $1
    else
        tmux switch-client -t $1
    fi
}

has_session() {
    tmux list-sessions | grep -q "^$1:"
}

tmux_init_filename=".tmux-session-init.sh"
tmux_sessionizer_init_default=$HOME/.local/bin/tmux-sessionizer/.tmux-session-init.default.sh

hydrate() {
    if [ -f "$2/$tmux_init_filename" ]; then
        tmux send-keys -t $1 "source $2/$tmux_init_filename && clear" Enter
    elif [ -f "$tmux_sessionizer_init_default"  ]; then
        tmux send-keys -t $1 "source $tmux_sessionizer_init_default && clear" Enter
    fi
}

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(find ~/ ~/.dotfiles/.local ~/.dotfiles/.local/bin ~/.dotfiles ~/.dotfiles/.config ~/programming ~/programming/advent-of-code ~/programming/edyoucated ~/personal ~/work ~/projects ~/.config -maxdepth 1 -mindepth 1 -type d 2> /dev/null | fzf --tmux)
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _) # Make file name tmux conform
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s $selected_name -c $selected
    hydrate $selected_name $selected
    exit 0
fi

if ! has_session $selected_name; then
    tmux new-session -ds $selected_name -c $selected
    hydrate $selected_name $selected
fi

switch_to $selected_name
