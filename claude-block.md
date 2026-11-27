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
