# Validate placements

Validation decides whether a plan can be built - wrong overlaps, illegal door slots, a roof
with no wall under it, a footprint that doesn't fit. The framework ships a set of **default
validators** you opt into by name, plus hooks for your own rules.

## Opt into default validators

List the ones you want in `def.validation.useDefaults`:

```lua
RCSF.Registry.registerStructure({
    id = "MyMod_Shed",
    -- …
    validation = { useDefaults = {
        "noEmptyPlan",
        "noOverlap",
        "slotKindCompatible",
        "roofNeedsWallUnder",
        "floorNeedsCell",
    } },
})
```

```{list-table}
:header-rows: 1
:widths: 32 68

* - Validator
  - Rejects when…
* - `noEmptyPlan`
  - the plan has no pieces.
* - `noOverlap`
  - two pieces occupy the same slot.
* - `slotKindCompatible`
  - a door/window slot is placed where it can't go (e.g. a door not on a wall edge).
* - `roofNeedsWallUnder`
  - a roof tile has no supporting wall/structure below.
* - `floorNeedsCell`
  - a floor-dependent piece sits over an empty cell.
* - `zAboveEmpty`
  - an upper-storey piece floats over nothing.
* - `minimumRoomRectSize`
  - a rect is smaller than the minimum room size.
* - `stairLinks`
  - a stair doesn't actually connect two storeys.
* - `obstructionFree`
  - the footprint overlaps existing world objects.
* - `footprintFitsInRect`
  - pieces fall outside their declared rect.
* - `multiRectEdgeConnectivity`
  - multi-rect groups aren't edge-connected.
```

Unknown names produce a registration **warning** (not an error), so a typo won't silently
disable a rule.

## Add your own rules

Three def callbacks run **after** the default validators. Each returns
`(ok, reasonKey?, data?)` - `reasonKey` is an `IGUI_`/`Tooltip_` key shown to the player, and
`data` is passed through to later stages (e.g. disassembly).

```lua
RCSF.Registry.registerStructure({
    id = "MyMod_Shed",
    -- …
    validateContainerPlacement = function(character, container, plan)
        if SafeHouse.isSafehouse(plan.rects[1]) then
            return false, "IGUI_MyMod_NoBuildInSafehouse"
        end
        return true
    end,
    validateDisassembly = function(character, object)
        -- (ok, reasonKey?, data?) - data flows into getRemovableObjects
        return true, nil, { objects = MyMod.collectPieces(object) }
    end,
})
```

## Validate a plan directly

To check a plan outside the UI (e.g. before a [headless build](headless-build.md)):

```lua
local ok, reasonKey = RCSF.PlacementValidation.validateContainerPlacement(
    "MyMod_Shed", player, container, plan)
if not ok then
    print("can't build: " .. tostring(reasonKey))
end
```

Or run a specific set of default validators yourself:

```lua
local ok, reason = RCSF.DefaultValidators.runAll(plan, { "noOverlap", "roofNeedsWallUnder" })
```

```{seealso}
[Reference → API → PlacementValidation / DefaultValidators](#placementvalidation).
```
