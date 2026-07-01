# RC Structure Framework

RC Structure Framework (**RCSF**) is a Build 42 dependency mod for **player-built
structures**. It gives you a sprite/piece catalog, an interactive placement UI,
pluggable material consumption, validation, a generic builder, runtime `IsoRoom`
creation, ghost-preview persistence, disassembly, and multiplayer sync - all
server-authoritative and MP-safe.

It's currently used by [Military Tents](https://steamcommunity.com/sharedfiles/filedetails/?id=3718884098).

```{admonition} New here? Start with the 5-minute build.
:class: tip
[**Getting started →**](getting-started.md) takes you from an empty mod to a working
"build a shed" feature. Then the [tutorials](tutorials/index.md) go deeper.
```

::::{grid} 1 1 2 2
:gutter: 3
:margin: 4 0 0 0

:::{grid-item-card} Getting started
:link: getting-started
:link-type: doc

Install it, then a 5-minute end-to-end build. The fastest path to "it works."
:::

:::{grid-item-card} Tutorials
:link: tutorials/index
:link-type: doc

Guided, build-along lessons: a shed and a quest room.
:::

:::{grid-item-card} How-to guides
:link: how-to/index
:link-type: doc

Task recipes: materials, unlock gating, headless builds, rooms, events, MP safety.
:::

:::{grid-item-card} Concepts
:link: concepts/index
:link-type: doc

How the pipeline fits together: the plan, material sources, authority, rooms.
:::

:::{grid-item-card} Reference
:link: reference/index
:link-type: doc

Every module, function, structure-definition field, data contract, and event.
:::

:::{grid-item-card} Use only the parts you need
:link: how-to/vendoring
:link-type: doc

Depend on everything, disable subsystems, or vendor a single standalone module.
:::

::::

## At a glance

- **Build:** Project Zomboid Build 42.13+
- **Mod id:** `RCStructureFramework` - declare `require=RCStructureFramework` in your `mod.info`
- **Global:** `RCSF` (short alias) / `RCStructureFramework` (long name + require id)
- **Multiplayer:** server-authoritative; dedicated server, listen host, and singleplayer
- **Modular:** depend on the whole thing, opt out of subsystems, or vendor a single module

## The 60-second example

Register a structure and its pieces (shared), then open the builder from a context menu
(client). That's the complete minimum for a working "build a shed" feature:

```{code-block} lua
:caption: media/lua/shared/MyMod/Shed.lua
local RCSF = require("RCStructureFramework")

RCSF.Registry.registerStructure({
    id                = "MyMod_Shed",
    roomName          = "MyModShed",          -- enables runtime IsoRoom creation
    useGenericBuilder = true,                  -- use the built-in per-piece builder
    materialSource    = "raw",                 -- consume items straight from inventory
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
})

RCSF.Registry.registerPieces("MyMod_Shed", {
    { spriteName = "walls_exterior_wooden_01_0", category = "wall", pieceType = "wall",
      categoryGroup = "wall", materialRequirement = { fullType = "Base.Plank", count = 2 } },
    { spriteName = "floors_exterior_natural_01_0", category = "floor",
      categoryGroup = "floor", materialRequirement = { fullType = "Base.Plank", count = 1 } },
})
```

```{code-block} lua
:caption: media/lua/client/MyMod/OpenBuilder.lua
require("RCStructureFramework/PlacementUI")   -- loads the RCStructurePlacementUI panel

local function onFillContext(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    context:addOption("Build Shed", nil, function()
        RCStructurePlacementUI.open("MyMod_Shed", playerIndex, player, nil)
    end)
end
Events.OnFillInventoryObjectContextMenu.Add(onFillContext)
```

That gives the player the full drag-footprint → paint → build flow, with material checks,
validation, an `IsoRoom`, and MP sync. The [Getting started](getting-started.md) guide
walks through it line by line.

```{toctree}
:hidden:
:caption: Getting started

getting-started
```

```{toctree}
:hidden:
:caption: Learn

tutorials/index
concepts/index
```

```{toctree}
:hidden:
:caption: Build with it

how-to/index
reference/index
```

```{toctree}
:hidden:
:caption: Project

reference/roadmap
```
