# Build a structure without the UI

`RCSF.build` builds a plan immediately - no placement UI, no timed action. Use it for
**prefab spawners, quest rewards, world generation, and tests**.

```text
RCSF.build(structureId, plan, character, opts?) -> RCSFBuildOutcome
```

```{important}
`RCSF.build` is **server-authoritative**: it runs on the MP server and in singleplayer.
On an MP client it returns a failure outcome unless you pass `opts.allowClient` (rarely
correct). Call it from server-side logic. See [Multiplayer](multiplayer.md).
```

## A minimal free build

The simplest case: build a registered structure at fixed coordinates, consuming nothing
(`free = true`), and let the framework create its room.

```lua
local function spawnShedAt(x, y, z)
    local plan = {
        variant = "default",
        rects = { { x = x, y = y, z = z, w = 4, h = 4, kind = "room" } },
        walls = RCSF.Plans.getRectanglePerimeterWalls({ x = x, y = y, z = z, w = 4, h = 4 }, "wall"),
    }
    local outcome = RCSF.build("MyMod_Shed", plan, nil, { free = true })
    if outcome.success then
        print(("built %d pieces; room=%s"):format(#outcome.placed, tostring(outcome.roomCreated)))
    else
        print("build failed: " .. tostring(outcome.reason))
    end
    return outcome
end
```

You don't have to pre-normalize or build a material source - `RCSF.build` runs
`Plans.normalizePlan` on a **copy** of your plan (your table is never mutated) and resolves
the material source from the def.

## What `opts` controls

```{list-table}
:header-rows: 1
:widths: 24 76

* - Option
  - Effect
* - `free = true`
  - Consume **nothing** (sets the material source to nil). Ideal for prefab/world spawns.
* - `materialSource = src`
  - Supply a ready [material source](../concepts/material-sources.md); skips def resolution.
* - `container = item`
  - `InventoryItem` fed to the def's source / legacy builder.
* - `variant = "green"`
  - Override `plan.variant`.
* - `createRoom = false`
  - Skip room creation (default **true** when the def names a room and the plan has rects). On success, `outcome.roomCreated` reports whether a room was made.
* - `builderOptions = {…}`
  - Forwarded to `Builder.buildFromPlan` (per-piece `configure*` hooks, container, …).
* - `allowClient = true`
  - Bypass the server-authoritative guard (cosmetic local builds only).
```

## Consuming a character's materials

Pass a `character` and omit `free` to consume from the def's material source (for `"raw"`,
that's the character's inventory):

```lua
local outcome = RCSF.build("MyMod_Shed", plan, player)   -- consumes per-piece materials
```

The outcome is the standard [`RCSFBuildOutcome`](#builder-outcomes):
`{ success, placed, failed, reason?, roomCreated? }`. On failure the build rolls back every
piece placed this call.

## Building from a saved preset

Combine with [Presets](#presets) to stamp a
designed layout anywhere:

```lua
local presets = RCSF.Presets.load("MyMod_Shed")
local plan    = RCSF.Presets.toPlanAt("MyMod_Shed", presets[1], anchorX, anchorY, z)
RCSF.build("MyMod_Shed", plan, nil, { free = true })
```

```{seealso}
- [Concepts → The plan](../concepts/the-plan.md) - what a plan contains and how to build one.
```
