# Creator catalog: ten distinct collections

Task CREATOR-CATALOG-10-20260910. User confirmed ten TOTAL packs, including Gilded Grove. Create nine further packs of twelve original base models each (132 base models across the catalog). Palette variants do not count as extra models. Intended starting price: Gilded Grove $5.99, new twelve-model packs $4.99 each, subject to account/platform ability. Paid publication is explicitly authorized. No external paid assets, financial-account onboarding, identity/tax submissions or spending is authorized by this implementation plan.

## Owners and integration

Coordinator owns this contract, shared exporter/packager/Studio tooling, source integration, all final outputs, seller/CDP state, publication, verification and handoff. Preserve the frozen first-pack04254dd artifact and PR3. Parent branch starts from fresh origin/develop and integrates that dependency. Workers own only their three assigned source modules and ignored scratch inside separate worktrees; no shared file edits.

1. Worker1: `packs/mossvale_camp.py`, `packs/harvest_homestead.py`, `packs/tidewatch_harbor.py`.
2. Worker2: `packs/emberforge_smithy.py`, `packs/moonwell_alchemy.py`, `packs/runestone_dungeon.py`.
3. Worker3: `packs/neon_relay_lab.py`, `packs/sunbeam_cafe.py`, `packs/starfall_arcade.py`.
4. Coordinator integrates workers1,2,3, then runs combined exports, native asset checks, source/visual QA, packaging and publication gates. A worker handoff is only eligible for integration; no claimed live listing without verified paid listing URL and correct product content.

## Module interface

Each module provides `META` and `build()`:

```python
META = {
    "slug": "mossvale-camp",
    "title": "Mossvale Camp",
    "tagline": "Short concrete product use",
    "description": "Original visual props; no gameplay systems.",
    "palettes": {"Classic": ["16 six-digit RGB hex strings"],
                 "Warm": ["16 hex strings"], "Twilight": ["16 hex strings"]},
    "samples": ["01_Example", "06_Example"]
}
def build():
    # Return twelve geometry.Asset values with IDs01_..12_.
    ...
```

Import `Asset, ring_mesh` from existing `geometry` in `work/creator-packs/gilded-grove/src/geometry.py`; the exporter provides that import path and sets geometry.PALETTES['Teal'] to META's Classic colors before build. Use only the existing 16 material keys in this order: wood,darkwood,woodlight,teal,teallight,gold,goldlight,iron,stone,stonelight,cream,red,emerald,amethyst,leather,black. Base colors are palette slots, not restrictions to literal wood/teal surfaces. The exporter owns PNG color encoding, UV atlas, grouping and material application. No bpy operators run at module import time; only within build/helpers.

## Design and asset gates

- Twelve unique, useful original silhouettes per pack: about two hero props, four medium props and six complementary pieces. Create recognizable forms with deliberate supports, thickness, bevels and restrained detail.
- Distinct themes and new geometry; no recolored copies of Gilded Grove or repeated packs. No branded characters, logos, imported models, copied web geometry or dependency assets.
- Z up, front -Y, one unit intended as one stud. Root origin at ground. Place all geometry at or above ground (tolerance0.005); hanging items explicitly documented with mount/pivot. Most items within8×8×8 studs; scene fixture maximum12. Document modular dimensions where relevant.
- Target<3,000 triangles per asset, hard cap8,000 per role mesh, pack<35,000. Join semantic roles through exporter; budget<=16 role meshes per twelve-model pack. Separate lids only if useful and correctly hinged. No physics, animations, runtime scripts or unsupported interaction claims.
- No floating wheels/tools, interpenetrating face badges, missing rear/undersides or zero-area/negative-scale meshes. Insets should sit on their parent surface. Closed solids except deliberately open container cavities which have wall thickness.
- Name asset IDs01_..12_ clearly. Each `Asset` has useful description, role pivots and notes for intended assembly/use. Two small free sample IDs per new pack.
- Worker checks: actual Blender build, asset count/names, finite/nondegenerate evaluated meshes, bounds/grounding, triangles, topology where appropriate. Produce real contact-sheet render in ignored scratch and inspect it before handoff. No Studio or browser actions from workers.
- Final Coordinator checks: isolated FBX/GLB roundtrip, intended RGB plus embedded palette, actual source reopen, model readability in Blender and Studio, native uploaded asset persistence and dependency permissions, archive integrity, paid listing verification. Unavailable required gates remain BLOCKED.

## Theme briefs

| Module | Scene use and content direction |
| --- | --- |
| mossvale_camp | A forest expedition campsite: tent, campfire, bedroll, backpack, supply rack, cooking rig, trail post, log seats and camp details. |
| harvest_homestead | Cozy farming scenes: planter beds, crops, irrigation, hay, handcart, scarecrow, seed displays and farm tools. |
| tidewatch_harbor | A small waterfront: dock segments, mooring, buoy, fishing/storage props, navigation light and seaside fixtures. |
| emberforge_smithy | A workshop: forge, anvil, quench tank, bellows, grinding machine, ingots, tongs, tool racks and castings. |
| moonwell_alchemy | Fantasy research: workbench, cauldron, retort/distiller, specimen cases, scale, bookstand and reagent holders. |
| runestone_dungeon | Modular dungeon set dressing: doorway, wall/floor modules, pillars, brazier, sarcophagus, altar and architectural details. |
| neon_relay_lab | Science-fiction utility room: console, power cell, server unit, signal beacon, terminals and lab equipment. |
| sunbeam_cafe | Small café: service counter, espresso machine, seating, pastry case, menu frame and serving props. |
| starfall_arcade | Original amusement room: arcade cabinet, pinball table, racing cabinet, prize kiosk, token/change machine and room details. No copied game titles. |
