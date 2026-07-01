# Tutorial 1 - Build a shed

By the end you'll have a small mod that adds a **"Build Shed"** option to the inventory
context menu, opens the framework's placement UI, and lets the player drag a footprint, paint
walls and a floor, and build a real, lit, persisted shed - consuming planks, validated, and
multiplayer-safe.

This is the [`RCSFExampleShed`](https://github.com/AlexVDefi/Structure-Framework/tree/main/examples/RCSFExampleShed)
example, explained.

## Prerequisites

- Project Zomboid **Build 42.13+**.
- A mod skeleton (`mod.info` + `media/lua/`). If you don't have one, scaffold any empty B42
  mod first.

## Step 1 - Declare the dependency

In your `mod.info`:

```ini
name=My Shed Mod
id=MyShedMod
require=RCStructureFramework
```

`require=` makes the game load the framework before your mod, so `require("RCStructureFramework")`
works.

## Step 2 - Register the structure and pieces (shared)

Create `media/lua/shared/MyShedMod/Shed.lua`. This runs on **both** client and server.

```{code-block} lua
:caption: media/lua/shared/MyShedMod/Shed.lua
:linenos:

local RCSF = require("RCStructureFramework")

local Shed = {}
Shed.STRUCTURE_ID = "MyShedMod_Shed"

-- This shed has no door/window frames, no blueprints, and pays from inventory,
-- so we switch off three auto-systems we don't need. (Optional; safe to omit.)
RCSF.disable("spritePatcher")
RCSF.disable("plannedConstructions")
RCSF.disable("materialContainers")

RCSF.Registry.registerStructure({
    id                = Shed.STRUCTURE_ID,
    roomName          = "MyShedRoom",        -- a real, lit, persisted IsoRoom
    useGenericBuilder = true,                 -- the built-in per-piece builder
    materialSource    = "raw",                -- pay from the player's inventory
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
})

RCSF.Registry.registerPieces(Shed.STRUCTURE_ID, {
    { spriteName = "walls_exterior_wooden_01_0", category = "wall", pieceType = "wall",
      categoryGroup = "wall", materialRequirement = { fullType = "Base.Plank", count = 2 } },

    { spriteName = "floors_exterior_natural_01_0", category = "floor",
      categoryGroup = "floor", materialRequirement = { fullType = "Base.Plank", count = 1 } },
})

return Shed
```

What each part does:

- **`roomName`** turns the finished shed into a real room - so lighting and room detection
  work. Omit it for a wall-only structure.
- **`materialSource = "raw"`** + each piece's **`materialRequirement`** means a wall costs 2
  planks, a floor 1, taken from the builder's inventory.
- **`validation.useDefaults`** rejects empty plans, overlapping pieces, and illegal door/window
  slots. (We have no doors here, but `slotKindCompatible` is cheap insurance.)
- The three `RCSF.disable(...)` lines are a [subset opt-out](../how-to/vendoring.md) - purely an
  optimization for a mod that doesn't use those systems.

```{tip}
Don't have these exact sprite names? Use the in-game tile picker (debug mode) to find a wall
and floor sprite, and swap them in.
```

## Step 3 - Open the builder (client)

Create `media/lua/client/MyShedMod/OpenBuilder.lua`. This is **client-only** - the UI is
presentation; the build itself runs server-side through the framework's timed action.

```{code-block} lua
:caption: media/lua/client/MyShedMod/OpenBuilder.lua
:linenos:

require("RCStructureFramework/PlacementUI")     -- loads the RCStructurePlacementUI panel
local Shed = require("MyShedMod/Shed")

local function onFillInventoryContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    context:addOption("Build Shed", nil, function()
        -- (structureId, playerIndex, character, container)
        RCStructurePlacementUI.open(Shed.STRUCTURE_ID, playerIndex, player, nil)
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContextMenu)
```

For clarity this adds the option to every inventory item. A real mod would gate it on a
specific kit/blueprint item (pass that item as the 4th `container` argument).

## Step 4 - Try it

1. Enable **My Shed Mod** and **RCStructureFramework** in the mod list, start a world.
2. Make sure you've got a stack of planks.
3. Right-click any inventory item → **Build Shed**.
4. Drag a footprint, paint the walls and floor, and confirm.

You'll watch the timed action build it plank by plank, get a real room (try a light switch
inside after dark), and - on a server - see it appear for every other player.

## What you have

Without writing any of it yourself: footprint selection, a paint UI with live material and
validation feedback, atomic build-or-rollback, runtime room creation, lighting, and full
multiplayer sync.

## Next

- Add **disassembly** so players can take the shed back down: [How-to → Disassemble & refund](../how-to/disassembly.md).
- Add a **door** piece (`slotKind = "door"`, `categoryGroup = "door"`) and a wall sprite for it.
- Gate the shed behind a skill or magazine: [Materials & unlocks](#unlock-gating).
- Move on to [Tutorial 2 - Claim a quest room](claim-a-room.md).
```
