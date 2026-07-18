# PunchWall RPG

Roblox Studio project for the Hero City punching and depth-progression game.

## Project layout

- `outputs/` - playable Roblox place files and delivery artifacts
- `work/punch-wall-rpg/` - Rojo source for server, client, and shared modules
- `work/automation/` - recorded Studio automation flows and sync/build scripts
- `work/docs/` - design, QC, and implementation documentation
- `work/assets/` - generated visual assets used by the project
- `.codex/skills/punch-wall-rpg-development/` - project-specific Codex workflow and references

Repository-wide working rules are in `AGENTS.md`; Git workflow rules are in
`work/docs/GIT_BRANCH_DEVELOPMENT_RULES.md`.

## Source workflow

1. Edit source under `work/punch-wall-rpg/src/`.
2. Sync source into the open Roblox Studio place with `work/automation/sync-source-to-studio.ps1`.
3. Run the relevant recorded flows under `work/automation/flows/`.
4. Embed the tested source into `outputs/PunchWallRPGPlayable_v1_final.rbxlx` with `work/automation/embed-source-into-rbxlx.ps1`.

The project uses visual-only Creator Store assets. Imported assets are sanitized before use and gameplay logic remains in the project source.
