# Navino16/.github

Shared kit of Navino16's personal repositories: one place for the Renovate preset, the CI and build workflows, the labels, the issue and pull request templates and the standards every repository converges to.

Being the account's `.github` repository, it also gives its [default community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) (issue forms, pull request template, security policy) to every repository that has none of its own.

Repositories always reference a release tag (`X.Y.Z`) of the kit, never a branch. Renovate moves these references in a single `repo-kit` pull request.

What runs and when in an adopting repository: [docs/lifecycle.md](docs/lifecycle.md).

## Contents

| Path | What it is |
|---|---|
| `default.json` | Renovate preset: one-day minimum release age, patch, digest and pin updates grouped and auto-merged, minors grouped in one pull request to review, majors labelled `major`, vulnerability alerts at any time, dependency dashboard |
| `.github/workflows/ci.yml` | Reusable CI: Lint, Build (build + type-check), Test (with Codecov), optional E2E (Playwright), for npm, pnpm or bun |
| `.github/workflows/build.yml` | Reusable build: multi-platform Docker image on ghcr.io, GitHub release with a changelog on tags, Discord notification |
| `.github/workflows/close-issues.yml` | Reusable workflow closing the issues a pull request references with a closing keyword (`Fixes #12`) when it merges into `develop`: GitHub only does it for the default branch. Bot pull requests, pull request numbers and closed issues are skipped |
| `labels.json`, `actions/sync-labels` | Shared labels and the action that creates or updates them in a repository (it never deletes a label) |
| `.github/ISSUE_TEMPLATE`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/SECURITY.md` | Default community health files |
| `templates/workflows/` | The caller workflows a repository copies |
| `claude-block.md` | The shared block of every repository's `CLAUDE.md` |
| `STANDARDS.md` | The target stack and the convergence rule |
| `settings/repository.json`, `scripts/apply-settings.sh` | Repository settings shared by every repository (squash-only merges with the pull request title, branch cleanup, Dependabot alerts without Dependabot pull requests, secret scanning, private vulnerability reporting, CodeQL, read-only default token) and the script that applies them |
| `scripts/sync-repo.sh` | Reports how repositories drift from the kit (block, caller workflows, ruleset, settings) and fixes the parts named with `--apply` |
| `rulesets/main-develop.json`, `scripts/apply-ruleset.sh` | The branch ruleset of every public repository, exported from Varken, and the script that applies it |

### `ci.yml` inputs

| Input | Default | |
|---|---|---|
| `package-manager` | `npm` | `npm`, `pnpm` (version from `packageManager` in `package.json`) or `bun` |
| `working-directory` | `.` | Directory holding `package.json` |
| `ref` | event commit | Ref to check out |
| `node-version-file` | `.nvmrc` | Node is not set up when the file is missing |
| `bun-version` | `latest` | |
| `lint-script`, `typecheck-script`, `build-script`, `test-script` | `lint`, `typecheck`, `build`, `test:coverage` | An empty string skips the step |
| `e2e`, `e2e-script` | `false`, `test:e2e` | |
| `codecov` | `true` | Uploads only when the `CODECOV_TOKEN` secret exists |
| `coverage-files`, `junit-files` | `.reports/coverage/cobertura-coverage.xml`, `.reports/junit.xml` | |

### `build.yml` inputs

| Input | Default | |
|---|---|---|
| `image-name` | `ghcr.io/<owner>/<repo>` | |
| `arm64` | `true` | Also build `linux/arm64` on the `ubuntu-24.04-arm` runner; set `false` in a private repository if that runner is not available to it |
| `release-title` | repository name | Title of the Discord notification |
| `discord-role-id` | none | Role mentioned in the notification; it is sent only when the `DISCORD_RELEASES_WEBHOOK` secret exists |

## Adopting the kit

In the repository, on a branch from `develop`:

1. `renovate.json` (or `.github/renovate.json`): `"extends": ["github>Navino16/.github#1.2.1"]`, followed only by the rules specific to the repository. Drop `.github/dependabot.yml` if any (keep Dependabot *alerts* enabled: Renovate reads them).
2. Copy the workflows of `templates/workflows/` into `.github/workflows/` and remove the ones they replace. Adjust the inputs to the repository (package manager, scripts, `e2e`, `arm64`…). A repository without a Docker image skips `build.yml`; a repository whose default branch is not `develop` adapts the branches.
3. Delete `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md`, unless the repository has a real need of its own: a single template of its own disables every default issue template.
4. Copy `claude-block.md` to `.github/repo-kit.md`, and in `CLAUDE.md` replace what it covers (git workflow, commit rules) with the line `@.github/repo-kit.md`, which imports it. When `CLAUDE.md` is not in git, add the line to the local copy: `.github/repo-kit.md` is versioned either way.
5. Codecov: the targets, precision and comment layout live in the Codecov global YAML of the account, not in this repository. The account is on Codecov's free Developer plan, which only posts `codecov/patch`: there is no `codecov/project` status or project coverage in the comment, so `codecov/project` cannot be a required check. Keep a `codecov.yml` only for the repository's own exceptions, and repeat the global entries of any list it extends (`ignore`): Codecov merges the repository YAML into the global one key by key, but does not document whether lists are merged or replaced.
6. Align the repository settings: `scripts/apply-settings.sh --dry-run Navino16/<repo>` lists the drift, the same command without `--dry-run` applies it (`--default-branch NAME` when the default branch is not `main`). Check first that the repository's own workflows declare their `permissions:`, since the default token becomes read-only. The Actions right to create and approve pull requests is left as it is.
7. After the pull request's checks pass, apply the shared ruleset from a clone of the kit: `scripts/apply-ruleset.sh [--e2e] Navino16/<repo>` (`--dry-run` prints it). It creates or replaces the `Main/Develop` ruleset: protected `main` and `develop`, squash-only pull requests with one approval and resolved conversations, required checks up to date with the target branch: `ci / Lint`, `ci / Build`, `ci / Test` (plus `ci / E2E` with `--e2e`) and CodeQL, Renovate allowed to bypass. A private repository cannot have rulesets without GitHub Pro.
8. Once merged, check that the `Labels` workflow ran and that the Dependency Dashboard shows no configuration error.

The Renovate bypass of the ruleset must be `always` (not `pull_request`), and the repository should only allow squash merges: Renovate then merges the grouped patch, digest and pin updates on its own.

## Keeping repositories in sync

`scripts/sync-repo.sh <owner/repo>...`, run from `main` after a kit release, reports for each repository:

- the block: `.github/repo-kit.md` against `claude-block.md`, and its import in `CLAUDE.md`;
- the caller workflows against `templates/workflows/`, leaving aside the kit references Renovate moves;
- the ruleset and the settings, as `apply-ruleset.sh` and `apply-settings.sh` would change them.

It writes nothing unless `--apply` names the parts to fix, such as `--apply block,settings`. `block` pushes `fix/repo-kit-X.Y.Z` and opens a pull request to `develop`, which also swaps a block pasted in `CLAUDE.md` for the import; `ruleset` and `settings` run the two scripts. Caller workflows are never rewritten: each repository sets its own inputs in them.

## Releasing the kit

The kit follows the release rule of the shared block:

1. `git flow release start X.Y.Z`, then `scripts/set-version.sh X.Y.Z`, `scripts/check.sh` and a commit.
2. `git flow release finish X.Y.Z`, which merges into `main`, tags `X.Y.Z` and merges back into `develop`.
3. `git push origin main develop --tags`, never `--force`, then `gh release create X.Y.Z --generate-notes`.
