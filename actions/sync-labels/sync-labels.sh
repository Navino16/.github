#!/usr/bin/env bash
# Usage: sync-labels.sh [--dry-run] <labels.json> <owner/repo>
# Creates or updates every label of the file; never deletes a label the repository has on its own.
set -euo pipefail

dry_run=false
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=true
  shift
fi
if [ "$#" -ne 2 ]; then
  echo "usage: $0 [--dry-run] <labels.json> <owner/repo>" >&2
  exit 2
fi
file="$1"
repo="$2"

errors="$(jq -r '
  if type != "array" then "the file must be a JSON array"
  else
    (.[] | select((.name | type) != "string" or .name == "") | "label without a name: \(tojson)"),
    (.[] | select((.color | type) != "string" or (.color | test("^[0-9a-fA-F]{6}$") | not)) | "\(.name): color must be 6 hex digits"),
    (.[] | select((.description // "" | length) > 100) | "\(.name): description over 100 characters"),
    (group_by(.name) | .[] | select(length > 1) | "\(.[0].name): defined \(length) times")
  end
' "$file")"
if [ -n "$errors" ]; then
  echo "::error::Invalid labels file $file"
  echo "$errors" >&2
  exit 1
fi

jq -r '.[] | [.name, .color, (.description // "")] | @tsv' "$file" |
  while IFS=$'\t' read -r name color description; do
    if $dry_run; then
      printf 'gh label create %s --color %s --description %s --force -R %s\n' "${name@Q}" "$color" "${description@Q}" "$repo"
    else
      gh label create "$name" --color "$color" --description "$description" --force -R "$repo"
    fi
  done
