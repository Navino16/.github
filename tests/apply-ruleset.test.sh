#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

SCRIPT=scripts/apply-ruleset.sh
failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }
contexts() { jq -r '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' | sort | tr '\n' ' '; }

out="$(bash "$SCRIPT" --dry-run owner/repo 2>&1)" || fail "dry-run exits 0"
[ "$(contexts <<<"$out")" = "CodeQL ci / Build ci / Lint ci / Test " ] && pass "default required checks" || fail "default checks: $(contexts <<<"$out")"
[ "$(jq -r .name <<<"$out")" = "Main/Develop" ] && pass "ruleset name" || fail "ruleset name"

out="$(bash "$SCRIPT" --dry-run --e2e owner/repo 2>&1)"
[ "$(contexts <<<"$out")" = "CodeQL ci / Build ci / E2E ci / Lint ci / Test " ] && pass "--e2e requires ci / E2E" || fail "--e2e checks: $(contexts <<<"$out")"

bash "$SCRIPT" --dry-run --nope owner/repo >/dev/null 2>&1
[ "$?" -eq 2 ] && pass "unknown option exits 2" || fail "unknown option did not exit 2"

bash "$SCRIPT" --dry-run >/dev/null 2>&1
[ "$?" -eq 2 ] && pass "missing repository exits 2" || fail "missing repository did not exit 2"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
