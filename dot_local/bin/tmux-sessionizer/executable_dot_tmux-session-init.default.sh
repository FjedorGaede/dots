#!/usr/bin/env bash

tmux rename-window "nvim"
tmux new-window -dn "scratch"
clear

nvim .

