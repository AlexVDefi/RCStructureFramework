# Data contracts

These are the public data structures the framework passes around: the **plan** (and its
piece arrays), the **piece library entry**, the **planned-construction record**, and the
**event payloads**. They are the serialized format used by presets and MP sync, so they
are part of the supported API - you may read them directly, and (where noted) write them.

All shapes are declared as EmmyLua `@class` types in `Contracts.lua`; this page is the
prose version. See also [Concepts → The plan](../concepts/the-plan.md).

## Stability policy

- **stable** - read (and, where noted, write) directly. Breaking changes ship with a
  `schemaVersion` bump and a migration (see `Migrations.lua` / `Presets`).
- **internal** - implementation detail; may change without notice.
- The plan's `schemaVersion` is the version anchor (current = **4**). Always run
  `Plans.normalizePlan(plan)` before relying on the array fields - it stamps the version
  and guarantees every array (`walls`, `cells`, `roofs`, `rects`, `stairs`, …) exists.

## Plan (`RCSFPlan`) - stable

The world-space build plan. Produced by the placement UI or a headless caller, consumed by
`Builder` / `Presets` / `PlannedConstructions`.

```{list-table}
:header-rows: 1
:widths: 26 30 44

* - Field
  - Type
  - Notes
* - `schemaVersion`
  - `integer?`
  - current = 4; the migration anchor.
* - `structureId`
  - `string?`
  - owning structure def id.
* - `variant`
  - `string?`
  - structure variant (e.g. `"green"`).
* - `color`
  - `string?`
  - legacy alias read as a variant fallback.
* - `rects`
  - `RCSFRect[]?`
  - one or more footprints (canonical since multi-rect).
* - `walls` / `cells` / `roofs` / `stairs`
  - `*[]?`
  - the structural piece arrays (cells = floors/rugs).
* - `furniture` / `appliances` / `decoratives` / `vegetation`
  - `*[]?`
  - entity pieces.
* - `rect`, `x/y/z/w/h`
  - *deprecated*
  - legacy single-rect; `normalizePlan` lifts them into `rects[1]`.
```

### Piece shapes

`RCSFRect`
: `{ x, y, z, w, h, kind? }` - `x,y` is the min (NW) corner; `w,h >= 1`; `kind` defaults to `"room"`.

`RCSFWall`
: `{ x, y, z, north, wallType?, slotKind?, spriteName?, wallpaperSpriteName? }`. `north` = `true` for the north edge, `false` for the west edge. `slotKind` (`"wall"`/`"door"`/`"window"`) changes engine flags; `spriteName` wins over `wallType` resolution.

`RCSFCell`
: `{ x, y, z, spriteName?, isRug? }` - `isRug = true` places on top of an existing floor instead of replacing it. A `nil` sprite is a silent skip in the builder.

`RCSFRoof`
: `{ x, y, z, north, spriteName?, slope?, roofKind? }`.

`RCSFStair`
: `{ x, y, z, north, bottomSprite?, middleSprite?, topSprite?, pillarSprite? }`.

Entity pieces
: **Furniture** `{ x, y, z, facing?, defId?, spriteName?, footprint?, anchor? }` · **Appliance** = furniture + `utilities? = { power?, water? }` · **Decorative** `{ x, y, z, facing?, defId?, spriteName?, anchor? }` · **Vegetation** `{ x, y, z, defId?, spriteName? }`.

```{tip}
Use the `Plans.copy*` helpers (`copyPlan`, `copyWall`, `copyRoof`, …) to deep-copy rather
than reaching in by hand - they are the authoritative field lists.
```

(piece)=
## Piece (`RCSFPiece`) - stable

A catalog entry registered via `PieceLibrary.register` / `Registry.registerPieces`.
Canonical type: `RCStructureFrameworkPiece` (declared in `PieceLibrary.lua`).

```{list-table}
:header-rows: 1
:widths: 26 30 44

* - Field
  - Type
  - Notes
* - `id`
  - `string`
  - unique; defaulted to `structureId .. ":" .. spriteName`.
* - `spriteName`
  - `string`
  - closed-state sprite.
* - `category`
  - `string`
  - placement slot: `"wall"`, `"floor"`, `"roof"`, …
* - `subcategory`
  - `string?`
  - e.g. `"regular"`/`"door"`/`"window"` for walls.
* - `structureId` / `variant`
  - `string?`
  - scoping.
* - `label` / `labelKey`
  - `string?`
  - raw text / `IGUI_` key.
* - `tags`
  - `string[]?`
  - arbitrary filter tags.
* - `pieceType`
  - `string?`
  - hook for `def.getPieceSpriteName`.
* - `northVariant` / `westVariant`
  - `string?`
  - facing-specific sprites.
* - `openSpriteName`
  - `string?`
  - door/window open state.
* - `footprint`
  - `{ w, h }?`
  - per-piece engine footprint.
* - `categoryGroup`
  - `string?`
  - catalog UI bucket.
* - `materialRequirement`
  - `{ tag?, fullType?, count }?`
  - consumed by `MaterialSource`.
* - `materialRecipe`
  - `[{fullType, count, keep?, tag?}, …]?`
  - heterogeneous recipe via `RecipeSource`.
* - `unlockSources`
  - `{ skill?, magazines?, research? }?`
  - gating; `nil` = default-unlocked.
* - `thumbnailIcon`
  - `string?`
  - catalog tile icon override.
```

## Planned-construction record (`RCSFPlannedRecord`) - stable

A server-authoritative "planned but unbuilt" structure (the ghost-preview feature). Stored
in global ModData under `PlannedConstructions.MOD_DATA_KEY`.

```{list-table}
:header-rows: 1
:widths: 26 24 50

* - Field
  - Type
  - Notes
* - `id`
  - `string`
  - generated record id.
* - `ownerId`
  - `string`
  - `onlineID` (MP) or `"SP_<username>"` (SP).
* - `blueprintItemId`
  - `any`
  - caller-supplied, opaque.
* - `plan`
  - `RCSFPlan`
  - world-space plan copy.
* - `createdAtMs`
  - `integer`
  -
* - `pieces`
  - `RCSFPlannedPiece[]`
  - per-piece build state.
```

`RCSFPlannedPiece`
: `{ kind, x, y, z, north?, spriteName, slotKind?, defId?, materialRecipe?, builtAt?, builtBy? }`. `builtAt = nil` means unbuilt; otherwise a build timestamp (ms). Records are **mutated server-side only**; clients read a synced cache.

(builder-outcomes)=
## Builder outcomes - stable

- `Builder.buildFromPlan` (and `RCSF.build`) returns `RCSFBuildOutcome`:
  `{ success, placed, failed, reason?, roomCreated? }`.
- `Builder.disassembleFromPlan` returns `RCSFDisassembleOutcome`: `{ success, removed, reason? }`.

On failure the builder rolls back everything placed this call (`placed` will be empty).

## Room assignment + event payloads - stable

- `RCSFRoomAssignment` (returned by `RCSF.Rooms.assign`, carried by the room events):
  `{ id, name, rects }`.
- `OnRCSFStructureBuilt` payload: `{ structureId, plan, character, placed }`.
- `OnRCSFStructureDisassembled` payload: `{ structureId, character, removed }`.

See [Events](events.md) for the full event reference.
