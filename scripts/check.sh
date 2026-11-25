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
docker run --rm -v "$PWD:/repo" -w /repo "rhysd/actionlint:${ACTIONLINT_VERSION}" -color .github/workflows/*.yml
