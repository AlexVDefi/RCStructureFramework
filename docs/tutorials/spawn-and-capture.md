# Tutorial 3 - Spawn & capture a prefab

In this one you'll do a full **round-trip**: design a structure in-game, **capture** it to a
blueprint with [`RCSF.Capture`](../how-to/capture.md), then **spawn** that blueprint anywhere
with [`RCSF.build`](../how-to/headless-build.md). That's the basis for prefab spawners,
world-gen structures, and quest rewards.

## What you'll build

Two server-side commands on a registered structure (reuse `MyShedMod_Shed` from
[Tutorial 1](build-a-shed.md), or any structure):

- **capture** - scan an area, save it as a named preset.
- **spawn** - stamp a saved preset at a location, for free.

## Step 1 - Capture an area to a preset

`RCSF.Capture.captureArea` reconstructs an `RCSFPlan` from the objects in an area - the inverse
of building. Give it a `structureId` and a `name` and it also produces (and saves) a relative
preset.

```{code-block} lua
:caption: media/lua/server/PrefabKit/Capture.lua
:linenos:

local RCSF = require("RCStructureFramework")
local STRUCTURE_ID = "MyShedMod_Shed"

---Capture a w×h area at (x,y,z) into a named preset for STRUCTURE_ID.
local function captureArea(x, y, z, w, h, name)
    local result = RCSF.Capture.captureArea(
        { x = x, y = y, z = z, w = w, h = h },
        { structureId = STRUCTURE_ID, name = name, save = true })

    if not result then
        print("[PrefabKit] nothing to capture")
        return
    end
    local c = result.counts
    print(("[PrefabKit] saved '%s': %d walls, %d floors (%d pieces)")
        :format(name, c.walls, c.cells, c.tagged))
end

-- e.g. capture a 6×6 structure you built with the framework:
-- captureArea(10600, 9420, 0, 6, 6, "Starter shed")
```

Capture reconstructs framework-built structures losslessly - those pieces are tagged. See the
[capture guide](../how-to/capture.md) for the full options.

## Step 2 - Spawn a saved preset

Load the preset, anchor it to a location with `Presets.toPlanAt`, and build it for free with
`RCSF.build`:

```{code-block} lua
:caption: media/lua/server/PrefabKit/Spawn.lua
:linenos:

local RCSF = require("RCStructureFramework")
local STRUCTURE_ID = "MyShedMod_Shed"

---Spawn a saved preset (by name) at (x,y,z). Server/SP only.
local function spawnPreset(name, x, y, z)
    if isClient() then return end                    -- RCSF.build is server-authoritative

    local presets = RCSF.Presets.load(STRUCTURE_ID)
    local preset
    for i = 1, #presets do
        if presets[i].name == name then preset = presets[i]; break end
    end
    if not preset then print("[PrefabKit] no preset '" .. name .. "'"); return end

    local plan    = RCSF.Presets.toPlanAt(STRUCTURE_ID, preset, x, y, z)
    local outcome = RCSF.build(STRUCTURE_ID, plan, nil, { free = true })

    print(("[PrefabKit] spawn '%s' -> %s (%d pieces, room=%s)"):format(
        name, tostring(outcome.success), #outcome.placed, tostring(outcome.roomCreated)))
end

-- spawnPreset("Starter shed", 10700, 9420, 0)
```

`free = true` means it costs nothing - perfect for world-gen / admin spawns. Drop `free` and
pass a `character` to make it consume materials instead.

## Step 3 - Wire commands and try it

Expose the two functions however you like - a debug context menu, an admin chat command, or a
world-gen hook. Then:

1. Build a small shed with your structure builder (Tutorial 1).
2. Run **capture** over its footprint → a preset is saved to the structure's presets file.
3. Run **spawn** at a fresh location → an identical shed appears instantly, with its room.

You've turned a built structure into reusable data and back into the world.

## Where this goes

- **World generation:** call `spawnPreset` from a server-side chunk/zone hook to scatter
  prefabs.
- **Quest rewards:** ship a preset with your mod and spawn it when a quest completes.

```{seealso}
- [How-to → Capture](../how-to/capture.md) and [How-to → Headless build](../how-to/headless-build.md) - full options.
- [Concepts → The plan](../concepts/the-plan.md) - what capture produces and build consumes.
```
