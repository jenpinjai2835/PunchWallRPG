# Verified final visual capture

Agent 3, 2026-09-06. This bounded task adds only `work/automation/scripts/studio-final-visual-capture.mjs` and this document after immutable profiler handoff `b80d770`. It does not change the profiler, source, flows, final place, or Studio. The Coordinator owns integration and actual capture after the frozen full regression and rebuilt-artifact reopen.

The prototype in `work/tools/smash-final-visual-capture.mjs` was not ready to establish final artifact visual evidence: it recorded a disk hash without tying it to a build manifest/native reopen proof, did not validate SetStats or seed readback, trusted several unverified navigation acknowledgements, and captured some images before checking the intended state. A combined cleanup block could skip simulator reset if Play stop failed. Source preflight also ran outside the protected cleanup/evidence path.

The durable tool closes those gaps. **No Studio execution, actual screenshots, frame-rate measurements, or completed visual review are claimed by this handoff.**

## Exact supported capture set

Two device configurations each capture five actual MCP images: fresh HUD, Shop, Inventory Fists, Inventory Pets, and Settings. The tool never generates, redraws, downloads, or edits game artwork.

- Desktop stops device simulation and requires its active device to be `default`. The real client viewport must be at least 900×600; maximize the Studio game viewport before running. Its actual dimensions are recorded, not labelled 1920×1080 without evidence.
- Phone selects exactly one device whose `IsCustom` is false and normalized built-in name is `iPhone 17 Pro`. It sets LandscapeLeft/FitToWindow, verifies the active device id and 874×402 simulator resolution, and requires that exact client camera viewport before every phone image. It does not create a custom phone with the same dimensions and label it built-in.

MCP PNG dimensions are recorded independently. A scaled capture or Studio chrome may give the image dimensions different from the simulator's logical raster. Built-in emulation does not establish physical-phone GPU performance.

## Binding, fixtures, and screen guards

The tool reuses the profiler's tested argument, artifact, actual-live-source, seed, and navigation interfaces. Its preflight independently reads current local sources and the canonical artifact, validates exact inventories, build manifest byte/raw/normalized hashes, canonical/validation-copy byte equality, and the successful native reopen proof's same Studio id/name/local place/artifact hash. It runs the actual XML source verifier and tracked read-only live source checker. These checks run before MCP capture setup; HEAD is reported only as `repositoryCommit`, separate from `artifactBuildCommit`.

After capture and cleanup, it repeats live source equality and the disk/source/manifest/native-proof/tool dependency binding. The prior native reopen proof is a required external fact established by the Coordinator; equal source and a filename alone do not prove all non-code DataModel content came from that artifact. Do not sync after the verified reopen.

Fresh HUD capture first requires the strict ephemeral server guard and actual starter Snapshot Power=15, Coins=0. Seeding then uses the shared profiler's exact loaded-catalog validation, successful Reset/SetStats, actual RPGStats and server Snapshot readback, replicated client values, Inventory readback, and two actual equipped companion models. The seed is five first-tier catalog fists, Forest Pup twice and Miner Cat once in inventory, and Forest Pup/Miner Cat equipped. Three pet copies are not labelled three companions.

Every image is bracketed by successful actual client Snapshots. Each bracket verifies the viewport, safe-HUD dimensions, and requested screen. Shop must be visible on its Fists page. Inventory must show the exact requested category and seeded name/count set; its current safe-area/bounds/text-fit/no-overlap layout flags must pass. Settings must expose all seven options plus Done as visible, active, selectable, readable controls at least 44×44. Fresh HUD must have no open menus. The client viewport cannot change between the image's pre/post checks.

The tool routes through existing controllers and records their actual outcomes. These captures supplement the strict native gesture regression; automation navigation is not presented as a physical input test. The PNG reader rejects tool errors, missing/multiple images, wrong MIME, invalid base64/signature/header, degenerate dimensions, and missing IEND. This is a capture envelope check, not an independent full PNG decoder or an artistic judgment. Saved bytes come directly from the actual `screen_capture` image block.

## Evidence and cleanup

The fresh evidence directory is reserved without replacing existing evidence. Each PNG and manifest uses exclusive creation; partial evidence remains available on failure. Each capture records its SHA256, bytes, actual image dimensions, pre/post state and timestamps. Image writes occur only after both screen-state checks pass.

Play stop, simulator reset to default, and MCP close are attempted independently. A failed stop cannot skip reset/close; failed reset cannot skip close. No image/manifest write failure can bypass this cleanup. Primary and cleanup failures are preserved separately, and any failed guard, tool, cleanup, postflight or evidence write returns a nonzero process exit. Success requires both devices, all ten images, successful cleanup and unchanged postflight binding.

The tool deliberately ends with device simulation stopped/default rather than leaving the phone emulator enabled. OS-forced process termination cannot guarantee asynchronous cleanup; the Coordinator must stop that owned Play session and restore simulator default if the process is forcibly killed.

## Offline verification

```powershell
node --check work/automation/scripts/studio-final-visual-capture.mjs
node work/automation/scripts/studio-final-visual-capture.mjs --self-test
git diff --check
```

PASS: 26 visual-tool Node checks, 13 Luau snippet compilations, and 42 assertions executing the exact generated screen-state guards with deterministic mocks. The latter cover all ten accepted device/screen pairs and reject wrong screen/category, wrong viewport, missing seed names, invalid Inventory layout, and undersized/unreadable Settings controls. Cleanup injections prove independent attempts. In-memory mock image headers exercise metadata rejection only and are never saved as visual evidence.

The self-test also runs the unchanged profiler dependency contract: 52 Node checks, eight compiled snippets, and 31 exact ephemeral/collector assertions. These include wrong artifact/source/Studio identity, stale native proof, invalid live equality, unsafe fixture states and cleanup failures. Studio was not accessed by either test.

## Coordinator command after final native reopen

Integrate `b80d770` before this tool and only after the frozen suite ends. Save the JSON output of the successful native `run-final-artifact-regression.ps1` run, not `-StaticOnly`, and use its same actual reopened Studio id:

```powershell
node work/automation/scripts/studio-final-visual-capture.mjs `
  --studio-id 'ACTUAL_REOPENED_STUDIO_ID' `
  --studio-name 'PunchWallRPGPlayable_v1_final_validation.rbxlx' `
  --evidence-leaf 'smash-final-artifact-visuals-20260906' `
  --manifest 'outputs/PunchWallRPGPlayable_v1_final.build.json' `
  --reopen-proof 'work/docs/evidence/smash-final-artifact-native-reopen-20260906.json'
if ($LASTEXITCODE -ne 0) { throw 'Visual capture failed; inspect manifest and cleanup results' }
```

The ten actual images then require visual inspection by the Coordinator for readability, framing, art quality and overlap; automation flags cannot replace that review. Actual capture and visual acceptance remain **BLOCKED pending rebuilt/reopened artifact execution and image review**.
