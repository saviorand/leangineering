#!/bin/sh
# Pulls the latest awesome-lean-programming readme, which is the single source of truth for /awesome.
set -eu
cd "$(dirname "$0")/.."
curl -fsSL https://raw.githubusercontent.com/saviorand/awesome-lean-programming/main/readme.md -o data/awesome-lean.md
echo "data/awesome-lean.md updated"
