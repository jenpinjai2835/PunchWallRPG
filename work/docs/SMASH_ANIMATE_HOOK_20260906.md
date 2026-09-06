# Animate PlayEmote lifecycle repair — 2026-09-06

The default Animate script can attach its sole emote callback to the owned fallback created during a partial character bootstrap. Previously, a later engine child caused the repair to destroy that already-bound fallback and retain an unbound replacement. `Invoke('wave')` then waited indefinitely. The fix preserves both objects and selects an endpoint only after a non-visible readiness response.

Source handoff: `f72175ba9d6aa6eb92b319746274a2f925b707f9`, based on `0b061fbae8f80b120054a82462108818535c3c05`. Only the initial Animate repair block changed. The normalized client prefix and suffix outside that block are identical to the base. Main-client ownership was released to the Coordinator after the source-only commit; the subsequent contract/document commit makes no further source edits.

## Evidence and limits

The original full-suite `world-wall-reset` failure reported one BindableFunction, `repaired=true`, one invocation attempt and `invokeCompleted=false` after the bounded caller wait. The later `smash-emote-diagnostic-20260906.json` captured a healthy R15 engine hook with `wave=true`, plus the actual Animate source. That source contains one `script:WaitForChild('PlayEmote').OnInvoke` assignment, followed by its animation loop, with no late-child rebinding path.

Executing that captured assignment together with the old production repair reproduces the failing schedule: fallback at 0.35 seconds; native assignment to fallback; late child at 0.50; fallback destroyed; retained child has no callback. Early native arrival and native binding after late adoption succeed. This proves a source-level race; the original failed Studio sample did not capture enough hook-identity attributes to prove that exact interleaving occurred in that particular run.

Roblox documents that a BindableFunction invocation remains suspended if no callback is ever assigned. It also cautions that siblings sharing a name can resolve to an undesired object. The fix therefore tests both oldest/newest selection during the transient duplicate interval instead of assuming child arrival order proves callback ownership. [BindableFunction reference](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/BindableFunction.yaml), [Instance reference](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Instance.yaml).

Captured full native source SHA-256: `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`. Exact extracted binding SHA-256: `3e6b8779e88d1feee2511690bdd9879a1496c59b7ebd10ae560996964b49f40a`. The binding is embedded unchanged in the portable contract, avoiding a dependency on an untracked Studio evidence file.

## Behavior

- The first selected public hook remains the endpoint while late same-name BindableFunctions move into an owned `PunchWallLatePlayEmoteHooks` folder. Their instances, names and callbacks survive.
- A reserved unknown emote string probes readiness without playing an animation. The newly created fallback returns a unique private sentinel for this probe and ordinary `false` for normal calls. The captured default callback returns `false` or `nil` for the unknown name.
- If the held object received the native callback before a deferred ChildAdded handler, and the public hook is still pending, the ready object becomes public; the old pending endpoint moves into holding. If the public callback is already ready, it remains intact.
- There is exactly one OnInvoke assignment in the repair, initializing the new unparented fallback. The code does not read or copy callbacks, replace callbacks on existing objects, destroy hooks, or restart Animate.
- Each probe has a 0.12-second cancellation deadline sampled at 0.02-second intervals. Reconciliation uses a two-second retry window; a final in-flight probe/check can finish after that window, subject to normal scheduler latency. It is event driven, with no render loop or permanent polling.
- Discovery expires after six seconds. One Animate.ChildAdded guard remains for the character lifetime, so arrivals after six seconds are still handled. Character removal, CharacterRemoving, respawn and Animate removal disconnect listeners and cancel owned probe/reconciliation tasks.

The readiness protocol is specific to the captured default Animate behavior: an unsupported name returns promptly with `false` or `nil`. An arbitrary custom callback that hangs, errors, returns a different protocol, or replaces callbacks repeatedly is not certified by this change. A readiness response also does not prove animation asset access; the real Studio `wave=true` assertion remains required. An unbound shim is never treated as ready merely because it exists.

## Validation

Run from a repository root:

```powershell
node work/automation/scripts/animate-hook-lifecycle-contract.mjs
```

The script supports `--source-root`, `--baseline-ref` and `--luau` (or `LUAU_QA_EXE`). It reads production source and executes in memory without writing fixtures or changing the place.

PASS:

- Full client Luau compilation.
- 19 executable scheduler scenarios: early native, late native, fallback takeover, deferred callback before/after binding, oldest/newest transient lookup, WaitForChild suspension, nil native response, rejected unexpected response, multiple late hooks, late arrivals after six seconds, timeout cancellation, character removal/CharacterRemoving/respawn, Animate removal, six-second discovery expiry and preexisting duplicate recovery.
- The public endpoint must complete `wave` with `true` and exactly one native animation call in successful cases; probes must produce zero animation calls. The pending-only case must remain `false` and expose not-ready status. Every completed scenario checks relevant object/callback preservation, endpoint count and cleanup.
- Both demonstrated baseline failures are caught.
- Eight compile-valid weakening mutations are caught: destroying the owned callback, skipping held readiness, treating the pending sentinel as native, omitting timeout cancellation, omitting listener cleanup, expiring the guard at six seconds, omitting CharacterRemoving cleanup, and destroying held objects.
- `git diff --check`.

**Studio verification: BLOCKED / pending Coordinator.** These scheduler models establish code paths, callback selection and cleanup predicates; they do not substitute for actual Roblox replication or animation playback. The Coordinator owns the `world-wall-reset` flow and combined runtime evidence.
