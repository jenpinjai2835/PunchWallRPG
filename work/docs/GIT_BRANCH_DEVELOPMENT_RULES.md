# Punch Wall RPG: Git Branch Development Rules

## Purpose

This document defines the required Git workflow for developing Punch Wall RPG. It protects the playable Roblox place, keeps parallel work isolated, and makes every gameplay change traceable to a tested source change.

## Branch Model

| Branch | Role | Direct push |
| --- | --- | --- |
| `main` | Stable, approved baseline | No |
| `develop` | Shared integration branch for the next game build | No, except repository-maintenance changes approved by the project owner |
| `production` | Current release-ready game source and exported delivery artifacts | No |
| `feature/<short-name>` | New gameplay, UI, map, economy, or tooling work | Yes, by the branch owner |
| `fix/<short-name>` | Defect fix that targets `develop` | Yes, by the branch owner |
| `hotfix/<short-name>` | Urgent production fix, branched from `production` | Yes, by the branch owner |
| `docs/<short-name>` | Documentation-only change | Yes, by the branch owner |
| `release/<version>` | Release stabilization from `develop` | Yes, only for release fixes |

Use lowercase kebab-case branch names. Examples: `feature/pet-inventory`, `fix/mobile-punch-cooldown`, and `docs/branch-rules`.

## Starting Work

1. Update local references before creating a branch: `git fetch origin`.
2. For normal work, branch from the latest `origin/develop`.
3. For a production emergency, branch from the latest `origin/production` using `hotfix/`.
4. Keep one focused task per branch. Do not mix a wall-combat change with unrelated UI, art, or cleanup work.
5. Do not start from an uncommitted working tree. Stash or commit the current task first so that changes cannot be carried into the next branch by accident.

```powershell
git switch develop
git pull --ff-only origin develop
git switch -c feature/wall-reward-feedback
```

## Source And Asset Rules

- Treat `work/punch-wall-rpg/src/` as the authoritative gameplay source. Make Luau gameplay changes there, not only inside Roblox Studio.
- Treat `work/automation/flows/` as the authoritative automated test coverage. Add or update a JSON flow whenever a player-visible gameplay path changes.
- Keep design notes, test evidence, and release notes in `work/docs/`.
- Do not commit locks, logs, local screenshots, temporary tools, or generated test caches covered by `.gitignore`.
- Do not overwrite `outputs/PunchWallRPGPlayable_v1_final.rbxlx` from an unrelated branch. Commit a rebuilt place only when the corresponding source, automation flows, and verification result are included in the same pull request.
- Avoid editing the same `.rbxlx` file in parallel branches. It is difficult to merge; coordinate ownership first.

## Required Checks Before a Pull Request

Choose the smallest relevant test set while developing, then run the full regression for changes that affect gameplay, UI, map geometry, progression, or the final place.

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1"
```

For full validation:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Before testing an embedded place, sync the current source into Roblox Studio:

```powershell
node "F:\Roblox\PuchWall\work\automation\scripts\sync_rojo_source_to_studio.mjs"
```

Record in the pull request:

- What player behavior changed.
- Which files and systems are affected.
- Commands/flows run and their results.
- Whether `outputs/PunchWallRPGPlayable_v1_final.rbxlx` was rebuilt.
- Known limitations, blocked checks, or follow-up work.

## Review And Merge Rules

1. Push the task branch and open a pull request into `develop`.
2. Keep the pull request focused and resolve merge conflicts in the task branch.
3. Require a review for gameplay, data/economy, networking, progression, and final-place changes.
4. Use squash merge unless preserving a sequence of independently useful commits improves history.
5. Delete the remote task branch after merge; local branches may be deleted after confirming the merge is present in `develop`.
6. Never force-push shared branches (`main`, `develop`, or `production`).

## Release And Hotfix Flow

```text
feature/fix/docs branch -> pull request -> develop -> release/<version> -> production
                                              ^                         |
                                              |------ validated hotfix --|
```

- Create `release/<version>` from a tested `develop` when stabilizing a build.
- Only release fixes, verification updates, and release artifacts belong in a release branch.
- Merge an approved release to `production`, then merge it back to `develop` if needed to retain release-only fixes.
- Create a `hotfix/<short-name>` from `production` only for urgent live issues. After merging it to `production`, merge the same fix back into `develop`.

## Commit Rules

- Use imperative, scoped messages such as `feat(walls): add break reward feedback` or `fix(ui): prevent mobile punch double tap`.
- Do not use vague messages such as `update`, `fix stuff`, or `wip` for merge-ready commits.
- Keep generated binary output and its source changes together only when the output was deliberately rebuilt and verified.
- Never commit credentials, Roblox cookies, API tokens, or local configuration secrets.

## Definition Of Done

A task is complete only when its source is committed, appropriate automation has passed (or is documented as blocked), the pull request is reviewed and merged to `develop`, and any release artifact change is traceable to the source and test evidence that produced it.
