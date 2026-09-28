#!/bin/sh
# Pulls the latest awesome-lean readme, which is the single source of truth for /awesome.
set -eu
cd "$(dirname "$0")/.."
curl -fsSL https://raw.githubusercontent.com/saviorand/awesome-lean/main/readme.md -o data/awesome-lean.md
echo "data/awesome-lean.md updated"
