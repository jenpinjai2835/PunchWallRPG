# Functional Full-Game Playtest Matrix

- Commit: `fb73c57baa0049e7e3ca284adf4b439f81571fc1`
- Branch: `codex/feature/inventory-integration`
- Studio source sync: `C:\Temp\functional-full-game-sync-fb73c57.stdout.json`
- Main automation evidence: `C:\Temp\functional-full-game-fb73c57-20260719-063154`
- Targeted rerun evidence: `C:\Temp\functional-full-game-reruns-fb73c57-20260719-065144`
- Real-input method: Roblox Studio MCP `user_mouse_input` and `user_keyboard_input`

## Automation Matrix

- Main batch: 25 flows, 18 passed, 7 failed.
- Targeted reruns: 16 executions, 11 passed, 5 failed.
- Confirmed passing coverage includes onboarding, training, punch/break/reward/reset, progression/world transition, fist shop, premium-pet Studio mode, inventory persistence, spin UI, release expansion UI, inventory UI (51/51), critical UI/model checks, rebirth/boss, and high-power Studio mode.

## Real-Input Matrix

| Area | Result | Evidence |
| --- | --- | --- |
| Inventory open/close | PASS | Inventory HUD icon opened the modal and close button hid it. |
| Inventory category/search/rarity/select | PASS | Fists/Pets category, `starter` search, clear, Common/All rarity, and card selection changed the live inventory snapshot. |
| Fist purchase fail-closed | PASS | Boxing Glove at 0 coins left authoritative state unchanged. |
| Fist purchase and equip | PASS | At 100000 coins the visible BUY button purchased Boxing Glove for 180; Starter and Boxing visible EQUIP actions changed `EquippedFist` authoritatively. |
| Pet equip/unequip | PASS | Visible inventory actions changed `EquippedPetsJSON` between `[]` and `["Crystal Fox"]`. |
| Pet lock/unlock | PASS | Visible inventory actions changed `LockedPetsJSON` to include and then remove `slot:1`. |
| Pet delete confirmation | FAIL | The visible Delete button emitted `Activated`, but the Inventory UI did not arm confirmation, did not change its label, and did not mutate authoritative inventory. |
| Pet fusion | FAIL | With two unlocked Crystal Fox copies the visible active `FUSE 2` button did not mutate `PetInventoryJSON`. |
| Premium unavailable path | FAIL (feedback) | At unpublished `PlaceId=0`, the visible premium-pet button correctly did not grant ownership, but no unavailable/setup feedback appeared. |
| Spin | PASS | Visible Spin button and Spin Now produced one authoritative result, `Power400`, then closed normally. |
| Punch | PASS | Visible punch and keyboard `F` produced windup/contact timing, recovered to Idle, damaged the nearest wall, and awarded coins on the server. |
| Jump keyboard | FAIL | Controlled grounded retry: Space produced `maxY - y0 = 0`, never entered Jumping/Freefall. |
| Jump HUD button | FAIL | Controlled grounded retry: visible ActionJump updated `LastJumpRequestedAt` but produced `maxY - y0 = 0` and never entered Jumping/Freefall. |
| Tasks | PASS (controlled retry) | Daily Supply visible CLAIM awarded 600 coins and changed to CLAIMED; City Cleanup and Five Minute Supply correctly showed WAIT after reset. |
| Settings | FAIL | First setting action works, but rebuilt Motion/Sound controls become no-op until the Settings tab is reopened. |
| UI scale | COVERAGE GAP | Buttons named `Scale0.8` and `Scale1.2` cannot be targeted by the current instance-path parser; coordinate retry did not change selection. |
| Rebirth gate | PARTIAL | Gate text and authoritative rejection were correct; no dynamic unavailable feedback could be observed. |

## Confirmed Defects / Gaps

1. Controlled keyboard and HUD jump requests do not move a healthy, grounded R15 character despite `JumpPower=50`.
2. Inventory Delete button can receive `Activated` while its Inventory UI action callback is disconnected/stale.
3. Active pet `FUSE 2` UI does not dispatch an authoritative fusion.
4. Settings action controls become stale after the first page rebuild until the tab is reopened.
5. Unpublished premium purchase and rejected rebirth paths lack clear player-facing unavailable feedback.
6. `iteration04-armory-pets-feedback` deterministically expects missing fixture `Workspace.PunchWallRPG.Polish.City Decor.Boxing Glove Gauntlet Palm`.
7. Default character `Animate` may intermittently infinite-yield on `PlayEmote`.
8. Some automation flows intermittently race Play startup before the Server DataModel is available.
9. Regression wrapper scripts hard-code the base repository flow path instead of the active integration worktree.
10. UI scale 80/120 remains a tool coverage gap because dotted instance names cannot be addressed through the current input-path parser.

The exact Studio console export is stored beside this file. Console errors naming `AssistantCommand` were caused by read-only QC inspection commands and are not runtime game-script stack traces.
