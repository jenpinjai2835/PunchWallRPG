# Punch Wall RPG Repository Guide

Use the project skill at `.codex/skills/punch-wall-rpg-development/SKILL.md` for Roblox gameplay, visual, automation, and release work. Its references preserve the relevant rules distilled from the original gameplay-design task without importing unrelated generic skills.

## Mandatory Agent HQ Workflow (Non-Negotiable)

Every actionable user request in this repository must be registered in Agent HQ before execution and remain traceable there through completion.

- The Coordinator owns intake, acceptance criteria, risk classification, planning, task decomposition, dependency order, assignment, integration, final verification, and handoff.
- Agents 1-3 are interchangeable workers. Assign them by current fit and availability, not by permanent role.
- Every active subtask must have exactly one owner plus an explicit scope, allowed paths, checklist, dependencies, and integration order. Two agents must never edit the same file concurrently.
- Dependency-blocked work stays `WAITING` and may become `WORKING` only after its prerequisite is verified complete. Agents must report meaningful status and checklist changes to Agent HQ.
- Implementation work uses isolated task branches/worktrees. Preserve every dirty tree, never reset or clean another task's work, and serialize shared-file handoffs through the Coordinator.
- A worker's completed subtask is only eligible for integration. The overall task is not `READY` until the Coordinator integrates in dependency order, runs the risk-appropriate combined regression, records evidence, and confirms no known in-scope defect remains.
- Failed, skipped, stale, or unavailable required checks must be reported as `BLOCKED`, never silently treated as passing. Do not claim absolute bug-free software; report the checks that passed and that no known in-scope defect remains.
- Even atomic tasks must be logged. The Coordinator may execute one without delegation only when splitting it would create more coordination or conflict risk than value, and must record that reason. Validation and status reporting still apply.
- After any Codex, Agent HQ, or machine restart, reconcile dashboard state with live sessions, Git state, durable files, and test evidence before resuming. A stale `WORKING` status is not proof that work occurred.
- Only an explicit user instruction for a specific task may override this workflow. Silence, urgency, or a restart is not an override.

The complete lifecycle, conflict controls, quality gates, status contract, and recovery procedure are defined in `work/docs/AGENT_HQ_MANDATORY_WORKFLOW.md`.

## Source Of Truth

- Author gameplay in `work/punch-wall-rpg/src/`.
- Keep test coverage in `work/automation/flows/` and project evidence in `work/docs/`.
- Treat `outputs/PunchWallRPGPlayable_v1_final.rbxlx` as a verified output artifact, not the authoritative source.
- Follow `work/docs/GIT_BRANCH_DEVELOPMENT_RULES.md` for branching, review, and release work.

## Required Safeguards

- Validate rewards, damage, purchases, and progression on the server.
- Keep imported Creator Store assets visual-only and sanitize all imported code/behavior.
- Update or add an automation flow for changed player-visible behavior.
- Run the applicable regression before merge and record any blocked check or known limitation.
- Preserve unrelated in-progress working-tree changes.
