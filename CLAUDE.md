# CLAUDE.md

This repository is the shared kit of Navino16's personal repositories (see `README.md`). It holds no application: only configuration that other repositories reference by tag. A mistake here breaks the CI of every repository at its next kit update.

## Commands

- `scripts/check.sh`: every check (Renovate configs, label sync and repository sync tests, actionlint on workflows and templates, labels of the issue forms, version references). Needs Docker and Node; `kit-check.yml` runs it on pull requests, along with `ci.yml` on the npm, pnpm and bun fixtures of `tests/fixtures/`.
- `scripts/apply-settings.sh [--dry-run] [--default-branch NAME] <owner/repo>`: aligns a repository's settings on `settings/repository.json`; `tests/fake-gh/gh` stands in for `gh` in its tests.
- `scripts/apply-ruleset.sh [--dry-run] [--e2e] <owner/repo>`: creates or updates a repository's `Main/Develop` ruleset from `rulesets/main-develop.json`.
- `scripts/sync-repo.sh [--apply block,ruleset,settings] <owner/repo>...`: reports how repositories drift from the kit and fixes only the parts named with `--apply`.
- `scripts/set-version.sh X.Y.Z`: moves `VERSION`, the block markers and every `@X.Y.Z` / `#X.Y.Z` reference of the README and the templates.

## Rules

- Public repository: nothing private, nothing specific to one person's tools.
- A change to a reusable workflow's inputs is a breaking change for its callers unless the new input has a default that keeps the old behavior.
- `claude-block.md` and the block below must stay identical; `scripts/check.sh` enforces it.
- Release process: see "Releasing the kit" in `README.md`. Plans live in `docs/plans/`.

<!-- repo-kit:start 1.2.1 -->
## Shared conventions (Navino16/.github)

This block comes from the [Navino16/.github](https://github.com/Navino16/.github) kit: change it there, never here.

- Every issue opened by an agent carries the `agent-log` label.
- Convergence: when a change touches something that departs from the target in [STANDARDS.md](https://github.com/Navino16/.github/blob/main/STANDARDS.md), migrate it to the standard instead of updating it (an ESLint major becomes a move to Biome).
- Git-flow: `develop` is the integration branch and the target of pull requests, `main` only receives releases. Work branches: `feature/<slug>`, `fix/<slug>`.
- Release, done by the maintainer, or by an agent only after the maintainer's explicit yes for this release, with git-flow (version tag prefix left empty): `git flow release start X.Y.Z` from `develop`, version bump, `git flow release finish X.Y.Z` (real merges into `main` and back into `develop`, tag `X.Y.Z`, no `v`), then `git push origin main develop --tags`. The push goes through the admin bypass of the ruleset and is a fast-forward: never `--force`; if it is rejected, pull `develop` and push again.
- Commits: a single line, in English.
- CI, Renovate, labels, issue and pull request templates come from the kit. A need specific to this repository goes through the inputs of the kit's workflows or after the `extends` of `renovate.json`; a change for every repository goes to the kit.
<!-- repo-kit:end -->
