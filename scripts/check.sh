#!/usr/bin/env bash
# Runs every check of the kit; kit-check.yml runs the same script.
set -euo pipefail
cd "$(dirname "$0")/.."

RENOVATE_VERSION=44.262.2
ACTIONLINT_VERSION=1.7.12

step() { printf '\n== %s\n' "$1"; }

step "Renovate configs"
npx --yes --package "renovate@${RENOVATE_VERSION}" -- renovate-config-validator --strict --no-global default.json renovate.json

step "Label sync"
tests/sync-labels.test.sh

step "Workflows (actionlint)"
docker run --rm -v "$PWD:/repo" -w /repo "rhysd/actionlint:${ACTIONLINT_VERSION}" -color .github/workflows/*.yml templates/workflows/*.yml

step "Labels used by the issue forms"
known="$(jq -r '.[].name' labels.json)"
missing=0
for form in .github/ISSUE_TEMPLATE/*.yml; do
  [ "$(basename "$form")" = config.yml ] && continue
  while IFS= read -r label; do
    if ! grep -qxF "$label" <<<"$known"; then
      echo "$form sets the label '$label', missing from labels.json" >&2
      missing=1
    fi
  done < <(grep -m1 '^labels:' "$form" | sed 's/^labels: *\[//; s/\] *$//' | tr ',' '\n' | sed 's/^ *"//; s/" *$//')
done
[ "$missing" -eq 0 ] && echo "Every form label exists in labels.json"
[ "$missing" -eq 0 ]

step "Kit version references"
version="$(cat VERSION)"
stale=0
for file in claude-block.md CLAUDE.md; do
  grep -qxF "<!-- repo-kit:start $version -->" "$file" || { echo "$file: block marker is not $version" >&2; stale=1; }
done
diff <(sed -n '/<!-- repo-kit:start/,/<!-- repo-kit:end -->/p' CLAUDE.md) claude-block.md >/dev/null \
  || { echo "CLAUDE.md: the shared block differs from claude-block.md" >&2; stale=1; }
while IFS= read -r ref; do
  [ "${ref##*[@#]}" = "$version" ] || { echo "$ref does not point to $version" >&2; stale=1; }
done < <(grep -rhoE 'Navino16/\.github[^@#"[:space:]]*[@#][0-9]+\.[0-9]+\.[0-9]+' README.md templates)
[ "$stale" -eq 0 ] && echo "Every reference points to $version"
[ "$stale" -eq 0 ]
