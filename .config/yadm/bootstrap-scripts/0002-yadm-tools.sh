#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "$0")"

echo "[$script_name]: initializing tools"

# z script - directory jumping utility
echo "[$script_name]: initializing z script"
zscript_dir="$HOME/github/z"
if [[ -d "$zscript_dir/.git" ]]; then
    echo "[$script_name]: z script already cloned, updating"
    git -C "$zscript_dir" pull
else
    echo "[$script_name]: cloning z script"
    mkdir -p "$zscript_dir"
    git clone https://github.com/rupa/z.git "$zscript_dir"
fi

# devbox
echo "[$script_name]: ensuring devbox is installed"
command -v devbox &> /dev/null || curl -fsSL https://get.jetify.com/devbox | bash

# devbox global packages
echo "[$script_name]: initializing devbox global packages"
devbox_packages=(
    "llama-cpp"
    "awscli"
    "doctl"
    "helm"
    "kind"
    "kubectl"
    "minikube"
    "nodejs"
    "python"
    "terraform"
    "yarn"
    "go"
    "fzf"
    "go-task"
)

for package in "${devbox_packages[@]}"; do
    echo "[$script_name]: adding devbox global package: $package"
    devbox global add "${package}@latest"
done

echo "[$script_name]: tools initialization complete"
