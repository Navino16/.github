# Fixtures shared by the tests that run against tests/fake-gh/gh.
conforming_repo() { # visibility
  jq -n --arg visibility "$1" '{visibility: $visibility, default_branch: "main", allow_squash_merge: true, allow_merge_commit: false,
    allow_rebase_merge: false, allow_auto_merge: false, allow_update_branch: true, delete_branch_on_merge: true,
    squash_merge_commit_title: "PR_TITLE", squash_merge_commit_message: "BLANK", has_wiki: false, has_projects: false,
    has_discussions: false, security_and_analysis: {secret_scanning: {status: "enabled"}, secret_scanning_push_protection: {status: "enabled"}}}'
}
settings_fixture() { # dir, visibility
  mkdir -p "$1"
  conforming_repo "$2" >"$1/repo.json"
  echo '{}' >"$1/vulnerability-alerts.json"
  echo '{"enabled": false, "paused": false}' >"$1/automated-security-fixes.json"
  echo '{"enabled": true}' >"$1/private-vulnerability-reporting.json"
  echo '{"state": "configured"}' >"$1/code-scanning_default-setup.json"
  echo '{"default_workflow_permissions": "read", "can_approve_pull_request_reviews": true}' >"$1/actions_permissions_workflow.json"
}
