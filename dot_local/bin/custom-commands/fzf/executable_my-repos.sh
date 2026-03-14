#!/usr/bin/env bash

name="FjedorGaede"

gh repo list $name --json name --jq '.[] | .name' | fzf --tmux --bind "enter:execute(xdg-open https://github.com/${name}/{})+abort"
