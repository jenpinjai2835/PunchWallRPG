# Release spin credit oracle — 2026-09-06

Status: offline checks pass; the actual release flow rerun remains **pending**. No gameplay source changed. The Coordinator must integrate this handoff after the frozen full-suite run, register the new contract, and rerun the flow in Studio.

## Cause and change

The frozen full-suite `release-expansion-economy` step returned `credits=4` with `reward="BonusSpinPurple"`, failing its hardcoded final balance of 3. The actual server behavior is consistent with the catalog:

- `GameConfig.Spin.Rewards` contains eight weighted outcomes. Both `BonusSpinGreen` and `BonusSpinPurple` have `kind="BonusSpin"`, `amount=1`, and `weight=10`.
- `spinReward` performs weighted selection, consumes one credit when a paid credit is available, otherwise records the free-spin time, and then adds the selected bonus-spin amount. A fresh free bonus spin therefore changes credits from 0 to 1.
- `GameConfig.PremiumProducts` defines `SpinPack.spins=3`. The production premium grant adds that amount to the existing balance. One existing bonus credit plus the pack correctly totals 4.

The revised step reads actual server snapshots before the spin, after the spin, and after the explicit Studio grant. Its verifier requires the reward's index, ID, kind, amount, and positive weight to match the catalog. It checks the exact spin-credit ledger and the actual Coins/Power/Honor reward delta. It then requires successful SpinPack grant identity and amount, exactly three additional credits, and unchanged unrelated balances. The current free-spin baseline and strict default ephemeral profile are checked before this step's reset/grant.

The final total may be 3 or 4 depending on the legitimate weighted result. Acceptance is determined by the separate exact ledgers, rather than accepting either total without attribution. The explicit Studio grant exercises the production grant function; it does not test a real Robux purchase or receipt delivery.

Only the step labeled `spin grants weighted reward and bonus credits` changes. Every other release-economy step and cleanup is preserved semantically and checked against frozen revision `6211b00`. Existing fist, continuous training, Honor, rebirth, and console gates remain unchanged.

## Focused verification

Run from the repository root:

```powershell
node --check work/automation/scripts/release-spin-credit-contract.mjs
node work/automation/scripts/release-spin-credit-contract.mjs
```

The durable contract extracts the **actual** current spin catalog, premium-product catalog, weighted spin producer, premium grant producer, and flow verifier. Controlled random values select the midpoint of every configured weight interval; all eight outcomes run with zero credits and with two existing credits. Endpoint rolls are also checked. The old total-balance oracle is reproduced and fails both bonus outcomes while accepting non-bonus outcomes.

Result: 12 source/flow checks, 91 executed Luau assertions, 16 compiled snippets, and 10 rejected mutations. These are local producer/verification checks, not Studio results or a statistical distribution study.

Mutation controls reject missing bonus credits, missing or doubled pack credits, overwriting existing credits, mismatched product identity, non-weighted selection, and omitted paid-credit consumption. Three verifier-weakening mutations also fail: removing the exact pack delta, spin ledger, or grant identity checks. Additional executed negative cases reject unknown/mismatched reward metadata, wrong reported credit balances, unwanted reward/grant balance changes, and unsuccessful grants. Actual cooldown refusal and unready-profile refusal preserve balances.

## Integration handoff

- Modified flow: `work/automation/flows/release-expansion-economy.json`.
- New contract: `work/automation/scripts/release-spin-credit-contract.mjs`.
- This document: `work/docs/SMASH_RELEASE_SPIN_CREDITS_20260906.md`.
- Coordinator action: register the contract using the repository's current contract registry, integrate after the frozen run finishes, and run the unchanged full release flow with the revised spin step. Preserve the prior failed evidence.

No source, Studio, shared helper, root integration worktree, or Agent HQ files were edited by this worker. No runtime or release pass is claimed until the Coordinator records it.
