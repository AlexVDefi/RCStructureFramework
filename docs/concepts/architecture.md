# Architecture

The framework is a pipeline from *"a structure exists in the registry"* to *"real
`IsoObject`s exist in the world, in a room, synced to everyone."* Each stage is a module you
can use, replace, or skip.

## The pipeline

**register** → **plan** → **validate** → **resolve materials** → **build** → **finalize**

The numbered steps below walk each stage and name the module(s) that own it.

1. **Registration** - `Registry.registerStructure` records a [def](../reference/structure-definition.md);
   `PieceLibrary` records the pieces a player can paint. This is all that's required for a
   structure to *exist*.
2. **A plan is produced** - either interactively by the `RCStructurePlacementUI` (drag a
   footprint, paint pieces) or programmatically by you. The result is an
   [`RCSFPlan`](the-plan.md): rects, walls, cells, roofs, and entity pieces in world
   coordinates.
3. **Validation** - `PlacementValidation` runs the [default validators](../how-to/validation.md)
   you opted into, then your custom `validate*` callbacks.
4. **Material resolution** - a [`MaterialSource`](material-sources.md) is resolved from the
   def (`"raw"`/`"universal"`/`"bag"` or a custom factory).
5. **Build** - `Builder.buildFromPlan` walks the plan piece by piece. Each piece kind (wall,
   cell, roof, furniture, …) has a handler that consumes its material, resolves its sprite,
   and places the `IsoObject` via `PlacementHelpers`. Any failure **rolls the whole build
   back**.
6. **Finalize** - the room is created (`RoomPersistence`), lighting wired
   (`RoomLighting`), and `OnRCSFStructureBuilt` fires.

The interactive path wraps steps 3-6 in a **server-authoritative timed action**; the
[headless path](../how-to/headless-build.md) (`RCSF.build`) runs them directly on the server.

## Modules by job

```{list-table}
:header-rows: 1
:widths: 34 66

* - Job
  - Module(s)
* - Structure & piece registration
  - `Registry`, `PieceLibrary`
* - Interactive placement UI
  - `RCStructurePlacementUI`, `PieceCatalogPanel` (client)
* - Plan data + geometry
  - `Plans`, `Geometry`, `Footprints`
* - Validation
  - `PlacementValidation`, `DefaultValidators`
* - Material consumption (pluggable)
  - `MaterialSource`, `RecipeSource`, `MaterialContainers`
* - Generic per-piece builder + rollback
  - `Builder`, `PlacementHelpers`
* - Runtime `IsoRoom` creation + persistence
  - `RoomPersistence`
* - Light switches in runtime rooms
  - `RoomLighting`
* - Door/window-frame walkability fix
  - `SpritePropertyPatcher`
* - Ghost-preview persistence (across relogs)
  - `PlannedConstructions`
* - Presets (save/load layouts)
  - `Presets`, `Migrations`, `Json`
* - Disassembly + refund
  - `Builder.disassembleFromPlan`, `DisassemblyUI`
* - Headless entry points
  - `Build` (`RCSF.build`), `Rooms`, `Introspect`, `Events`
```

## Two design choices worth knowing

**Pluggable piece kinds.** The builder dispatches on a small registry of piece-kind handlers
(`wall`, `cell`, `roof`, `furniture`, `appliance`, `decorative`, `vegetation`). You can
`Builder.registerPieceKind(name, handler)` to add your own kind without touching the core
loop.

**Warn, don't throw.** Registration validates your def but only *errors* on a missing `id`;
everything else is a warning. This keeps a mod built against a newer framework version from
hard-crashing on an older one (forward compatibility). See
[registration is validated](../reference/structure-definition.md#registration-is-validated).

```{seealso}
- [The plan](the-plan.md) - the data structure steps 2-5 pass around.
- [Authority & rooms](authority-and-rooms.md) - what makes steps 5-6 multiplayer-safe.
- [Vendoring](../how-to/vendoring.md) - which of these modules you can use standalone.
```
