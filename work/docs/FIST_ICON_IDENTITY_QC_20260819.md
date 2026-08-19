# Fist Shop Icon Identity QC — 2026-08-19

## Result

PASS for serial Gate 2 of 8. The Shop retains three lightweight uploaded fist
silhouettes, but no two fist products now share the same complete visible or
machine-readable icon identity.

Each normal and Premium fist now has:

- a unique immutable icon key and variant key;
- palette tint derived from the equipped model definition;
- an exact `T01`–`T16` badge;
- an armor-family signature (`PAD`, `WRAP`, `RIVET`, `RAIL`, `SIEGE`,
  `SHIELD`, `BLADE`, or `CROWN`);
- bounded plate/fin marks matching the runtime armor family;
- zero icon RenderStep/Heartbeat work.

Unknown styles and missing icon keys fail closed instead of silently showing
Starter art. Premium fist keys no longer alias normal fists.

## QC loops

1. The legacy runtime flow expected five cards and exact old silhouette names.
   It was upgraded to inspect all sixteen current cards and stable runtime
   anatomy attributes.
2. The modal-art check accepted only one-digit counts (`4`–`9`) and rejected
   the correct sixteen-card result. It now requires exactly sixteen.
3. The Hero Shop purchase regression was missing the new Depth 1 prerequisite.
   Its setup now proves the visible button reaches server authority at the
   correct progression boundary.
4. Current screenshots were manually inspected at the top and endgame portions
   of the catalog. Tier badges, signature strips, tint, item names, Depth gates,
   and action buttons remain readable with zero reported text overflow.

## Passed evidence

- `fist-icon-identity-contract.mjs`: 7/7, including 16 unique normal keys and
  three additional non-aliasing Premium keys.
- `fist-items-icon-ui`: PASS, 14 named steps, 16/16 unique identities, tints,
  badges, signatures, and bounded static treatments.
- `hero-shop-reference-polish`: PASS, including UI purchase and post-stop
  console.
- `long-run-catalog-progression`: PASS, 24 named steps.
- aggregate static suite: Node 30, PowerShell 18, Luau 27, JSON flows 106,
  runner 11, infrastructure 25, economy 10, Batch-B fist 11, fist identity 7,
  pet pack 8, persistence 28.
- client runtime/performance structural contract: 26/26.

## Evidence

- `work/docs/evidence/fist-icon-identity-20260819/fists.jpg`
- `work/docs/evidence/fist-icon-identity-20260819/fists-endgame.jpg`
- `work/docs/evidence/fist-icon-identity-20260819/capture-summary.json`
- `work/docs/evidence/fist-icon-identity-20260819/runtime-fist-items-icon-ui.json`
- `work/docs/evidence/fist-icon-identity-20260819/runtime-hero-shop-reference-polish.json`
- `work/docs/evidence/fist-icon-identity-20260819/runtime-long-run-catalog-progression.json`

This gate intentionally avoids sixteen additional uploaded textures and keeps
the visual treatment code-native and static, preserving the prior performance
budget while making every offer recognizable.
