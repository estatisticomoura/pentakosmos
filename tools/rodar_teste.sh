#!/bin/sh
# Roda um script de teste sem interface, com limite de tempo.
cd "$(dirname "$0")/.." && timeout "${TIMEOUT:-300}" godot --headless --path . --script "$@" 2>&1
