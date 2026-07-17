# Free Asset Manifest

## Policy

Polish direction: Hero City Smash, with a natural forest opening world.

Integration mode: Hybrid Source-first with optional visual-only Creator Store inserts.

Core city readability is built from Rojo source so the final place remains reproducible. Creator Store models are used only as decorative city background candidates. Imported content is sanitized in code: scripts, sounds, tools, prompts, and behavior objects are removed; only visual instances are kept. If Roblox blocks an insert or the asset is too heavy, the source-built city facade, road, skyline, and rubble fallback remains.

## Candidate Assets

| Use | Asset | Asset ID | Creator | Script Status | Integration Status | Fallback |
| --- | --- | --- | --- | --- | --- | --- |
| Modular downtown buildings | [City Building Pack](https://create.roblox.com/store/asset/6418277837) | `6418277837` | Roblox | No scripts | Candidate documented, too heavy for automatic runtime insert | Source-built city facade blocks with windows |
| Skyscraper decor | [skyscraper](https://create.roblox.com/store/asset/44147935) | `44147935` | coolman104531 | No scripts | Optional runtime visual insert through sanitizer | Source-built background skyscraper blocks |
| Destroyed building decor | [ATF: destroyed building](https://create.roblox.com/store/asset/7935361972) | `7935361972` | Jacob_hosker | No scripts | Optional runtime visual insert through sanitizer | Source-built rubble pile and cracked facade |
| Large city district candidate | [City Buildings Skyscraper Apartment Town RP](https://create.roblox.com/store/asset/74343734530879) | `74343734530879` | XxOwenRoguexX201481 | No scripts | Candidate only; sandbox flag means manual review before keeping | Source-built street grid and facade blocks |
| Destroyed city candidate | [destroyed city](https://create.roblox.com/store/asset/146162368) | `146162368` | 544457 | Has scripts/audio | Candidate rejected for automatic insert; requires manual cleanup if used later | Source-built rubble only |
| Wrecked city vehicles | [Abandoned car pack](https://create.roblox.com/store/asset/74466546814963) | `74466546814963` | benr3al2015 | 1 script removed | Accepted after screenshot QC; 2 textured MeshParts retained | Source-built road barriers |
| Kaiju companion/display | [Crimson Claw Dragon Ally](https://create.roblox.com/store/asset/5618903358) | `5618903358` | Josegamer941 | 7 scripts removed | Accepted after screenshot QC; 14 MeshParts retained as visual-only | Client-built companion geometry |
| Detailed city landmark | [Buildings 3](https://create.roblox.com/store/asset/135834344041946) | `135834344041946` | TenTsuDev | No scripts found | Accepted after screenshot QC; 33 MeshParts and 141 visual parts retained | Lightweight source-built skyline blocks |

## Sanitization Rule

For every imported candidate:

- Remove all `Script`, `LocalScript`, `ModuleScript`, tools, sounds, prompts, and behavior objects.
- Keep only visual instances: `Model`, `Folder`, `BasePart`, `MeshPart`, `UnionOperation`, `Attachment`, `Decal`, `Texture`, `SurfaceAppearance`, `ParticleEmitter`, `Beam`, and `Trail`.
- Anchor decorative parts.
- Disable collision, touch, and query on decorative parts.
- Mark kept containers with `AssetId`, `Creator`, `Use`, and `SanitizedVisualOnly`.
- Keep source-built procedural fallbacks active for reproducibility and test stability.

## Current Kept External Assets

The Edit-mode curated folder contains sanitized visual-only copies of:

- `74466546814963` wrecked vehicle pack
- `5618903358` Crimson Claw Dragon
- `135834344041946` Buildings 3 landmark

Each accepted asset was loaded, inspected by screenshot, stripped of scripts/behavior, anchored, and made non-collidable. The Rojo source also retains runtime sanitized fallback insertion for these IDs if a clean build does not contain the curated folder.

Additional optional runtime visual inserts are attempted for:

- `7935361972` ATF: destroyed building
- `44147935` skyscraper

The two older optional background inserts are not counted as guaranteed deliverables.

## Free Audio

| Use | Asset ID | Creator | Status |
| --- | --- | --- | --- |
| Punch impact | `132504023010884` | NickySergal | Used through `GameConfig.Audio.Punch` |
| Building collapse | `73130804959365` | MajinGoofy | Used through `GameConfig.Audio.Collapse` |
| Reward chime | `4612374209` | thienbao2109 | Used through `GameConfig.Audio.Reward` |
| Boss roar | `133651202885353` | JuanitoproCritica | Used through `GameConfig.Audio.BossRoar` |
| Hero forest music | `1837768013` | APMOfficial (`Rise to the Top (c)`) | Free Creator Store music, looped through `GameConfig.Audio.Music`; follows the player's Sound setting |
# AI-Generated Material Variants

These project-local PBR variants were generated through Roblox Studio's AI
material generator for the Kaiju City Smash visual pass. Source code checks for
each name and falls back to the matching built-in material when the variant is
not embedded.

| Variant | Base material | Use |
| --- | --- | --- |
| `KaijuDamagedConcrete` | Concrete | Building shells, sidewalks, rubble, damaged walls |
| `KaijuWornAsphalt` | Asphalt | Main roads and service roads |
| `KaijuContainmentMetal` | CorrodedMetal | Titan and Cyber containment architecture |

Generated variants contain visual PBR maps only and no scripts.
# Iteration 01 GPT-Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `125153703372122` | `work/assets/generated/iteration-01/kaiju-city-billboard-spawn.png` | Mirrored spawn billboard composition |
| `82590428870038` | `work/assets/generated/iteration-01/kaiju-city-billboard.png` | Titan district billboard |
| `88173613852029` | `work/assets/generated/iteration-01/kaiju-city-menu-banner.png` | Responsive menu art banner |
| `108499712320512` | `work/assets/generated/iteration-01/kaiju-guardian-icon.png` | Guardian icon source for later release metadata |

The master and derivatives are original GPT-generated project assets with no
logos, text, third-party scripts, or external behavior.

# Iteration 02 GPT-Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `80764015986038` | `work/assets/generated/iteration-02/kaiju-dna-menu-banner.png` | Pets menu and DNA Lab world display |
| `114585325653299` | `work/assets/generated/iteration-02/kaiju-dna-pet-icon.png` | Pet inventory rarity thumbnail |

The wide master depicts five original Kaiju City companion concepts in a
laboratory display. World use keeps the generated image on a physical sign with
both SurfaceGui and Decal fallback; neither asset contains scripts or behavior.

# Iteration 03 GPT-Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `134754597904456` | `work/assets/generated/iteration-03/kaiju-tasks-banner.png` | Tasks/mission menu banner |
| `79786692712597` | `work/assets/generated/iteration-03/kaiju-settings-banner.png` | Settings/accessibility menu banner |

Both derivatives come from one original mission-control master generated for
the project. They contain no scripts, external logos, or behavioral objects.

# Iteration 04 GPT-Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `105049638464832` | `work/assets/generated/iteration-04/kaiju-fist-armory-banner.png` | Two-sided City Fist Armory landmark and Fists menu banner |

The original master is
`work/assets/generated/iteration-04/kaiju-armory-master.png`. The derivative is
project-original raster art and contains no scripts, prompts, sounds, or
behavior objects.

# Iteration 05 GPT-Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `93552182756522` | `work/assets/generated/iteration-05/kaiju-titan-containment-banner.png` | Two-sided Titan containment header and BossHUD image cue |

The original master is
`work/assets/generated/iteration-05/kaiju-titan-containment-master.png`. It is
project-original raster art with hard-surface concrete/metal texture and no
scripts, external logos, prompts, sounds, or behavior objects.

# Fist UI Redesign Generated Graphics

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `134314320646796` | `work/assets/generated/fist-ui-redesign/kaiju-city-icon-atlas-4x4.png` | HUD stats, actions, menu tabs, fist tiers, quests, notifications, and Armory nameplates |

This is a project-original GPT-generated raster atlas. It contains no scripts,
external logos, prompts, sounds, or behavior objects. Roblox serves it as a
1024x1024 image; runtime crops use 256x256 cells.

# Hero City Theme Exploration

| Workspace source | Use |
| --- | --- |
| `work/assets/generated/theme-exploration/hero-city-theme-comparison.png` | Original four-theme comparison board; Hero City selected as the final direction |

The comparison board is project-original GPT-generated concept art. It is kept
as a design reference and is not loaded at runtime.

# User-Supplied Hero City HUD Source

| Roblox asset | Workspace source | Use |
| --- | --- | --- |
| `104014193600358` | `work/assets/generated/hero-city-hud-reference/hero-city-hud-icons-source.png` | Live HUD icons, touch actions, tabs, fist cards, notifications, Armory nameplates, Fist Shop header, and world shop billboard |

This image was supplied by the user for direct use in the game. It contains no
scripts or behavioral objects; runtime uses only raster image crops.
# Hero City Skyline Addition

| Asset | ID | Creator | Usage | Sanitation | Fallback |
| --- | --- | --- | --- | --- | --- |
| City Buildings | `3346479763` | Zackgamer_awesome1 | Detailed skyline groups at the north and south city boundaries | Runtime sanitizer keeps visual classes only, anchors parts, and disables collision, query, and touch | Existing source-built skyline remains |

## Rejected QC Candidate

| Asset | ID | Creator | Result |
| --- | --- | --- | --- |
| Apartments (colored) | `2744631571` | logoffkid | Rejected after sanitized playtest. It contained no scripts but added 2,013 instances and produced no meaningful improvement in the reference combat camera, so it was removed. |
# Creator Store Fist Visuals - 2026-07-13

These free Creator Store models were selected for the current Hero Fist shop and inserted under `ReplicatedStorage.PunchWallFistAssets`. They are visual-only after sanitation. No third-party gameplay script, remote, or tool behavior is retained.

| Shop tier/style | Asset | Creator | Asset ID | Kept visual | Fallback |
|---|---|---|---:|---|---|
| Starter through Titan | Fist | Penguin9805 | `1622087753` | Approved closed-fist SpecialMesh, recolored and fitted to the wrist for every tier; source-built cuffs, core plates, materials, and lights distinguish the five shop tiers | Existing procedural closed-fist gauntlet |

Sanitation removed `Script`, `LocalScript`, `ModuleScript`, `RemoteEvent`, `RemoteFunction`, `BindableEvent`, `BindableFunction`, and Tool wrappers. Parts are welded to the player's right hand, non-collidable, massless, and controlled by the project's own punch animation and combat code.

The replaced `boxing gloves` asset `124838246751652` remains embedded only as a fallback for older place files. `Power Boxing Gloves` (`2837181164`), `Void Fists` (`116284795259865`), and `Vargas's Gauntlets` (`90276119548098`) are retained only as sanitized legacy fallbacks: screenshot QC showed inconsistent wrist alignment and silhouettes that did not match the shop art. Candidate `89377193377537` was rejected because its open glove read as a cuff, while `10036139093` read as a ring-shaped hand pose instead of a punch. Runtime selection now standardizes all tiers on the approved armored closed-fist `1622087753` visual.

# Final Source-Embedded Forest And Fist Assets - 2026-07-14

| Use | Asset | Asset ID | Creator | Kept visual | Source fallback |
| --- | --- | ---: | --- | --- | --- |
| World 1 forest trees | Stylized Forest Tree | `95555308270103` | `SwitchpmPixeld111933` | 7 MeshParts and 6 SurfaceAppearances | `ForestVisualBuilder.lua` retains a non-blocking procedural tree fallback |
| All five glove tiers | Armored Closed Hero Fist | `1622087753` | `Penguin9805` | 1 Part with approved closed-fist SpecialMesh and texture | `FistVisualBuilder.lua` recreates the sanitized mesh template from source |

The final `.rbxlx` builder embeds both visual templates with XML APIs. It also
embeds `ForestVisualBuilder` and `FistVisualBuilder`, validates the generated
XML, and replaces the delivery file only after validation. The embedded tree
and fist templates contain zero `Script`, `LocalScript`, or `ModuleScript`
descendants. Decorative forest instances are anchored and non-collidable;
equipped fist clones are welded, massless, and non-collidable.

# Release Expansion Visual Assets - 2026-07-16

Core gameplay remains source-owned. Every Creator Store model in this section
is either embedded as a visual template or loaded through `AssetService`, then
copied through an exact visual-class allowlist. Third-party scripts, tools,
prompts, remotes, and behavior objects are discarded.

| Use | Asset | Asset ID | Creator | Kept visual | Fallback |
| --- | --- | ---: | --- | --- | --- |
| Celestial premium fist | PowerFist (x6 Dmg) | `65566767` | `xFrimble` | Part, SpecialMesh, and texture; embedded in the final place | Source-built armored fist |
| Storm premium display | Void Fist Aura | `116284795259865` | `MysticHvNightO1592` | Sanitized parts, meshes, attachments, particles, and lights | Source-built energy aura |
| Power training landmark | Hero Power Bag | `140653091179998` | `Lucy896Miner` | Sanitized visual hierarchy only | Source-built heavy bag |
| Fist shop NPC | Rad Robo | `2841100862` | `L4UNDRY_BE4R` | Sanitized character visuals only; all scripts, prompts, and behavior removed | Procedural Hero Armorer NPC |
| Premium Robux merchant NPC | Bionic Ninja Size Corrected | `3162411898` | `Mario5697` | Sanitized upright bionic-hero visuals only; all scripts, prompts, tools, and behavior removed | Procedural Premium Hero NPC |
| Pet shop NPC | Pet Lab Scientist | `103629315510813` | `XxWillowV3nomxX2016` | Sanitized character visuals only | Procedural Pet Scientist NPC |

Runtime-loaded assets are restricted to the exact IDs above and are skipped in
Studio playtests to avoid local third-party insertion warnings. The published
place has free-asset loading enabled; any load or sanitation failure immediately
uses the procedural fallback. Decorative parts are anchored and non-colliding.
Equipped fist parts are massless, non-colliding, and welded by project code.

`narwhal warrior upgraded` (`15949563425`) was rejected after in-game screenshot
QC because its sanitized visual imported in a sprawled, sideways pose that did
not read as a merchant. The upright bionic hero replaces it.

## Release Audio

| Use | Asset ID | Runtime policy |
| --- | ---: | --- |
| Forest Hero background music (`Winning Spirit (c)`, APMOfficial) | `1837768082` | Free Creator Store audio; looped at volume `0.22`, preloaded, and controlled by the live Sound HUD button in Studio and published runtime |

# User-Supplied Hero Shop Product Art - 2026-07-16

These six transparent PNG layers came from `C:\Temp\Shop`. They are raster
art only and contain no scripts, prompts, remotes, sounds, or behavior. The
remaining checkerboard-backed frame exports are retained as layout references;
their backgrounds are baked into RGB pixels, so the live shop recreates those
metal frames and buttons with native Roblox UI instead of displaying white
checkerboard corners.

| Runtime use | Source file suffix | Roblox asset ID |
| --- | --- | ---: |
| Starter red fist | `02_08_00 (1).png` | `102627532847126` |
| Titan gold fist | `02_08_00 (2).png` | `97597870943935` |
| Champion black fist | `02_08_00 (3).png` | `123648606849968` |
| Coin boost x2 | `02_08_01 (4).png` | `124043136175492` |
| Speed boost lightning | `02_08_01 (5).png` | `110700899933892` |
| Damage boost burst | `02_08_01 (6).png` | `140286541155994` |
| Shop Coin price icon | `C:\Temp\RMBG\ChatGPT Image 13 ก.ค. 2569 01_49_21 (3).png` | `72320637874093` |

The client shows the atlas fallback only when a product has no supplied image.
This prevents legacy labels and frames from bleeding through the transparent
pixels of the uploaded art.

The Coin price icon is also copied into
`F:\Roblox\PuchWall\work\assets\user-supplied\shop-coin-icon.png` and is
preloaded during the client loading screen. It is rendered as a standalone
transparent `ImageLabel`, so no square atlas frame or crop can overlap prices.
