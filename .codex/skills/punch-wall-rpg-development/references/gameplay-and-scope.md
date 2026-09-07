# Gameplay And Scope Reference

## Player Loop

The core loop is:

```text
Train stats -> break the next valid wall -> earn coins and progression
-> upgrade fists and pets -> reach rebirth and Titan Server Wall goals
```

The loop must be understandable from a fresh-player state. A player must be able to see what to do next, why a wall is gated, how their action changes state, and what reward or milestone was earned.

## Canonical Content

- Training: Power Bag, Speed Dummy, and Focus Stone build player capability.
- Destruction: wall tiers progress through Brick, Concrete, Iron, Crystal, Lava, and Cyber Gate toward the Titan Server Wall.
- Economy: coins buy stronger fists; pets provide multipliers and use inventory/equip rules.
- Long-term progression: rebirth resets the specified short-term state and grants permanent scaling.
- Feedback: HUD, toast/reward pop, damage state, camera, and VFX must communicate a real server-confirmed outcome.

## Feature Decisions

- Prefer a clear next action over a new menu or decorative system.
- Keep the path navigable after destruction. Players must be able to identify solid, broken, unsupported, and traversable space.
- Make attack phases readable: wind-up, strike/contact, feedback, recovery. Do not use fast movement or camera effects that hide the avatar or cause clipping.
- Keep walls, HUD labels, quests, and world progression tied to live state. Do not show stale or decorative progress.
- Give each tier a readable material identity and environmental change; avoid temporary-looking flat color slabs.
- Keep the map cute low-poly / Hero City in visual style, while preserving visual clarity and mobile readability.

## Feature Acceptance

A gameplay feature is ready only when:

1. It works from an appropriate player state and respects server validation.
2. Its outcome is visible and tied to the game state.
3. The affected mobile and desktop path remains usable.
4. A recorded flow proves the expected behavior or documents a concrete blocker.
5. It does not break the progression loop, navigation, or existing economy.
