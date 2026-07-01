# The plan

The `RCSFPlan` is the data structure everything revolves around. The placement UI *produces*
one; the builder, presets, ghost-previews, and MP sync all *consume* it. If you
understand the plan, you understand the framework's data flow.

A plan is a plain Lua table of **world-space** pieces:

```lua
local plan = {
    structureId = "MyMod_Shed",
    variant     = "default",
    rects       = { { x = 100, y = 100, z = 0, w = 4, h = 4, kind = "room" } },
    walls       = { { x = 100, y = 100, z = 0, north = true, wallType = "wall", ... }, ... },
    cells       = { { x = 101, y = 101, z = 0, spriteName = "floors_..." }, ... },
    roofs       = { ... },
    stairs      = {},  furniture = {},  appliances = {},  decoratives = {},  vegetation = {},
}
```

The full field list and every piece shape are in
[Reference → Data contracts](../reference/data-contracts.md).

## Coordinates are absolute

Plans hold **world** coordinates, not offsets. A rect's `x,y` is its min (north-west) corner;
`north = true` on a wall means the north edge of its tile, `false` the west edge. This is why
the same plan builds the same structure at the same place every time, and why
[presets](#presets) store *relative* offsets
and re-anchor with `Presets.toPlanAt(...)`.

## Always normalize first

```lua
plan = RCSF.Plans.normalizePlan(plan)
```

`normalizePlan`:

- stamps `schemaVersion = 4` (the migration anchor),
- guarantees every array exists (`walls`, `cells`, `roofs`, `rects`, `stairs`, `furniture`,
  `appliances`, `decoratives`, `vegetation`) - so you never nil-check them,
- lifts a legacy single rect (`plan.rect`, or top-level `x/y/z/w/h`) into `rects[1]`.

It's idempotent and edits in place, so call it freely before reading array fields. `RCSF.build`
runs it for you (on a copy).

## Building a plan by hand

You rarely need to - the UI builds one - but for [headless builds](../how-to/headless-build.md)
the `Plans` helpers do the tedious parts:

```lua
local rect = { x = 100, y = 100, z = 0, w = 4, h = 4 }
local plan = RCSF.Plans.normalizePlan({
    structureId = "MyMod_Shed",
    rects = { { x = rect.x, y = rect.y, z = rect.z, w = rect.w, h = rect.h, kind = "room" } },
    walls = RCSF.Plans.getRectanglePerimeterWalls(rect, "wall"),  -- the perimeter for you
})
```

Use the `Plans.copy*` helpers (`copyPlan`, `copyWall`, ...) to deep-copy a plan rather than
aliasing it - they are the authoritative field lists, so a copy never silently drops a field.

## Multi-rect & multi-storey

`rects` is a **list** - a structure can be several rectangles. Edge-adjacent rects at the same
Z become one building with one room each; disjoint groups become separate buildings. Pieces
carry `z`, so rects span storeys and `stairs` bridge levels. The same plan model powers a
one-tile shed and a three-storey base.

```{seealso}
- [The plan's serialized form](../reference/data-contracts.md) is what presets and MP sync send.
```
