# Final server/shared/persistence review — 2026-09-06

## Result

No new actionable P1/P2 defect was found in the reviewed server/shared/persistence changes. This is a bounded code and evidence review, not overall game release approval. Coordinator still owns combined regression and release acceptance.

Reviewed range: 4094e51 through **742b8cd77b39e2197f644be0efabc6d52cb641dd**. Isolated review branch: codex/review/smash-server-final-20260906. Only this document was changed. No source, automation flow, Studio state, live profile, purchase, registry or HQ record was mutated by this worker.

The diff contains 215 changed server lines, a 201-line shared catalog-model addition, and three inventory art fallback mappings. ProfilePersistence.lua and GameConfig.lua are unchanged from the baseline. The review followed the project skill and the ordinary Wayfinder review path; no external tracker was created.

## Reviewed behavior

| Area | Evidence and conclusion |
| --- | --- |
| Snapshot queue and lifecycle | Bootstrap lines 1637–1765 and Changed listeners around 2413. Only full UI snapshot publication is deferred; stat values change synchronously. A fixed 50 ms first deadline cannot be extended by continuing input. The queue is detached before flush, one leaderboard is shared per flush, initial/explicit responses remain immediate, and removed/unready players are skipped. PlayerRemoving discards pending references. The executable queue contract covers changes during a flush, two mock contributors, removal, readiness and recovery. |
| Saving versus UI snapshots | collectPlayerData at line 2915 reads authoritative current stats/boost expiries directly. It does not serialize the delayed client payload. Existing fenced single-flight save and receipt queues are independent of the new UI dirty queue. |
| Damage, reward and progression authority | Punch/hitDepthBlock and buyFist remain server-owned. Clients supply intent/catalog selection; server code reads actual character, server power, level, cleared depth, configured cost and ownership. The new Titan gate at hitBoss line 5505 uses RequiredDepth 75, retaining level 99 and rejecting before HP, participation, contribution or reward changes. Shared catalog geometry and art fallback code do not affect stats, prices or grants. |
| Receipt/purchase failure paths | ProcessReceipt at line 6502 still requires an eligible writable profile, resolves the configured ProductId, serializes the receipt operation and returns PurchaseGranted only after a durable fenced commit. Replays, product mismatches, ledger compaction, malformed state and grant headroom are covered by the unchanged executable persistence module. Failed live application requires safe reload and does not fabricate a second paid grant. Studio profiles stay ephemeral/nonwritable unless explicitly opted into live access. |
| Punch cancellation and physics races | CancelShake/CancelPunch/BindCharacterLifetime around 4507, Lunge at 5042 and Punch at 5228 invalidate ownership tokens and cancel tracked tweens. Delayed shake restoration checks token, anchored/live/attached state; detach, break and reset cancel it. Windup rechecks current character, token and life. Tween completion rejects cancellation or character replacement; delayed ownership release is token-guarded. Reset cancels before world restoration, and cancelled/character/lunge outcomes cannot fall through to another combat target. The earlier two P1 candidates in SMASH_SERVER_FIXES_20260906.md are resolved by these changes and the actual interruption-flow evidence below. |
| Fresh spawn and character replacement | The binder at 3545 covers existing and future players, waits boundedly for direct components/workspace membership, reacquires the current root, checks living Humanoid/current character/current binding, clears velocities and faces course direction -Z. Binding and same-character placement are idempotent; removal disconnects the listener. No yield occurs between final validation and assignment. Exact-source controls prove the old dead-character and replaced-root failures are rejected. |
| World CoinBoost route | The CoinBoost spec advertises ROBUX SHOP and selects Robux; the actual catalog product is configured on that page. The kiosk at 6789 only sends OpenMenu after readiness, known-showcase and throttle checks. It grants/spends nothing. Speed/Damage retain their existing page. Actual desktop keyboard/mouse routes and simulator touch presentation passed the Coordinator's flow. |
| Shared fist models | First-five identity is validated by saved name/style/icon/tier. GetCatalogSpec/BuildCatalogModel create bounded visual Part geometry with anchored, noncolliding, nonquery, nontouch and massless flags, then apply the existing sanitizer. No imported script, animation, force, reward or purchase behavior is introduced. Actual first-five R6/R15 equipment/motion/normal respawn parity passed on the current integrated visual implementation. |

## Offline verification executed

| Check | Result |
| --- | --- |
| server-snapshot-coalescing-contract.mjs | PASS: 16 exact-production queue assertions, 17 exact hitBoss gate assertions, 31 flow chunks compile |
| persistence-contract.mjs logic with temp-only runner adaptation | PASS: 31/31, including full server and persistence compile at O0/O1/O2, persistence analysis and exact module RunContractSelfTest |
| character-spawn-lifecycle-contract.mjs from Coordinator's 2d05f5d, --source-root pointing at reviewed tree | PASS: 39 exact-source cases, two expected old-source failures, 14 compiled weakening mutations, full server compile |
| honor-product-receipts-contract.mjs | PASS: 14/14 structural/catalog/receipt-flow checks |
| world-boost-showcase-contract.mjs | PASS: 11/11 structural/route checks |
| full-game-economy-boundaries-contract.mjs | PASS: 11/11 flow authority checks |
| honor-progression-contract.mjs | PASS: 19/19 |
| long-run-content-contract.mjs | PASS: 30/30; 16 regular fists and 16 normal pets |
| git diff --check | PASS |

Static/source and flow-structure checks above are not described as actual gameplay runs. The queue, boss gate, spawn cases and persistence self-test execute real extracted/unchanged production Luau with controlled dependencies.

