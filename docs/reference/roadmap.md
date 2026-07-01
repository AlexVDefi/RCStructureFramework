# Roadmap

What the framework delivers today, and what's proposed next.

## Delivered

The full free-form-building pipeline:

- **Piece/sprite catalog** - `PieceLibrary` (register/query by category/tag/structure, with
  skill/magazine/research unlock gating) + the `PieceCatalogPanel` browser UI.
- **Per-piece sprites in the plan** - `wall.spriteName`, `cell.spriteName`, `roof.spriteName`
  flow through `Plans`, `Presets`, and the builder.
- **Roofs as first-class plan data** - `plan.roofs[]` + roof piece kind + preview helpers.
- **Slot kinds** - `wall.slotKind` (`"wall"`/`"door"`/`"window"`) with door/window-frame
  placement helpers and the `SpritePropertyPatcher` walkability fix.
- **Plan schema version** - `plan.schemaVersion` (= 4) + `Migrations` for presets.
- **Generic per-piece builder** - `Builder.buildFromPlan` with per-piece material consumption,
  per-piece success/failure, and rollback; pluggable piece kinds.
- **Pluggable materials** - `MaterialSource` (`raw`/`universal`/`bag`) + `RecipeSource`
  (heterogeneous item+tag recipes).
- **Default validators** - overlap, slot-kind, roof-needs-wall, floor-needs-cell, min size,
  stair links, multi-rect connectivity, and more.
- **Multi-rectangle footprints & multi-room** - `plan.rects[]`, one `IsoRoom` per connected
  rect group.
- **Multi-storey** - pieces carry `z`; rects span storeys; stairs bridge levels.
- **Runtime rooms + lighting** - `RoomPersistence.createRoom`, `RoomLighting`.
- **Ghost-preview persistence** - `PlannedConstructions` (survives relogs, MP-synced).
- **Disassembly** - `Builder.disassembleFromPlan` + `DisassemblyUI` + material refund.
- **Presets** - save/load/rename, versioned JSON, auto-migration.

### Dev-friendly API

These first-class entry points make the framework easy to drive programmatically:

- **Headless room assignment** - [`RCSF.Rooms.assign/unassign`](../how-to/rooms.md): claim an
  arbitrary area as a server-authoritative, MP-synced, persisted `IsoRoom` decoupled from
  the build pipeline.
- **Custom Lua events** - [`OnRCSFStructureBuilt` / `Disassembled` / `RoomAssigned` /
  `RoomUnassigned`](events.md).
- **Headless build** - [`RCSF.build(structureId, plan, character, opts)`](../how-to/headless-build.md):
  one-call server-side build, no UI/timed-action.
- **`RCSF.defineStructure(def)`** - [validating one-call registration](../how-to/introspection.md)
  with inline pieces and a default variant.
- **Registry introspection** - [`RCSF.Introspect`](../how-to/introspection.md): documented,
  mutation-safe cross-mod queries.

## Proposed next

Each would get its own implementation plan (MP authority, `Core.ResetLua`, and vendoring
impact assessed per item).

1. **Multi-material containers** - richer mixed-material container modelling beyond the
   current `raw`/`universal`/`bag` sources.
2. **Non-rectangular single rooms** - true arbitrary-cell footprints (L-shapes today are
   handled as unions of rects). Would also let `RCSF.Rooms.assign` model exact
   footprints instead of per-Z bounding rects.
3. **Generalized disassembly UI** - promote `DisassemblyUI` to a fully documented, reusable
   consumer entry point.
4. **EmmyLua → API generator** - a small script so this reference stays in sync with the
   inline annotations.
