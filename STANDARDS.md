# Standards

The target every repository of Navino16 converges to. The kit's Renovate preset, workflows and CLAUDE.md block assume it.

## Target

| Topic | Standard | Accepted exceptions |
|---|---|---|
| Runtime | Node 26, pinned by `.nvmrc` | DUST (Bun) |
| Package manager | npm | DUST (bun), starledger (pnpm) |
| Modules | ESM | — |
| Lint / format | Biome | — |
| Tests | Vitest, Playwright for end-to-end | DUST (`bun test`) |
| Running TypeScript | tsx or native type stripping | — |
| Branches | full git-flow: `release/X.Y.Z`, version bump, merge into `main`, tag `X.Y.Z`, tag merged back into `develop` | — |
| Tags | `X.Y.Z`, no `v` | — |
| Commits | a single line, in English | — |
| Dependencies | Renovate through the kit's preset | — |

The framework (Next, Fastify…), the ORM (Prisma, Drizzle, TypeORM…) and the kind of application are not part of the standard.

## Convergence

- There is no migration project: repositories converge as they change.
- **Rule:** when a change touches something that departs from the target, migrate it to the standard instead of updating it. An ESLint major becomes a move to Biome; a Jest major becomes a move to Vitest.
- New projects start from the kit.
