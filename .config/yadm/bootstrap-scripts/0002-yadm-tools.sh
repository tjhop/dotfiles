#!/usr/bin/env bash

echo "[$(basename $0)]: initializing tools"

echo "[$(basename $0)]: initializing z script"
zscript_dir="$HOME/github/z"
mkdir -p $zscript_dir
git clone https://github.com/rupa/z.git $zscript_dir

echo "[$(basename $0)]: initializing asdf"
asdf_dir="$HOME/github/asdf"
mkdir -p $asdf_dir
git clone https://github.com/asdf-vm/asdf.git $asdf_dir

asdf_tools=(
    "awscli"
    "doctl"
    "golang"
    "golangci-lint"
    "helm"
    "kind"
    "kubectl"
    "loki-logcli"
    "minikube"
    "nodejs"
    "python"
    "terraform"
    "vault"
    "yarn"
)

for tool in "${asdf_tools[@]}"; do
    echo "[$(basename $0)]: initializing ${tool} with latest version"
    asdf plugin-add "${tool}"
    asdf install "${tool}" latest
    asdf global "${tool}" latest
done
