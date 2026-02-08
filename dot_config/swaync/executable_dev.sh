#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

ls $SCRIPT_DIR | entr bash -c "swaync-client -R && swaync-client -rs && swaync-client -t"
