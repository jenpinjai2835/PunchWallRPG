# Inventory Module QC Contract

## Purpose

This document defines the acceptance contract for the Punch Wall RPG Inventory
module. The Inventory is a client presentation over server-authoritative saved
state. It must never invent ownership, rewards, quantities, purchase results,
or progression.

The dedicated recorded flow is:

`work/automation/flows/inventory-menu-ui.json`

The flow is designed for the source-first Studio place named `PunchWallRPG`.
It becomes an integration gate after the Coordinator wires the client
automation contract described below.

## Runtime Asset Gate: BLOCKED

Runtime use of the generated Inventory layer pack is currently **BLOCKED**.

The audited source is the untracked folder:

`F:\Roblox\PuchWall-parallel\work\assets\inventory-ui\generated`

Current blockers:

- the pack contains 19 chrome/background PNG files but no complete category
  icon or game-item icon set;
- the audited PNGs are 24-bit RGB exports with no alpha channel;
- the area intended to be transparent is bright magenta chroma;
- no approved Roblox asset IDs or runtime manifest exist for these files;
- using the files directly would expose magenta or chroma-key fringe in game.

A native Roblox UI fallback is acceptable for the functional MVP. The fallback
must retain the dark Hero City hierarchy, cyan/red/gold accents, readable rarity
states, and must contain no magenta, checkerboard, sample text, or fake item.

Generated layers may replace the fallback only after all of the following:

1. Chroma is removed with clean anti-aliased edges and a real alpha channel.
2. Runtime-size exports are visually checked for haloing and border distortion.
3. Reusable frames define safe nine-slice centers or are exported at their
   exact runtime aspect.
4. Every retained layer has an approved `rbxassetid://` value.
5. The source file, asset ID, purpose, retained content, and fallback are
   recorded in the project asset manifest.
6. Desktop and compact captures prove no magenta or checkerboard is visible.

## Authoritative Inventory Sources

| Category | Server-synchronized source | Stable key |
| --- | --- | --- |
| Fists | `OwnedFistsJSON`, `OwnedPremiumFistsJSON`, `EquippedFist` | `fist:<internal save name>` |
| Pets | `PetInventoryJSON`, `EquippedPetsJSON`, `LockedPetsJSON` | `pet:slot:<1-based index>` |
| Honor | `OwnedHonorItemsJSON`, `EquippedHonorItem` | `honor:<internal name>` |
| Boosts | Active entries in `ShopBoosts` | `boost:<internal boost name>` |

`PetInventoryJSON` capacity is the only current inventory capacity:
`used = #PetInventoryJSON`, `max = GameConfig.MaxPetInventory` (currently 60).
Do not present a combined fake capacity for fists, Honor items, and pets.

Robux products are store offers, not owned inventory. VIP Pass, steel ingots,
gold ore, extra slots, auto-train tokens, coin magnets, and other sample items
from the visual reference must not appear unless an authoritative game system
is introduced for them.

## Client Automation Contract

The Studio-only `PunchWallClientAutomation` BindableFunction must expose these
commands. They are test controls, not player-facing production controls.

| Command | Value | Required behavior |
| --- | --- | --- |
| `OpenInventory` | none | Open the Inventory as the only active modal and return an updated snapshot or `true`. |
| `CloseInventory` | none | Close the Inventory, restore gameplay HUD/input, and return an updated snapshot or `true`. |
| `SelectInventoryCategory` | `All`, `Fists`, `Pets`, `Honor`, or `Boosts` | Change category, preserve only valid selection, refresh visible items. |
| `SetInventorySearch` | string | Apply trimmed case-insensitive search to authoritative names/display names. |
| `SetInventoryRarity` | `All`, `Common`, `Rare`, `Epic`, `Legendary`, or `Premium` | Apply rarity filtering without mutating inventory. |
| `SelectInventoryItem` | stable item key | Select exactly one owned/active item. Duplicate pets must be selected by slot key. |
| `InvokeInventoryAction` | `{action=<name>, key=<stable key>}` | Send the normal server request for that exact owned item. An unknown key must return `false, "item_not_found"`, preserve the prior selection, and dispatch nothing. Never mutate ownership locally. |
| `InventorySnapshot` | none | Return the deterministic state contract below without changing gameplay. |

