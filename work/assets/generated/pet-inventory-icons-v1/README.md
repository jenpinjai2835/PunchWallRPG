# Model-Matched Pet Inventory Icons V1

Project-owned transparent pet portraits generated for the Inventory card and
detail views. Each portrait is intentionally species-specific and follows the
same silhouette, colors, armor, and signature feature as the corresponding
in-world companion.

## Runtime-ready upload candidates

| Pet / art key | File (512x512 RGBA) | Identity cue | SHA-256 |
| --- | --- | --- | --- |
| Forest Pup / `ForestPup` | `runtime-512/forest-pup.png` | green pup, floppy ears, yellow collar | `E846A730A7E287525010461563970FFE5D40B81889E2FBCF9AF4B78B955773BB` |
| Miner Cat / `MinerCat` | `runtime-512/miner-cat.png` | blue cat, miner helmet and lamp | `43F24A0376A2317A73FE6D49D28E07238EC25CFF31DA3275AF537FA2F9FA8B28` |
| Crystal Fox / `CrystalFox` | `runtime-512/crystal-fox.png` | violet fox, crystal shards and tail | `1418EBB4BB9671DDCC1846916C51C5F84531226CF73CBC646CD13F7704B22B91` |
| Lava Dragon / `LavaDragon` | `runtime-512/lava-dragon.png` | lava-orange armored dragon and ember core | `15B33A5796DB4EC0CEE8EF4A4DA21847A46618EDAFABBF0D6D81D25DCA44E6CD` |
| Secret Titan Golem / `SecretTitanGolem` | `runtime-512/secret-titan-golem.png` | black-red titan armor and glowing core | `CD45174A4495A87457C981201F6D17F377486C8EBC56C10F41C22E12B715D215` |
| Crimson Phoenix / `CrimsonPhoenix` | `runtime-512/crimson-phoenix.png` | red-gold phoenix, spread flame wings | `B67DC33BC8723E9889E80EBF2C0D4005BB5CB67513D83052F4C116D52D16B01D` |
| Storm Wyvern / `StormWyvern` | `runtime-512/storm-wyvern.png` | navy-cyan wyvern and electric core | `2A4168AAA1BF9BEFC28BFA0291E9242583B3BD4138676743EEA0C1328D87A0CF` |
| Celestial Guardian / `CelestialGuardian` | `runtime-512/celestial-guardian.png` | white-gold robotic guardian with cyan visor | `246991E3AE7168C2103B2880A616BEF7310143D46CA46FF231DFCE4059AC8DE9` |

All selected files are square RGBA images with transparent corners. The larger
files in this directory are generation masters; `runtime-512/` is the only
upload set.

## Roblox integration contract

1. Until approved Roblox image IDs exist, Inventory renders a sanitized
   `ViewportFrame` clone from the same pet builder used by the equipped pet.
   This removes the old repeated generic pet picture without relying on an
   unavailable local-file URL.
2. Upload the eight files from `runtime-512/` as project-owned image assets and
   place the returned IDs in `GameConfig.PetInventoryArt.entries[*].assetId`.
3. Keep the model preview as a fail-safe whenever an ID is missing or cannot be
   loaded. Never fall back from one pet to another pet's portrait.
4. Uploaded art is decorative only. Name, rarity, equipped/locked state, stars,
   fusion eligibility, and all actions remain native server-backed UI.

## Generation method and prompt family

The built-in ImageGen tool was used with one species-specific prompt per pet,
then selected images were resized to 512x512 and alpha-validated. The common
prompt contract was:

> Create one polished square Roblox companion inventory icon on a transparent
> background. Show the named pet in a readable three-quarter hero pose. Match
> its current in-game species, primary/accent colors, armor/materials, and
> signature feature exactly. Use crisp mobile-readable edges, centered framing,
> no card frame, no scenery, no text, no logo, no watermark, and no duplicate
> animals.

The Celestial Guardian generation used a temporary chroma background because
the first alpha attempts baked a checkerboard into the pixels; the selected
runtime image was chroma-keyed and manually alpha-checked.
