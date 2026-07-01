# Capture a structure (reverse build)

`RCSF.Capture.captureArea` scans a world area and reconstructs an `RCSFPlan` - the **inverse
of building**. Use it for prefab authoring - "design it in-game, save it as data".

```text
RCSF.Capture.captureArea(area, opts?) -> { plan, counts, preset?, saved? }?
```

It's **read-only** - no world mutation, no MP-authority concern - but it only sees **loaded
squares**, so run it where the area's chunks are loaded.

## Capture an area to a plan

```lua
local result = RCSF.Capture.captureArea({ x = 10600, y = 9420, z = 0, w = 12, h = 10 })
if result then
    print(("%d walls, %d floors, %d roofs captured"):format(
        result.counts.walls, result.counts.cells, result.counts.roofs))
    -- result.plan is a ready-to-build RCSFPlan
end
```

`area` is either a rect `{x,y,z,w,h}` (add `levels = N` to scan N storeys upward) or an
explicit box `{x1,y1,z1, x2,y2,z2}`.

## What it captures

Every object the framework placed carries an `RCStructureFramework` modData tag; capture
reconstructs those pieces **exactly** - the true inverse of build. Walls, floors, roofs,
stairs, furniture, appliances, decoratives and vegetation are all recovered.

Pass `onlyStructureId = "MyMod_Shed"` to capture just one structure out of an area holding
several.

`result.counts` reports `{ walls, cells, roofs, stairs, furniture, appliances, decoratives,
vegetation, tagged }` so you can tell how much was captured.

## Capture straight to a preset

With a `structureId` plus `asPreset` / `name` / `save`, you also get a relative preset (and
optionally persist it to the structure's presets file):

```lua
local result = RCSF.Capture.captureArea(
    { x = 10600, y = 9420, z = 0, w = 12, h = 10 },
    {
        structureId = "MyMod_Shed",
        name        = "My saved base",
        save        = true,            -- writes via Presets.add
    })
-- result.preset is a relative preset; result.saved == true
```

You can then stamp it anywhere with [`RCSF.build`](headless-build.md) +
`Presets.toPlanAt` - see the [round-trip tutorial](../tutorials/spawn-and-capture.md).

## Options

```{list-table}
:header-rows: 1
:widths: 26 74

* - Option
  - Effect
* - `structureId`
  - Stamped on the plan; **required** for `asPreset` / `save`.
* - `onlyStructureId`
  - Capture only tagged pieces whose `structureId` matches.
* - `rects`
  - Override the derived room rects (otherwise one bounding-box rect per Z level).
* - `name` / `asPreset` / `save`
  - Produce / persist a preset (needs `structureId`).
```

```{note}
Derived room rects are a bounding box per Z, so a non-rectangular footprint becomes a slightly
larger rectangular room. Pass explicit `rects` when you need exact room bounds.
```