Supported action names used by this flow are `Equip`, `Unlock`, `Lock`, and
`Delete`. `selected.actions` contains enabled actions only. A locked pet exposes
`Unlock` but not `Delete`.

The `key` supplied to `InvokeInventoryAction` is authoritative scope, not a
selection hint. The client must never fall back to the previously selected item
when that explicit key is missing, invalid, or stale.

Every slot-specific pet request sent to the server includes both the saved pet
token and its current 1-based inventory index. If the index is out of range or
no longer contains that token, the normal server validator and the mirrored
Studio automation command return `ok = false, reason = "stale_inventory"`.
Inventory, locks, and equipped pets must remain byte-for-byte unchanged.

### `InventorySnapshot` Shape

```lua
{
    ok = true,
    visible = true,
    category = "All",
    search = "",
    rarity = "All",
    visibleKeys = { "fist:Starter Glove", "pet:slot:1" },
    visibleNames = { "Starter Fist", "Crystal Fox" },
    selected = {
        key = "pet:slot:1",
        kind = "Pet",
        name = "Crystal Fox", -- authoritative internal name
        displayName = "Crystal Fox",
        description = "Power +85% | 1 Star",
        rarity = "Epic",
        slot = 1,
        equipped = true,
        locked = false,
        actions = { "Unequip", "Lock", "Delete" },
    },
    capacity = {
        used = 3,
        max = 60,
    },
    hudHidden = true,
    layout = {
        compact = false,
        columns = 4,
        minTouchTarget = 44,
        allTextFits = true,
        insideSafeArea = true,
        noOverlap = true,
        detailMode = "Pane", -- "Drawer" for compact selection
    },
    art = {
        mode = "NativeFallback", -- or "UploadedLayers"
        magentaFree = true,
        checkerboardFree = true,
    },
}
```

The snapshot must derive layout measurements from currently visible,
interactive descendants. It must not return hard-coded pass values.

## Deterministic Flow State

The desktop phase resets the automation player and seeds:

- owned fists: Starter Glove, Boxing Glove, Crimson Vanguard Fist;
- equipped fist: Starter Glove;
- pet slots: Crystal Fox, Crystal Fox, Miner Cat;
- equipped pet: the first Crystal Fox token;
- lock: `slot:2`;
- owned/equipped Honor item: Vanguard Trail;
- one active CoinBoost purchased through the server automation path.

The flow verifies:

1. Only the eight seeded owned/active keys are eligible to appear.
2. Starter Glove is owned and visible.
3. Reference-only fake item names do not appear.
4. Fists, Pets, Honor, and Boosts filters return their authoritative entries.
5. Search for `boxing` selects `fist:Boxing Glove`.
6. Equip goes through the normal server path and server state becomes
   `EquippedFist = "Boxing Glove"`.
7. Search for `crystal` plus `Epic` rarity returns both duplicate pet slots.
8. With one Crystal Fox equipped, slot 1 alone exposes `Unequip`; slot 2 alone
   exposes `Equip`. Slot 2 remains independently locked, exposing `Unlock` but
   not `Delete`.
9. `InvokeInventoryAction` with `pet:slot:999` returns
   `false, "item_not_found"`, keeps slot 2 selected, and leaves the three
   authoritative pet strings unchanged.
10. Unlock/relock/unlock targets slot 2, then deletion targets that exact
    unequipped duplicate.
11. Deleting slot 2 leaves `[Crystal Fox, Miner Cat]`, preserves the equipped
    sibling as `["Crystal Fox"]`, and clears the removed slot's lock.
12. Reusing the old `{ target = "Crystal Fox", index = 2 }` after that deletion
    returns `stale_inventory` and leaves inventory, locks, and equipped pets
    unchanged.
13. The test invokes `Reset` immediately after the destructive and stale-index
    assertions, then closing the modal restores the live Hero City gameplay HUD.

Deletion is permitted only inside this isolated, deterministic test state. The
flow deletes the unequipped duplicate only after explicitly unlocking its slot,
verifies the equipped sibling and stale-index failure, then resets immediately.
Cleanup always stops Play mode, so the mutation cannot be treated as player
data.

## Responsive Acceptance Matrix

