#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

SCRIPT=scripts/sync-repo.sh
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PATH="$PWD/tests/fake-gh:$PATH" FAKE_GH_LOG="$TMP/log"
. tests/fake-gh/fixtures.sh
failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }
run() { : >"$FAKE_GH_LOG"; FAKE_GH_DIR="$1" bash "$SCRIPT" "${@:2}" 2>&1; }
has() { grep -qF -- "$2" <<<"$1" && pass "$3" || fail "$3: $1"; }
lacks() { ! grep -qF -- "$2" <<<"$1" && pass "$3" || fail "$3: $1"; }
written() { grep -F "$1" "$FAKE_GH_LOG" || true; }

file_json() { # path to a file whose content is served
  jq -n --arg content "$(base64 -w0 "$1")" --arg sha "sha-$(basename "$1")" '{content: $content, sha: $sha}'
}
serve() { # dir, repository path, local file
  file_json "$3" >"$1/contents_${2//\//_}.json"
}
conforming() { # dir: a repository in line with the kit
  settings_fixture "$1" public
  echo '{"object": {"sha": "develop-sha"}}' >"$1/git_ref_heads_develop.json"
  serve "$1" .github/repo-kit.md claude-block.md
  printf '# Project\n\n@.github/repo-kit.md\n' >"$TMP/claude-ok.md"
  serve "$1" CLAUDE.md "$TMP/claude-ok.md"
  for template in templates/workflows/*.yml; do
    serve "$1" ".github/workflows/$(basename "$template")" "$template"
  done
  echo '[{"id": 7, "name": "Main/Develop"}]' >"$1/rulesets.json"
  jq '. + {id: 7, source: "owner/repo", node_id: "RRS_7"}
    | .rules |= map(if .type == "pull_request" then .parameters.automatic_copilot_code_review_enabled = false else . end)' \
    rulesets/main-develop.json >"$1/rulesets_7.json"
}

conforming "$TMP/ok"
out="$(run "$TMP/ok" owner/repo)" || fail "conforming repository exits 0"
has "$out" "block: up to date" "block up to date"
has "$out" "CLAUDE.md: imports .github/repo-kit.md" "import found"
lacks "$out" "differs" "workflows and ruleset match, ignoring the fields GitHub adds"
has "$out" "settings: match" "settings match"
[ ! -s "$FAKE_GH_LOG" ] && pass "conforming repository: no write" || fail "wrote: $(cat "$FAKE_GH_LOG")"

conforming "$TMP/drift"
sed 's/repo-kit:start [0-9.]*/repo-kit:start 1.0.0/; s/single line/two lines/' claude-block.md >"$TMP/old-block.md"
serve "$TMP/drift" .github/repo-kit.md "$TMP/old-block.md"
{ printf '# Project\n\n'; cat "$TMP/old-block.md"; printf '\nOwn rules\n'; } >"$TMP/claude-pasted.md"
serve "$TMP/drift" CLAUDE.md "$TMP/claude-pasted.md"
sed 's#ci.yml@[0-9.]*#ci.yml@0.9.0#' templates/workflows/ci.yml >"$TMP/ci-old-ref.yml"
serve "$TMP/drift" .github/workflows/ci.yml "$TMP/ci-old-ref.yml"
{ cat templates/workflows/close-issues.yml; echo '# local change'; } >"$TMP/close-issues.yml"
serve "$TMP/drift" .github/workflows/close-issues.yml "$TMP/close-issues.yml"
rm "$TMP/drift/contents_.github_workflows_scheduled.yml.json"
jq '.bypass_actors[0].bypass_mode = "pull_request"' "$TMP/drift/rulesets_7.json" >"$TMP/r" && mv "$TMP/r" "$TMP/drift/rulesets_7.json"
jq '.allow_merge_commit = true' "$TMP/drift/repo.json" >"$TMP/r" && mv "$TMP/r" "$TMP/drift/repo.json"

for flags in "" "--dry-run"; do
  out="$(run "$TMP/drift" $flags owner/repo)"
  [ ! -s "$FAKE_GH_LOG" ] && pass "report only${flags:+ with $flags}: no write" || fail "report wrote: $(cat "$FAKE_GH_LOG")"
done
has "$out" "block: 1.0.0 -> $(cat VERSION)" "outdated block"
has "$out" "CLAUDE.md: does not import" "missing import"
has "$out" "workflows/ci.yml: matches the template (references the kit at 0.9.0)" "kit reference left to Renovate"
has "$out" "workflows/close-issues.yml: differs" "changed workflow"
has "$out" "+# local change" "workflow diff shown"
has "$out" "workflows/scheduled.yml: missing" "missing workflow"
has "$out" "ruleset: differs" "ruleset drift"
has "$out" "allow_merge_commit: true -> false" "settings drift"

out="$(run "$TMP/drift" --apply block owner/repo)" || fail "--apply block exits 0"
branch="fix/repo-kit-$(cat VERSION)"
has "$(written 'POST git/refs')" "\"ref\":\"refs/heads/$branch\",\"sha\":\"develop-sha\"" "branch created from develop"
block_put="$(written 'PUT contents/.github/repo-kit.md')"
[ "$(sed 's/^PUT [^ ]* //' <<<"$block_put" | jq -r .content | base64 -d)" = "$(cat claude-block.md)" ] \
  && pass "block written as the kit's" || fail "block content: $block_put"
has "$block_put" "\"sha\":\"sha-old-block.md\"" "block update carries the file sha"
claude="$(written 'PUT contents/CLAUDE.md' | sed 's/^PUT [^ ]* //' | jq -r .content | base64 -d)"
[ "$claude" = "$(printf '# Project\n\n@.github/repo-kit.md\n\nOwn rules')" ] \
  && pass "pasted block replaced by the import" || fail "CLAUDE.md: $claude"
has "$(written 'POST pulls')" "\"base\":\"develop\"" "pull request to develop"
lacks "$(cat "$FAKE_GH_LOG")" "rulesets" "--apply block leaves the ruleset"
lacks "$(cat "$FAKE_GH_LOG")" "PATCH repo" "--apply block leaves the settings"

touch "$TMP/drift/fail_POST_git_refs"
out="$(run "$TMP/drift" --apply block owner/repo)"
has "$out" "may already exist" "existing branch reported"
lacks "$(cat "$FAKE_GH_LOG")" "PUT contents" "existing branch: nothing pushed"
rm "$TMP/drift/fail_POST_git_refs"

out="$(run "$TMP/drift" --apply ruleset,settings owner/repo)" || fail "--apply ruleset,settings exits 0"
has "$(written 'PUT rulesets/7')" '"bypass_mode":"always"' "ruleset applied"
has "$(written 'PATCH repo')" '"allow_merge_commit":false' "settings applied"
lacks "$(cat "$FAKE_GH_LOG")" "git/refs" "--apply ruleset,settings leaves the block"

conforming "$TMP/e2e"
jq '.rules |= map(if .type == "required_status_checks"
  then .parameters.required_status_checks += [{context: "ci / E2E", integration_id: 15368}] else . end)' \
  "$TMP/e2e/rulesets_7.json" >"$TMP/r" && mv "$TMP/r" "$TMP/e2e/rulesets_7.json"
has "$(run "$TMP/e2e" owner/repo)" "ruleset: matches (with ci / E2E)" "E2E check kept"

conforming "$TMP/private"
rm "$TMP/private/rulesets.json" "$TMP/private/contents_CLAUDE.md.json"
out="$(run "$TMP/private" owner/repo)"
has "$out" "ruleset: unavailable" "private repository without rulesets"
has "$out" "CLAUDE.md: not in git" "CLAUDE.md outside git"

mkdir -p "$TMP/nodevelop"
out="$(run "$TMP/nodevelop" owner/repo)"
[ "$?" -eq 1 ] && pass "no develop branch exits 1" || fail "no develop branch: $out"

for args in "" "--nope owner/repo" "--apply workflows owner/repo" "--apply"; do
  run "$TMP/ok" $args >/dev/null
  [ "$?" -eq 2 ] && pass "usage error exits 2: '$args'" || fail "usage error did not exit 2: '$args'"
done

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
