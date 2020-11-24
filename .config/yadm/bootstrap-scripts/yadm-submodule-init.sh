#!/usr/bin/env bash

echo "[yadm bootstrap]: initializing submodules"
yadm -C "$HOME" submodule update --recursive --init
