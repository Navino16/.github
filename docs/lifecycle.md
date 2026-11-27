# Lifecycle of a repository using the kit

What runs, and when, in a repository that adopted the kit (`templates/workflows/`). Dashed boxes are handled by the post-it maintenance scanner (design §7), not by GitHub.

## 1. A feature

```mermaid
flowchart LR
  push["Push feature/x<br/><i>no CI on a plain push</i>"] --> pr["Pull request to develop"]
  pr --> ci["CI (kit ci.yml)<br/>ci / Lint · ci / Build + type-check · ci / Test → Codecov"]
  pr --> other["CodeQL, Copilot review,<br/>repository-specific checks"]
  ci --> gate{"Required checks green<br/>+ 1 approval"}
  other --> gate
  gate --> squash["Squash merge<br/>one commit on develop"]
  squash --> dev(["→ 2. push on develop"])
  squash --> close["Close linked issues<br/>Fixes #12 in the PR body"]
```

## 2. A push on develop

```mermaid
flowchart LR
  push["Push on develop<br/><i>merged PR, release merge-back</i>"] --> build["Build Docker Image<br/>job ci (kit ci.yml) first"]
  build --> image["job build (kit build.yml)<br/>amd64 + arm64, manifest"]
  image --> ghcr(["ghcr.io<br/>develop, sha-xxxxxxx"])
  push -.->|"labels.yml changed<br/>(kit version bump)"| labels["Labels<br/>sync the kit's labels"]
```

## 3. Renovate

Monday before 6 am, vulnerability alerts at any time, every update waits one day after its release.

```mermaid
flowchart LR
  safe["Patch · digest · pin<br/>grouped: code / ci / docker"] --> safeci["PR + CI"] --> auto(["Auto-merged (squash)<br/>by Renovate"])
  minor["Minors<br/>one minor-dependencies PR"] --> minorci["PR + CI"] --> review["Review and merge"]
  minorci -.->|"green and stuck > 48 h"| t1["Maintenance ticket"]
  major["Majors<br/>label major"] -.-> t2["Maintenance ticket<br/>fix on its own PR"] --> review2["Review and merge"]
  style t1 stroke-dasharray: 5 5
  style t2 stroke-dasharray: 5 5
```

A merged pull request is a push on develop: section 2 follows.

## 4. A release

Git-flow, done locally by the maintainer (or by an agent after the maintainer's explicit yes) with `git flow release start/finish`: real merges, no squash. The branches and the tag are pushed through the admin bypass of the ruleset, as fast-forwards, never with `--force`.

```mermaid
flowchart LR
  rel["release/X.Y.Z from develop<br/>version bump"] --> main["Merge into main<br/><i>no kit CI on a push to main</i>"]
  main --> tag["Tag X.Y.Z, pushed"]
  tag --> build["Build Docker Image<br/>ci, then image"]
  build --> ghcr(["ghcr.io<br/>X.Y.Z, X.Y, latest"])
  build --> release(["GitHub release<br/>changelog from PR labels"])
  release --> discord(["Discord<br/>if the webhook is set"])
  tag --> back["Merge the tag back into develop"] --> dev(["→ 2. push on develop"])
```

## 5. Every week

Scheduled workflows run from the default branch only: a repository whose default branch is `main` gets `scheduled.yml` with its next release.

```mermaid
flowchart LR
  cron["Scheduled CI<br/>Monday 05:00 UTC or by hand"] --> ci["CI on develop and main<br/>in parallel, no Codecov"]
  ci --> green(["Green: nothing to do"])
  ci -.->|"red"| ticket["Maintenance ticket<br/>the environment broke a quiet repository"]
  style ticket stroke-dasharray: 5 5
```
