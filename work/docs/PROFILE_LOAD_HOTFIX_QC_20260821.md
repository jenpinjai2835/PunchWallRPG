# Public Profile Load Hotfix QC — 2026-08-21

## Incident

The affected player was disconnected with `Your saved data could not be loaded safely. Please rejoin and try again.`

The production record was inspected through a temporary least-privilege Open Cloud credential. The record is valid DataVersion 8 data, migrates to `Current`, and accepts a fresh session lease in the executable persistence harness. The live record was not deleted, reset, or rewritten during diagnosis.

The exact disconnect was reproduced in Studio while editing the linked published place. Studio API access was disabled, but the previous runtime treated a linked place as production because its `GameId` and `PlaceId` were non-zero. The first lease `UpdateAsync` returned `StudioAccessToApisNotAllowed`; the fail-closed guard then removed the player.

## Remediation

- Every Studio session is ephemeral by default, including Studio opened against a published place.
- A deliberate live-data Studio test requires the explicit `ServerStorage.PunchWallAllowLiveDataStoreAccess=true` opt-in.
- Public Roblox servers remain durable because `RunService:IsStudio()` is false.
- Durable DataStore operations now have five bounded attempts with a 0.5-second exponential base delay before fail-closed removal.
- Runtime attributes expose the default-ephemeral policy and opt-in state for fail-closed automation.

## Acceptance

- Focused persistence contract: PASS 31/31.
- Linked published-place Studio flow: PASS 7/7 on Studio instance `dfcfb094-1c97-4365-81d8-22f53bafd763`, PlaceId `125255969070601`.
- Runtime profile: `EphemeralStudio`, ready, non-writable, live-data opt-in false.
- Runtime and post-stop console: no DataStore access error, profile-load failure, lease failure, or saved-data kick.
- Live production profile: valid and unchanged by this incident repair.

Machine-readable evidence is in `work/docs/evidence/profile-load-hotfix-20260821/`.

## Release Gate

The hotfix must be merged to `develop`, rebuilt with the exact nine-script allowlist, published as the next place version, and verified against the published artifact. The temporary Open Cloud credential used for diagnosis/publish must be deleted before handoff.
