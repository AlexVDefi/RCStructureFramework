# Getting started

This takes you from an empty mod to a working "build a structure" feature on top of RC
Structure Framework - in about five minutes. A complete, compilable version lives in
[`examples/RCSFExampleShed`](https://github.com/AlexVDefi/RCStructureFramework/tree/main/examples/RCSFExampleShed),
and the [Build a shed tutorial](tutorials/build-a-shed.md) walks through it in depth.

## Prerequisites

- Project Zomboid **Build 42.13+**.
- Your mod declares the dependency in `mod.info`:
  ```ini
  require=RCStructureFramework
  ```
- At least one wall sprite name and one floor sprite name. Use the in-game tile-picker
  debug, or vanilla names like `walls_exterior_wooden_01_0` and `floors_exterior_natural_01_0`.

```{admonition} Players need the framework too
:class: note
RCSF is a **dependency mod** - it does nothing on its own. Players subscribe to it
alongside your mod. The `require=` line makes the game load it first.
```

## 1. Get the API

```lua
local RCSF = require("RCStructureFramework")
```

`RCSF` is the framework table; every module hangs off it (`RCSF.Registry`, `RCSF.Builder`,
`RCSF.PieceLibrary`, …). You can also require a single module directly:
`require("RCStructureFramework/Registry")`.

## 2. Register a structure (shared)

Put this in `media/lua/shared/`. A [structure definition](reference/structure-definition.md)
is one table; only `id` is required.

```{code-block} lua
:caption: media/lua/shared/MyMod/Shed.lua
:emphasize-lines: 4,5,6

RCSF.Registry.registerStructure({
    id                = "MyMod_Shed",
    roomName          = "MyModShed",     -- omit if you don't want an IsoRoom
    useGenericBuilder = true,            -- opt into the built-in per-piece builder
    materialSource    = "raw",           -- "raw" | "universal" | "bag"
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
})
```

`materialSource = "raw"` means each piece's `materialRequirement` is consumed straight from
the player's inventory. For container- or recipe-based consumption, see
[Materials & unlocks](how-to/materials-and-unlocks.md).

## 3. Register pieces (shared)

Pieces are the catalog the player paints from. `category` drives the placement slot;
`categoryGroup` drives the catalog UI bucket; `materialRequirement` is what each placed piece
costs.

```lua
RCSF.Registry.registerPieces("MyMod_Shed", {
    { spriteName = "walls_exterior_wooden_01_0", category = "wall", pieceType = "wall",
      categoryGroup = "wall", materialRequirement = { fullType = "Base.Plank", count = 2 } },

    { spriteName = "walls_exterior_wooden_01_8", category = "wall", pieceType = "door",
      slotKind = "door", categoryGroup = "door",
      materialRequirement = { fullType = "Base.Plank", count = 2 } },

    { spriteName = "floors_exterior_natural_01_0", category = "floor",
      categoryGroup = "floor", materialRequirement = { fullType = "Base.Plank", count = 1 } },
})
```

`registerPieces` auto-fills each piece's `structureId` and an `id`
(`structureId .. ":" .. spriteName`) when you don't supply one. See the
[piece fields](#piece).

```{tip}
Gate pieces behind skills, magazines, or research with `unlockSources` - the catalog hides
a piece until the player qualifies. See [Materials & unlocks](#unlock-gating).
```

## 4. Open the builder (client)

Put this in `media/lua/client/`. Requiring `PlacementUI` loads the panel class; then call
`RCStructurePlacementUI.open(structureId, playerIndex, character, container)`. `container` is
the inventory item the build is associated with (a blueprint/kit item), or `nil`.

```{code-block} lua
:caption: media/lua/client/MyMod/OpenBuilder.lua

require("RCStructureFramework/PlacementUI")

local function onFillContext(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    context:addOption("Build Shed", nil, function()
        RCStructurePlacementUI.open("MyMod_Shed", playerIndex, player, nil)
    end)
end
Events.OnFillInventoryObjectContextMenu.Add(onFillContext)
```

The player now gets the full flow: drag a footprint, paint walls/floors, see live material +
validation feedback, and confirm. The framework runs a timed action that validates and builds
server-side, creates the `IsoRoom`, and syncs to other players.

That's a complete, working feature.

## Optional next steps

::::{grid} 1 1 2 2
:gutter: 2

:::{grid-item-card} Add disassembly
```lua
require("RCStructureFramework/DisassemblyUI")
RCStructureDisassemblyUI.open(
    "MyMod_Shed", clickedObject, player)
```
See [Disassembly](how-to/disassembly.md).
:::

:::{grid-item-card} Build without the UI
For prefab spawners, quests, and tests, skip the UI entirely with
[`RCSF.build`](how-to/headless-build.md).
:::

:::{grid-item-card} Claim a room (no build)
Mark any area as a real `IsoRoom` for a quest or zone with
[`RCSF.Rooms.assign`](how-to/rooms.md).
:::

:::{grid-item-card} React to builds
Run code when a structure is built or torn down via the
[framework events](how-to/events.md).
:::

::::

## Where to go next

- [**Tutorials**](tutorials/index.md) - build-along lessons, starting with the full shed.
- [**Structure definition**](reference/structure-definition.md) - every callback you can implement to customize build/validate/material/disassembly behavior.
- [**Multiplayer**](how-to/multiplayer.md) - authority rules before you ship to servers.
- [**Vendoring & subsets**](how-to/vendoring.md) - trim what you pull in.
```{important}
Before shipping to servers, read [Multiplayer](how-to/multiplayer.md). World/inventory
mutations must run server-side; the UI flow already routes through a server-authoritative
timed action, but if you build headlessly you must do it on the server.
```
