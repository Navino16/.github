#!/usr/bin/env bash
# Usage: scripts/apply-settings.sh [--dry-run] [--default-branch NAME] <owner/repo>
# Aligns a repository's settings on settings/repository.json and prints what changes.
# The Actions right to create and approve pull requests is left as each repository has it.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "usage: $0 [--dry-run] [--default-branch NAME] <owner/repo>" >&2; exit 2; }

dry_run=false
default_branch=""
repo=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --default-branch) [ "$#" -ge 2 ] || usage; default_branch="$2"; shift 2 ;;
    -*) usage ;;
    *) [ -z "$repo" ] || usage; repo="$1"; shift ;;
  esac
done
[ -n "$repo" ] || usage

want="$(jq --arg branch "$default_branch" 'if $branch != "" then .repository.default_branch = $branch else . end' settings/repository.json)"
current="$(gh api "repos/$repo")"
public="$(jq -r '.visibility == "public"' <<<"$current")"

changes=()
actions=()
change() { changes+=("  $1: $2 -> $3"); }

patch="$(jq -c --argjson cur "$current" '.repository | with_entries(select(.value != $cur[.key]))' <<<"$want")"
while IFS=$'\t' read -r key from to; do
  [ -n "$key" ] && change "$key" "$from" "$to"
done < <(jq -r --argjson cur "$current" 'to_entries[] | [.key, ($cur[.key] | tostring), (.value | tostring)] | @tsv' <<<"$patch")

if [ "$public" = true ]; then
  security="{}"
  for feature in secret_scanning secret_scanning_push_protection; do
    from="$(jq -r --arg f "$feature" '.security_and_analysis[$f].status // "disabled"' <<<"$current")"
    to="$(jq -r --arg f "$feature" 'if .public_only[$f] then "enabled" else "disabled" end' <<<"$want")"
    if [ "$from" != "$to" ]; then
      change "$feature" "$from" "$to"
      security="$(jq -c --arg f "$feature" --arg s "$to" '.[$f] = {status: $s}' <<<"$security")"
    fi
  done
  [ "$security" = "{}" ] || patch="$(jq -c --argjson s "$security" '.security_and_analysis = $s' <<<"$patch")"
fi
[ "$patch" = "{}" ] || actions+=("PATCH|$patch")

toggle() { # name, current, wanted, endpoint
  [ "$2" = "$3" ] && return
  change "$1" "$2" "$3"
  if [ "$3" = true ]; then actions+=("PUT $4|"); else actions+=("DELETE $4|"); fi
}

alerts=false
gh api "repos/$repo/vulnerability-alerts" >/dev/null 2>&1 && alerts=true
toggle dependabot_alerts "$alerts" "$(jq -r .dependabot_alerts <<<"$want")" vulnerability-alerts
toggle dependabot_security_updates \
  "$(gh api "repos/$repo/automated-security-fixes" | jq -r .enabled)" \
  "$(jq -r .dependabot_security_updates <<<"$want")" automated-security-fixes

if [ "$public" = true ]; then
  toggle private_vulnerability_reporting \
    "$(gh api "repos/$repo/private-vulnerability-reporting" | jq -r .enabled)" \
    "$(jq -r .public_only.private_vulnerability_reporting <<<"$want")" private-vulnerability-reporting
  codeql="$(gh api "repos/$repo/code-scanning/default-setup" | jq -r '.state == "configured"')"
  if [ "$codeql" != "$(jq -r .public_only.codeql_default_setup <<<"$want")" ]; then
    change codeql_default_setup "$codeql" true
    actions+=('PATCH code-scanning/default-setup|{"state":"configured"}')
  fi
fi

workflow="$(gh api "repos/$repo/actions/permissions/workflow")"
from="$(jq -r .default_workflow_permissions <<<"$workflow")"
to="$(jq -r .default_workflow_permissions <<<"$want")"
if [ "$from" != "$to" ]; then
  change default_workflow_permissions "$from" "$to"
  actions+=("PUT actions/permissions/workflow|$(jq -c --arg p "$to" '{default_workflow_permissions: $p, can_approve_pull_request_reviews}' <<<"$workflow")")
fi

if [ "${#changes[@]}" -eq 0 ]; then
  echo "$repo already matches settings/repository.json"
  exit 0
fi
echo "$repo:"
printf '%s\n' "${changes[@]}"
$dry_run && exit 0

for action in "${actions[@]}"; do
  request="${action%%|*}"
  body="${action#*|}"
  method="${request%% *}"
  endpoint="${request#* }"
  path="repos/$repo"
  [ "$request" = "$method" ] || path="$path/$endpoint"
  if [ -n "$body" ]; then
    gh api -X "$method" "$path" --input - <<<"$body" >/dev/null
  else
    gh api -X "$method" "$path" >/dev/null
  fi
done
echo "Applied."
