# Punch Wall RPG Repository Guide

Use the project skill at `.codex/skills/punch-wall-rpg-development/SKILL.md` for Roblox gameplay, visual, automation, and release work. Its references preserve the relevant rules distilled from the original gameplay-design task without importing unrelated generic skills.

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
