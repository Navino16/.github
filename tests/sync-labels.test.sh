#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

SCRIPT=actions/sync-labels/sync-labels.sh
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

out="$(bash "$SCRIPT" --dry-run labels.json owner/repo)" || fail "dry-run on labels.json exits 0"
count="$(grep -c '^gh label create ' <<<"$out")"
[ "$count" -eq 13 ] && pass "13 labels applied" || fail "expected 13 label commands, got $count"
grep -q "'maintenance:post-it'" <<<"$out" && pass "maintenance:post-it applied" || fail "maintenance:post-it missing"
grep -q -- "-R owner/repo" <<<"$out" && pass "targets the given repository" || fail "repository not passed"

echo '[{"name":"bug","color":"zzz","description":"x"}]' >"$TMP/bad-color.json"
out="$(bash "$SCRIPT" --dry-run "$TMP/bad-color.json" owner/repo 2>&1)"
status=$?
[ "$status" -eq 1 ] && pass "bad color exits 1" || fail "bad color exited $status"
grep -q '^gh label' <<<"$out" && fail "bad color still applied labels" || pass "bad color applies nothing"

echo '[{"name":"bug","color":"d73a4a","description":"x"},{"name":"bug","color":"d73a4a","description":"y"}]' >"$TMP/dup.json"
bash "$SCRIPT" --dry-run "$TMP/dup.json" owner/repo >/dev/null 2>&1
status=$?
[ "$status" -eq 1 ] && pass "duplicate name exits 1" || fail "duplicate name exited $status"

long="$(printf 'x%.0s' {1..101})"
echo "[{\"name\":\"bug\",\"color\":\"d73a4a\",\"description\":\"$long\"}]" >"$TMP/long.json"
bash "$SCRIPT" --dry-run "$TMP/long.json" owner/repo >/dev/null 2>&1
status=$?
[ "$status" -eq 1 ] && pass "description over 100 chars exits 1" || fail "long description exited $status"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
