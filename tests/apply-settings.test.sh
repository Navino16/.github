#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

SCRIPT=scripts/apply-settings.sh
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PATH="$PWD/tests/fake-gh:$PATH" FAKE_GH_LOG="$TMP/log"
failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

conforming_repo() {
  jq -n --arg visibility "$1" '{visibility: $visibility, default_branch: "main", allow_squash_merge: true, allow_merge_commit: false,
    allow_rebase_merge: false, allow_auto_merge: false, allow_update_branch: true, delete_branch_on_merge: true,
    squash_merge_commit_title: "PR_TITLE", squash_merge_commit_message: "BLANK", has_wiki: false, has_projects: false,
    has_discussions: false, security_and_analysis: {secret_scanning: {status: "enabled"}, secret_scanning_push_protection: {status: "enabled"}}}'
}
fixture() { # dir, visibility
  mkdir -p "$1"
  conforming_repo "$2" >"$1/repo.json"
  echo '{}' >"$1/vulnerability-alerts.json"
  echo '{"enabled": false, "paused": false}' >"$1/automated-security-fixes.json"
  echo '{"enabled": true}' >"$1/private-vulnerability-reporting.json"
  echo '{"state": "configured"}' >"$1/code-scanning_default-setup.json"
  echo '{"default_workflow_permissions": "read", "can_approve_pull_request_reviews": true}' >"$1/actions_permissions_workflow.json"
}
run() { : >"$FAKE_GH_LOG"; FAKE_GH_DIR="$1" bash "$SCRIPT" "${@:2}" 2>&1; }

fixture "$TMP/ok" public
out="$(run "$TMP/ok" owner/repo)" || fail "conforming repo exits 0"
[ ! -s "$FAKE_GH_LOG" ] && pass "conforming repo: no write" || fail "conforming repo wrote: $(cat "$FAKE_GH_LOG")"

fixture "$TMP/drift" public
jq '.allow_merge_commit = true | .has_wiki = true | .security_and_analysis.secret_scanning.status = "disabled"' \
  "$TMP/drift/repo.json" >"$TMP/r" && mv "$TMP/r" "$TMP/drift/repo.json"
rm "$TMP/drift/vulnerability-alerts.json"
echo '{"enabled": true, "paused": false}' >"$TMP/drift/automated-security-fixes.json"
echo '{"enabled": false}' >"$TMP/drift/private-vulnerability-reporting.json"
echo '{"state": "not-configured"}' >"$TMP/drift/code-scanning_default-setup.json"
echo '{"default_workflow_permissions": "write", "can_approve_pull_request_reviews": true}' >"$TMP/drift/actions_permissions_workflow.json"

out="$(run "$TMP/drift" --dry-run owner/repo)"
[ ! -s "$FAKE_GH_LOG" ] && pass "dry-run: no write" || fail "dry-run wrote: $(cat "$FAKE_GH_LOG")"
grep -q 'allow_merge_commit: true -> false' <<<"$out" && pass "dry-run shows the drift" || fail "dry-run output: $out"

run "$TMP/drift" owner/repo >/dev/null || fail "apply exits 0"
log="$(cat "$FAKE_GH_LOG")"
expect() { grep -qxF "$1" <<<"$log" && pass "writes: $1" || fail "missing write: $1 (log: $log)"; }
expect 'PATCH repo {"allow_merge_commit":false,"has_wiki":false,"security_and_analysis":{"secret_scanning":{"status":"enabled"}}}'
expect 'PUT vulnerability-alerts '
expect 'DELETE automated-security-fixes '
expect 'PUT private-vulnerability-reporting '
expect 'PATCH code-scanning/default-setup {"state":"configured"}'
expect 'PUT actions/permissions/workflow {"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}'
[ "$(wc -l <<<"$log")" -eq 6 ] && pass "nothing else written" || fail "unexpected writes: $log"

fixture "$TMP/private" private
rm "$TMP/private/private-vulnerability-reporting.json" "$TMP/private/code-scanning_default-setup.json"
jq 'del(.security_and_analysis)' "$TMP/private/repo.json" >"$TMP/r" && mv "$TMP/r" "$TMP/private/repo.json"
run "$TMP/private" owner/repo >/dev/null || fail "private repo exits 0"
[ ! -s "$FAKE_GH_LOG" ] && pass "private repo: public-only settings ignored" || fail "private repo wrote: $(cat "$FAKE_GH_LOG")"

out="$(run "$TMP/ok" --dry-run --default-branch v3 owner/repo)"
grep -q 'default_branch: main -> v3' <<<"$out" && pass "--default-branch overrides main" || fail "--default-branch output: $out"

run "$TMP/ok" --nope owner/repo >/dev/null
[ "$?" -eq 2 ] && pass "unknown option exits 2" || fail "unknown option did not exit 2"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