| Viewport | Mode | Required layout |
| --- | --- | --- |
| 1920x1080 desktop | Wide | Category rail, adaptive grid, and detail pane visible without overlap. |
| 1366x768 desktop | Wide automated gate | Same three-region hierarchy; all visible actions and text pass measurements. |
| 1024x768 tablet | Wide/adaptive | Detail remains usable; grid reduces columns without clipping. |
| 844x390 phone landscape | Compact | Horizontal/compact category control, 2-3 grid columns, detail drawer. |
| 740x360 phone landscape | Compact automated gate | Most restrictive layout; 44px actions, safe area, readable drawer, no overlap. |

All viewports must satisfy:

- modal remains inside `DeviceSafeInsets`;
- every visible close, category, filter, item, and action button has a minimum
  interactive dimension of 44 pixels;
- all visible non-wrapped control labels report `TextFits = true`;
- scrolling regions contain their children and do not cover the close control;
- detail selection is usable without hover;
- user UI scale values 0.8, 1.0, and 1.2 do not move controls out of the safe
  modal area;
- the Inventory hides gameplay HUD/action controls while open and restores
  them after close;
- no magenta, checkerboard, sample quantities, or reference-only text is
  visible.

Compact selection has an additional exclusive-detail contract. While the detail
drawer/page is open, `InventoryGridPane` and `InventoryGrid` must both be hidden,
the detail frame must have positive dimensions and remain inside
`InventoryWindow`, and every visible action button must have positive touch-safe
dimensions fully contained by the detail frame. Closing the detail state must
hide the detail frame and restore both grid objects with positive dimensions
inside the modal. The flow measures these live descendants directly; a
high-level `noOverlap = true` value alone is not sufficient evidence.

The recorded flow automates 1366x768 and the restrictive 740x360 layout. The
remaining matrix sizes require the release device-matrix pass and captured
player-view review.

## Functional Acceptance

- Item ownership and quantities always come from the last server
  `StatsChanged` payload.
- UI actions use the existing validated `ActionRequest` route.
- A local button press may show pending feedback but cannot claim success until
  the authoritative state refresh arrives.
- Invalid, missing, unowned, or stale stable keys fail closed.
- An invalid explicit client action key returns `item_not_found`, preserves the
  prior selection, and never dispatches an action for that prior selection.
- Duplicate pets never use species name alone for lock/delete selection.
- Slot-specific equip, unequip, lock, unlock, and delete requests include the
  current inventory index. A token/index mismatch returns `stale_inventory`
  without changing inventory, locks, or equipped pets.
- For duplicate tokens, only the last currently equipped occurrence may expose
  `Unequip`, and only the next unequipped occurrence may expose `Equip`.
- Deleting an unequipped duplicate preserves the equipped count and the
  equipped sibling.
- Locked pets cannot expose or invoke delete.
- Empty category, empty search, full capacity, loading, and selection-cleared
  states remain readable and do not leave stale detail actions enabled.
- Category/search/rarity changes do not mutate player state.
- Fists and Honor items use internal save keys for actions while displaying
  player-facing names.
- Opening Inventory does not expose the Fist Shop or another modal underneath.
- Closing from header, automation, and controller/back path produces the same
  restored HUD state.

## Execution And Evidence

Before Studio validation, synchronize current source:

```powershell
node "F:\Roblox\PuchWall\work\automation\scripts\sync_rojo_source_to_studio.mjs"
```

Run the dedicated flow:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\invoke-recorded-flow.ps1" `
  -FlowPath "F:\Roblox\PuchWall\work\automation\flows\inventory-menu-ui.json"
```

Then run the UI profile:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1" -Profile UI
```

Before integration is declared ready, rerun these directly affected flows:

- `inventory-persistence`
- `luck-distribution`
- `iteration04-armory-pets-feedback`
- `fist-items-icon-ui`
- `responsive-ui-inputs`
- `release-expansion-ui`
- `device-matrix-hud-shop`

Run the complete existing flow suite before merge:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Record:

- flow JSON result and console-clean result;
- `Inventory_Module_1366x768_All` capture;
- `Inventory_Module_740x360_PetDetail` capture;
- player-view captures for 1920x1080, 1024x768, and 844x390;
- any unrelated pre-existing failure as a concrete blocker, not a pass;
- asset mode used for the tested build (`NativeFallback` or
  `UploadedLayers`).

The Inventory is ready only after integration, the relevant regression, the
full required suite, and visual review report no known in-scope defect.
