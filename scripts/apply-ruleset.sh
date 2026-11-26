#!/usr/bin/env bash
# Usage: scripts/apply-ruleset.sh [--dry-run] [--e2e] <owner/repo>
# Creates or updates the repository's ruleset from rulesets/main-develop.json (matched by name).
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "usage: $0 [--dry-run] [--e2e] <owner/repo>" >&2; exit 2; }

dry_run=false
e2e=false
repo=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --e2e) e2e=true ;;
    -*) usage ;;
    *) [ -z "$repo" ] || usage; repo="$arg" ;;
  esac
done
[ -n "$repo" ] || usage

ruleset="$(jq --argjson e2e "$e2e" '
  if $e2e then
    .rules |= map(if .type == "required_status_checks"
      then .parameters.required_status_checks += [{context: "ci / E2E", integration_id: 15368}]
      else . end)
  else . end
' rulesets/main-develop.json)"

if $dry_run; then
  echo "$ruleset"
  exit 0
fi

name="$(jq -r .name <<<"$ruleset")"
if ! existing="$(gh api "repos/$repo/rulesets" 2>&1)"; then
  echo "::error::Cannot read the rulesets of $repo: $existing" >&2
  echo "Rulesets on a private repository need GitHub Pro." >&2
  exit 1
fi
id="$(jq -r --arg name "$name" '.[] | select(.name == $name) | .id' <<<"$existing")"

if [ -n "$id" ]; then
  gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$ruleset" >/dev/null
  echo "Updated ruleset '$name' ($id) on $repo"
else
  id="$(gh api -X POST "repos/$repo/rulesets" --input - --jq .id <<<"$ruleset")"
  echo "Created ruleset '$name' ($id) on $repo"
fi