The persistence script normally creates a temporary runner directory inside the repository. To honor the document-only write scope, a temporary copy of the script kept its source paths fixed to the reviewed tree and moved its runner into OS Temp. The exact ProfilePersistence module body was wrapped in a local function for self-test execution, avoiding Luau's cross-drive/short-path require-context error. The unmodified authoritative files still underwent O0/O1/O2 compile and module analysis. No product logic or assertion was changed; this adaptation does not validate filesystem require resolution itself. Coordinator can reproduce with the ordinary durable script in the integration checkout.

Commands used for the unmodified checks:

~~~powershell
node work/automation/scripts/server-snapshot-coalescing-contract.mjs
node work/automation/scripts/honor-product-receipts-contract.mjs
node work/automation/scripts/world-boost-showcase-contract.mjs
node work/automation/scripts/full-game-economy-boundaries-contract.mjs
node work/automation/scripts/honor-progression-contract.mjs
node work/automation/scripts/long-run-content-contract.mjs
node F:/Roblox/PuchWall-completion-20260906/work/automation/scripts/character-spawn-lifecycle-contract.mjs --source-root F:/Roblox/PuchWall-server-final-review-20260906
~~~

All Luau checks used the verified official local 0.737 toolchain. No Studio calls or network tools were used.

## Actual Coordinator evidence reviewed

The evidence is in the integration checkout under work/docs/evidence/:

- **smash-legacy-targeted-final-20260906/punchwall-map-progression.json: full PASS.** Fresh spawn, normal respawn without repeated relocation, actual concrete/high-tier gates, visible landmarks and console lifecycle all passed. This supersedes the earlier targeted2 run, which passed the spawn checks but failed a retired Cyber Gate lookup; that earlier whole flow was not a pass.
- **smash-source-sync-spawn-20260906.json: source identity matches the reviewed server.** UTF-8 length 434179, Adler32 1359971259. ProfilePersistence, GameConfig, FistVisualBuilder and InventoryViewModel fingerprints also match this review.
- **smash-integrated-targeted2-20260906/world-wall-reset.json: PASS.** Actual reset and client feedback, preserving player stats, with clean console/Animate lifecycle observations.
- **smash-integrated-targeted2-20260906/punchwall-radius-damage-shake.json: PASS.** Actual radius/falloff, facing-away rejection and exact grid return after shake.
- **smash-integrated-targeted2-20260906/world-boost-showcases.json: PASS.** Actual bounded models, shared server route/throttle, desktop E/mouse, ButtonX binding route and simulator touch with clean console. Some historical step labels still say Boosts; the Coin assertions inspect the actual Robux tab and CoinBoost card.
- **smash-integrated-targeted2-20260906/first-five-rig-parity.json: PASS.** Five actual regular fists on both R6 and R15, actual punch motion/recovery and saved equipment after normal avatar respawn.
- **smash-integrated-targeted2-20260906/premium-pet-gamepass-configuration.json: PASS.** Configured Roblox Game Pass metadata, world routes and displayed regional prices; this is not proof of a completed paid transaction.
- **smash-server-snapshot-coalescing-20260906.json: PASS.** Actual 480-stat-change burst and complete final client payload. This is a one-player transport measurement, separate from the two-player scheduler mocks.
- **smash-full-suite-20260906/punch-interruption-stability.json: PASS.** Actual shake detach/reset, reset during windup/travel, real remote fallback suppression and death/respawn. The relevant cancellation implementation is unchanged in the later reviewed server except unrelated spawn/kiosk changes.
- **smash-full-suite-20260906/boss-depth-authority.json: PASS.** Depth29/30/74 rejections, Lv99 requirement and exact Depth75 admission.
- **smash-full-suite-20260906/persistence-shutdown-single-flight.json: PASS.** Actual ephemeral lifecycle and post-stop console, without persistence warnings.

The initial full suite also had failures in obsolete shared-field HP and hybrid-physics flow expectations. No whole-suite pass is inferred from the focused evidence listed here. Remaining combined flow failures belong to Coordinator acceptance, including client/camera/legacy-input work outside this server review.

## Residual limits

- BLOCKED for release until Coordinator completes the required combined regression on the final integrated source. This document is eligible for integration, not an overall READY decision.
- Actual two-player concurrent damage/rewards, join/leave replication, network ownership and stressed full-server behavior were not run by this review. Two mock contributors in the queue test do not substitute for that evidence.
- PlaceId 0 ephemeral Studio runs do not prove published live DataStore reliability, cross-server lease contention, real Marketplace purchase completion, rejoin durability or production network latency. No live test purchase or profile write was performed.
- The 50 ms queue interval is a scheduler target, not guaranteed latency under load. Complete catalogs remain in snapshots. No FPS or physical-device performance gain is claimed.
- The bounded spawn discovery policy finishes after sequential five-second component/workspace waits; it is not an indefinite observer for an unchanged character after timeout. Controlled late-component cases and normal runtime respawn pass; arbitrary custom rig/loading behavior remains unverified.
- The prior endgame cost/pacing concern is a design/economy balancing limitation, not resolved by this authority patch. No new economy or content schedule was introduced and no retention/viral outcome is claimed.

## Source fingerprints (LF-normalized UTF-8 SHA-256)

- PunchWallBootstrap.server.lua: 9b57a40143c81460e87c50abb754b512a52868c70b436b2b0af8f56edb1e238b
- ProfilePersistence.lua: 36d21c0389a97bd213ebc4c31ae2bed7f3bcc51b7a6a632e6148cc6b9808f4e9
- GameConfig.lua: 641b1ff8a2b2f8afb6a199a323cd6e94a2285313ce1dd326b9149ecd5b03aec2
- FistVisualBuilder.lua: 634170d5fd2a0827c4c2144d9feaac3ac916783fc83ce7dc658d5734a56d81be
- InventoryViewModel.lua: a696c37178f9a582276a5953df798757862912b36b0ff0e5beebe028235f2d1c
