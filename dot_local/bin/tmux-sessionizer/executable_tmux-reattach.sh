#!/usr/bin/env bash

switch_to() {
    if [[ -z $TMUX ]]; then
        tmux attach-session -t $1
    else
        tmux switch-client -t $1
    fi
}



# We are able to kill a session with pressing ctrl-d
selected_session=$(tmux ls | awk '{print $1}' | cut -d: -f1 | 
    fzf --tmux --bind 'ctrl-d:execute(tmux kill-session -t {})+reload(tmux ls | awk "{print $1}" | cut -d: -f1)')

if [[ -z $selected_session ]]; then
    exit 0
fi

switch_to $selected_session
