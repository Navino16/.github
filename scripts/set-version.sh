#!/usr/bin/env bash
# Usage: scripts/set-version.sh X.Y.Z — moves every reference to the kit's version.
set -euo pipefail
cd "$(dirname "$0")/.."

new="${1:?usage: scripts/set-version.sh X.Y.Z}"
[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be X.Y.Z" >&2; exit 1; }
old="$(cat VERSION)"

echo "$new" > VERSION
sed -i "s/<!-- repo-kit:start $old -->/<!-- repo-kit:start $new -->/" claude-block.md CLAUDE.md
sed -i -E "s#(Navino16/\\.github[^@\#\"[:space:]]*[@\#])$old#\\1$new#g" README.md templates/workflows/*.yml
echo "$old -> $new"
