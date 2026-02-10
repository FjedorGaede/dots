#!/bin/bash

install_on_fedora() {
    sudo dnf install -y ansible
}

install_on_ubuntu() {
    sudo pacman -Syu
    sudo pacman -S ansible
}

OS="$(uname -s)"
case "${OS}" in
    Linux*)
        if [ -f /etc/arch-release ]; then
            install_on_fedora
        else
            echo "Unsupported Linux distribution"
            exit 1
        fi
        ;;
    *)
        echo "Unsupported operating system: ${OS}"
        exit 1
        ;;
esac


# ansible-playbook ~/.bootstrap/setup.yml --ask-become-pass

echo "Ansible installation complete."

