# API reference

Every public module hangs off the framework table (`RCSF` / `RCStructureFramework`) and can
also be required directly: `require("RCStructureFramework/<Module>")`. Data structures
(`RCSFPlan`, `RCSFPiece`, `RCSFStructureDef`, ...) live in [Data contracts](data-contracts.md)
and [Structure definition](structure-definition.md).

```{admonition} The three calls you'll use most
:class: tip
`RCSF.build(structureId, plan, character, opts?)` - one-call [headless build](#build).<br>
`RCSF.defineStructure(def)` - validating one-call [registration](#registry).<br>
`RCSF.enable(key)` / `RCSF.disable(key)` - toggle an [auto-system](#config).
```

```{note}
Several modules can be copied into your own mod and used **standalone**, without depending
on the framework. The [Vendoring guide](../how-to/vendoring.md) lists which ones.
```

## Modules

`````{list-table}
:header-rows: 1
:widths: 26 74

* - Group
  - Modules
* - **Core**
  - [Registry](#registry) · [PieceLibrary](#piecelibrary) · [Builder](#builder)
* - **Headless API**
  - [Build](#build) · [Rooms](#rooms) · [Introspect](#introspect) · [Events](#events)
* - **Plans & geometry**
  - [Plans](#plans) · [Footprints](#footprints) · [Geometry](#geometry)
* - **Materials**
  - [MaterialSource](#materialsource) · [RecipeSource](#recipesource) · [MaterialContainers](#materialcontainers)
* - **Placement & validation**
  - [PlacementHelpers](#placementhelpers) · [PlacementValidation](#placementvalidation) · [DefaultValidators](#defaultvalidators)
* - **Rooms & auto-systems**
  - [RoomPersistence](#roompersistence) · [PlannedConstructions](#plannedconstructions) · [PiecePresence](#piecepresence) · [RoomLighting](#roomlighting) · [SpritePropertyPatcher](#spritepropertypatcher)
* - **Presets, config & UI**
  - [Presets](#presets) · [Config](#config) · [Client UI](#client-ui)
`````

---

## Core

(registry)=
### Registry

Structure-definition registry. Validates defs on registration
(see [how validation works](structure-definition.md#registration-is-validated)).

:::{describe} registerStructure(def) -> boolean
Register an `RCSFStructureDef`. Returns `false` only if `id` is missing.
:::

:::{describe} defineStructure(def) -> RCSFStructureDef?
Validate, default, and register in one call; an inline `def.pieces` array is batch-registered, and a single `{ default = true }` variant is filled in when none is given. Also `RCSF.defineStructure(def)`.
:::

:::{describe} registerPieces(structureId, entries) -> integer
Batch-register pieces; returns the count. Auto-fills each piece's `structureId` and `id`.
:::

:::{describe} getStructure(structureId) -> RCSFStructureDef?
:::
:::{describe} requireStructure(structureId) -> RCSFStructureDef
Look up a def. `requireStructure` errors if the id is unknown.
:::

:::{describe} getStructureByRoomName(roomName) -> RCSFStructureDef?
Resolve a def from a live IsoRoom name (handles `_N` suffixes).
:::

:::{describe} getPieceSpriteName(structureId, variant, pieceType, north) -> string?
Resolve a piece sprite.
:::

:::{describe} getAllStructures() -> table<string, RCSFStructureDef>
The live registry table. Prefer [Introspect](#introspect) for safe, copied queries.
:::

(piecelibrary)=
### PieceLibrary

Catalog of pickable pieces, indexed by category / tag / structure, with unlock gating.

:::{describe} register(piece) -> boolean
:::
:::{describe} unregister(id)
:::
:::{describe} unregisterStructure(structureId)
Add, remove, or bulk-remove pieces.
:::

:::{describe} get(id) -> RCSFPiece?
Look up one piece.
:::

:::{describe} getByCategory(category) -> RCSFPiece[]
:::
:::{describe} getByCategoryAndTag(category, tag) -> RCSFPiece[]
:::
:::{describe} getByCategoryGroup(group) -> RCSFPiece[]
Bucket queries.
:::

:::{describe} find(predicate) -> RCSFPiece?
`predicate` is a function, or a descriptor table (fast path for `structureId + variant + pieceType + north`).
:::

:::{describe} findSpriteName(structureId, variant, pieceType, north) -> string?
Resolve a sprite by descriptor.
:::

:::{describe} all() -> table<string, RCSFPiece>
:::
:::{describe} iter() -> fun(): RCSFPiece?
Iterate every registered piece.
:::

:::{describe} isUnlockedFor(piece, player) -> boolean
Is this piece unlocked for the player (skill / magazine / research)?
:::

:::{describe} addRecipeKnowledgeProvider(name, fn)
Register `fn(player) -> table<string, bool>?` of known recipe keys. **Use this** to feed magazine / research unlocks; multiple providers OR together.
:::

:::{describe} makeResearchKey(research) -> string?
Stable key (`item:` / `sprite:` / `entity:` form) for a research source.
:::

:::{describe} rebuildBuckets()
*Advanced.* Rebuild the indexes after mutating a piece in place.
:::

:::{describe} setKnownRecipesProvider(fn)
*Deprecated.* Single-slot shim for `addRecipeKnowledgeProvider`.
:::

(builder)=
### Builder

Generic per-piece builder, piece-kind registry, and disassembly. Returns
[`RCSFBuildOutcome` / `RCSFDisassembleOutcome`](#builder-outcomes); a failed build rolls back
every piece placed this call.

:::{describe} buildFromPlan(structureId, character, materialSource, plan, options) -> RCSFBuildOutcome
The main build entry. `options = { configureWallObject?, configureCellObject?, configureRoofObject?, container? }`.
:::

:::{describe} disassembleFromPlan(structureId, character, options) -> RCSFDisassembleOutcome
Tear down and refund. `options = { data, objects?, materialSource? }`.
:::

:::{describe} buildFromContainer(structureId, character, container, plan) -> boolean
Legacy delegation to `def.buildFromContainer`.
:::

:::{describe} buildCompletion(structureId, object, character) -> boolean
Finalize a placed structure.
:::

:::{describe} registerPieceKind(name, handler) -> boolean
Add your own piece kind to the dispatch loop. `handler = { arrayKey, place(piece, ctx) -> obj, errorReason? }`.
:::

:::{describe} unregisterPieceKind(name)
:::
:::{describe} getPieceKindHandler(name) -> table?
:::
:::{describe} getPieceKinds() -> string[]
Manage / inspect registered piece kinds.
:::

:::{describe} getGableAxis(...) / getRoofPieceCount(...) / getRoofPreview(...) / getMinimumContainerMaterialCount(structureId)
Roof-geometry and material-gating helpers (forward to the def's callbacks).
:::

Built-in piece kinds, in iteration order: `wall`, `cell`, `roof`, `furniture`, `appliance`,
`decorative`, `vegetation`.

---

## Headless API

The first-class, no-UI entry points. `Build` and `Rooms` are **server-authoritative** - they run
on the MP server / in singleplayer and no-op (or fail) on an MP client (see
[Multiplayer](../how-to/multiplayer.md)).

(build)=
### Build

One-call programmatic build for prefab spawners, quest rewards, and tests. The caller's `plan`
is never mutated. Guide: [Build without the UI](../how-to/headless-build.md).

:::{describe} RCSF.build(structureId, plan, character, opts?) -> RCSFBuildOutcome
Also `RCSF.Build.build`. `opts = { variant?, materialSource?, free?, container?, builderOptions?, createRoom?=true, allowClient? }`. `free` consumes nothing; `createRoom` (default true) materializes the IsoRoom when the def names a room and the plan has rects (sets `outcome.roomCreated`).
:::

(rooms)=
### Rooms

Claim an arbitrary area as a persisted, MP-synced `IsoRoom`, decoupled from the build pipeline.
Fires `OnRCSFRoomAssigned` / `OnRCSFRoomUnassigned`. Guide: [Assign a room](../how-to/rooms.md).

:::{describe} RCSF.Rooms.assign(rectOrRects, name, opts?) -> RCSFRoomAssignment?
`rectOrRects` is a single `{x,y,z,w,h}`, a list of them, or `{ rects = {...} }`. `opts = { id?, stairs? }` (`id` defaults to a namespaced derivation of `name`). Returns `{ id, name, rects }`.
:::

:::{describe} RCSF.Rooms.unassign(target, opts?) -> boolean
`target` is the descriptor from `assign`, or a rect / rect-list plus `opts = { id? | name? }`. Tears down the IsoBuilding(s) and forgets the record.
:::

(introspect)=
### Introspect

Documented, mutation-safe cross-mod queries over the registry. Returns plain summaries /
shallow copies, never the live def. Guide: [Introspect the registry](../how-to/introspection.md).

:::{describe} hasStructure(id) -> boolean
:::
:::{describe} listStructureIds() -> string[]
Existence check; sorted id list.
:::

:::{describe} getStructure(id) -> table?
:::
:::{describe} listStructures() -> table[]
Summary `{ id, roomName, variantIds[], useGenericBuilder, materialSource, materialSourceKind, buildMode, hasValidation, pieceCount }`.
:::

:::{describe} listVariants(id) -> string[]
A structure's variant ids.
:::

:::{describe} getPiece(pieceId) -> table?
One piece (shallow copy).
:::

:::{describe} listPieces(filter?) -> table[]
:::
:::{describe} countPieces(filter?) -> integer
`filter = { structureId?, category?, categoryGroup?, variant?, pieceType?, tag? }`.
:::

:::{describe} listCategories() -> string[]
:::
:::{describe} listCategoryGroups() -> string[]
Distinct values in use.
:::

(events)=
### Events

The framework's custom Lua events, registered via `LuaEventManager.AddEvent`. Subscribe with
`Events.OnRCSF*.Add(handler)`; each delivers one descriptor table. Full reference:
[Events](events.md).

:::{describe} OnRCSFStructureBuilt(info)
`info = { structureId, plan, character, placed }`.
:::
:::{describe} OnRCSFStructureDisassembled(info)
`info = { structureId, character, removed }`.
:::
:::{describe} OnRCSFRoomAssigned(info) / OnRCSFRoomUnassigned(info)
`info = { id, name, rects }`.
:::

`RCSF.Events.NAMES` holds the four names; the `fire*` helpers are the dispatchers the framework
calls internally.

---

## Plans & geometry

(plans)=
### Plans

Plan construction, keys, deep-copy, and normalization.

:::{describe} normalizePlan(plan) -> RCSFPlan
**Call this first.** Stamps `schemaVersion`, fills every array, and lifts a legacy single rect into `rects[1]`. Idempotent.
:::

:::{describe} getSelectionRect(startX, startY, endX, endY, z) -> RCSFRect
:::
:::{describe} getSelection(startX, startY, endX, endY, z, existingRects?) -> table
Build a single-rect or multi-rect selection.
:::

:::{describe} getRectanglePerimeterWalls(rect, pieceType) -> RCSFWall[]
The perimeter walls for a rect - handy when building a plan by hand.
:::

:::{describe} wallSlotIsInsideRect(rect, x, y, north) -> boolean
Slot-containment test.
:::

:::{describe} copyPlan(plan) / copyWall / copyRoof / copyStair / copyFurniture / copyAppliance / copyDecorative / copyVegetation
Deep-copy helpers (the authoritative field lists).
:::

:::{describe} wallKey / makeWallKey / roofKey / makeRoofKey / buildWallMap / buildRoofMap
Keying and lookup-map helpers.
:::

:::{describe} getRoofZ(rectIndex, plan) -> integer?
:::
:::{describe} getStairLinks(plan) -> {fromZ, toZ, x, y}[]
Derived geometry.
:::

(footprints)=
### Footprints

:::{describe} getFootprintFromRoomRect(rect, gableAxis?) / getFootprintFromRects(rects, gableAxis?) / getFootprintFromCells(cells, z?) / getFootprintFromPlan(structureId, plan) -> table?
Derive a footprint from a rect, rect list, cells, or a whole plan.
:::

(geometry)=
### Geometry

Coordinate and rect utilities.

:::{describe} squareKey(x, y, z) / roomRecordKey(rect) / numberFromValue(v)
Stable keys and value coercion.
:::

:::{describe} ensureSquare(x, y, z) -> IsoGridSquare
Get-or-create a grid square.
:::

:::{describe} rectsOverlap(a, b) / rectsEdgeAdjacent4(a, b) / rectContainsCell(r, x, y) / cellInOrAdjacentToRect(r, x, y) -> boolean
Rect / cell predicates.
:::

:::{describe} getStairLandingTile(stair) -> x, y, z
The Z+1 tile a stair leads onto.
:::

:::{describe} isInteriorSquare(...) / isAdjacentToFootprint(...) / findNearestOutsideSquare(...) / findNearestAdjacentFootprintSquare(...) / findNearestAdjacentFootprintWalkTarget(...)
Footprint adjacency and nearest-square helpers.
:::

---

## Materials

See [Concepts → Material sources](../concepts/material-sources.md) for the model.

(materialsource)=
### MaterialSource

Factory registry for material consumption. A source implements
`canConsume / consume / refund / availableSummary / describe`.

:::{describe} register(kind, factory)
:::
:::{describe} create(kind, ctx) -> source?
Register / instantiate a source factory `fn(ctx) -> source`.
:::

:::{describe} fromDef(structureId, character, container, plan) -> source?
Resolve from `def.materialSource` / `def.createMaterialSource`.
:::

Built-in kinds: **`"raw"`** (player inventory), **`"universal"`** (one container holding per-piece
counts), **`"bag"`** (a bag of variant containers).

(recipesource)=
### RecipeSource

Atomic heterogeneous-recipe consumption (items + tags, with `keep` for tools).

:::{describe} countAvailable(recipe, character, containers?) -> table
How many of each requirement are available.
:::

:::{describe} hasAll(recipe, character, containers?) -> boolean, table?
Returns `(ok, missing?)`.
:::

:::{describe} consumeAtomic(recipe, character, containers?) -> boolean, table
Validate the whole recipe, then consume all-or-nothing.
:::

(materialcontainers)=
### MaterialContainers

Legacy container / loose-material tracking (item modData). Server-authoritative operations
route via `OnClientCommand`.

:::{describe} isContainer(structureId, item) -> boolean / isLooseMaterial(structureId, item) -> boolean
Classify an item.
:::

:::{describe} getMaterialCount(structureId, item) / getVariant(...) / getContainerVariantFromItem(...) / getMaterialVariantFromItem(...) / setState(structureId, item, variant, count)
Read and write container state.
:::

:::{describe} packLooseMaterials(...) / takeMaterials(...) / addLooseMaterials(...)
Inventory operations.
:::

---

## Placement & validation

(placementhelpers)=
### PlacementHelpers

Low-level object placement and tagging (used by the builder).

:::{describe} placeWallObject(square, north, spriteName, slotKind, options) -> IsoObject?
Place a wall / door / window slot object.
:::

:::{describe} placeFloorObject(...) / placeRugObject(...) / placeRoofObject(...) / placeDoor(...) / placeWindow(...) / placeStair(...) / placeFurniture(...) / placeAppliance(...) / placeDecorative(...) / placeVegetation(...)
Per-kind placement helpers, each returning the placed `IsoObject`.
:::

:::{describe} placeLightSwitch(...) / isLightSwitchSprite(spriteName) / squareHasRug(square) / ensureSquare(x, y, z) / getStairLandingTile(...)
Specialized helpers.
:::

:::{describe} removeObject(object) -> boolean
Remove a placed object cleanly.
:::

(placementvalidation)=
### PlacementValidation

:::{describe} validateContainerPlacement(structureId, character, container, plan) -> boolean, string?, table?
Runs the default validators, then the def's `validate*` hook. Returns `(ok, reasonKey?, data?)`.
:::

:::{describe} validateCompletion(structureId, character, object) / validateDisassembly(structureId, character, object)
Completion and disassembly gates.
:::

:::{describe} getPlacementSummary(structureId, plan) -> table / getPieceSpriteName(...) / getRemovableObjects(structureId, data)
UI summary and lookups.
:::

(defaultvalidators)=
### DefaultValidators

Each takes `(plan)` and returns `boolean, string?`. Opt in by name via
`def.validation.useDefaults`.

Available validators: `noEmptyPlan`, `noOverlap`, `slotKindCompatible`, `roofNeedsWallUnder`,
`floorNeedsCell`, `zAboveEmpty`, `minimumRoomRectSize`, `stairLinks`, `obstructionFree`,
`footprintFitsInRect`, `multiRectEdgeConnectivity`.

:::{describe} runAll(plan, names) -> boolean, string?
Run a named set yourself.
:::

---

## Rooms & auto-systems

(roompersistence)=
### RoomPersistence

Runtime `IsoRoom` / `IsoBuilding` creation, persistence, and MP sync. Server-authoritative
(see [Authority & rooms](../concepts/authority-and-rooms.md)).
`MOD_DATA_KEY = "RCStructureFrameworkRooms"`.

:::{describe} createRoom(structureId, rectOrFootprint, loading?) -> boolean
Idempotent room creation.
:::

:::{describe} createAssignedRoom(structureId, rectOrFootprint, loading?) -> boolean
Like `createRoom`, but flags the record as a standalone assignment (backs [`RCSF.Rooms`](#rooms)).
:::

:::{describe} removeRoomByRect(structureId, rect, clearRecord?, loading?) -> boolean
:::
:::{describe} removeRoomByRects(structureId, rects, clearRecord?, loading?) -> boolean
Single / multi-rect teardown.
:::

:::{describe} rememberRoom(...) / rememberRoomFromRects(...) / forgetRoom(...) / forgetRoomByRects(...) / ensureAssignmentDefs(records?)
Record bookkeeping; `ensureAssignmentDefs` reconstitutes synthetic assignment defs on load.
:::

:::{describe} getRoomDef(...) / hasInteriorRoom(rect) / markRoomRuntimeOnly(...) / getRoomRecords() / getRectFromRecord(record) / partitionRectsByConnectivity(rects, stairs?)
Queries and helpers.
:::

:::{describe} transmitRoomRecords() / syncRoomRecords(rooms?, loading?) / restorePersistedRooms(loading?) / restoreLoadedRoomDefs(loading?)
Sync and restore.
:::

(plannedconstructions)=
### PlannedConstructions

Server-authoritative ghost-preview store (persists unbuilt plans across relogs).
`MOD_DATA_KEY = "RCStructureFrameworkPlanned"`.

:::{describe} register(params) -> string?
`params = { ownerId, blueprintItemId?, plan }`. Server-only; clients get `nil`.
:::

:::{describe} cancel(recordId, requesterId) -> boolean
Authorization: the owner, or `"ADMIN"`.
:::

:::{describe} markBuilt(recordId, pieceIndex, builtBy?) -> boolean
May trigger room creation when a connected group completes.
:::

:::{describe} getRecord(...) / getRecordsForChunk(...) / intersects(candidatePlan) / getNextUnbuiltPieceFor(player, opts) / getRequiredMaterials(recordId, opts)
Queries.
:::

(piecepresence)=
### PiecePresence

"Is this slot already a real object?" detection (for ghost rendering / dedup).

:::{describe} hasRealWallAt(...) / hasRealFloorAt(...) / hasRealStairAt(...) / hasObjectWithSpriteAt(...) -> boolean / isPieceRealized(piece) -> boolean
Presence checks.
:::

:::{describe} wallIsoOrder / pieceIsoOrder(a, b) / sortedWallIndices(walls) / sortedPieceIndices(pieces) / inZPass(panel, pieceZ)
Render-ordering helpers.
:::

(roomlighting)=
### RoomLighting

Auto-system that gives *runtime-created* framework rooms working light switches (vanilla only
wires a switch to its room glow at chunk-load, which has already passed for a room you build at
runtime). The server owns light state; clients render. It runs on its own when enabled - toggle
the whole system with `RCSF.enable("roomLighting")` / `RCSF.disable("roomLighting")`. The one
thing you may want to configure:

:::{describe} RoomLighting.setRoomFilter(fn)
Set the predicate `fn(roomName) -> boolean` that decides which IsoRooms RoomLighting manages. The framework injects a default matching registered structure rooms; override it only if you [vendored](../how-to/vendoring.md) RoomLighting standalone (so it has no Registry to consult) or want custom room detection.
:::

(spritepropertypatcher)=
### SpritePropertyPatcher

Auto-system that marks door / window-frame sprites traversable in runtime rooms (vanilla relies
on map-baked sprite properties a runtime build doesn't have). Toggle with
`RCSF.enable("spritePatcher")` / `RCSF.disable("spritePatcher")` - this only gates the save-load
re-patch sweep; the patch on the live build path always runs.

:::{describe} SpritePropertyPatcher.applyToSprite(spriteName, north, slotKind)
Apply the sprite-property patch directly. Always available, even with the auto-system disabled.
:::

---

## Presets, config & UI

(presets)=
### Presets

Save / load / transform layout presets (versioned JSON, auto-migrated). The JSON codec itself
is the standalone `Json` module.

:::{describe} toRelative(structureId, plan) -> preset
:::
:::{describe} toPlanAt(structureId, preset, anchorX, anchorY, z) -> RCSFPlan
Convert between an absolute plan and a re-anchorable preset.
:::

:::{describe} load(structureId) -> preset[] / save(structureId, list) / add(...) / remove(...) / rename(...)
CRUD on a structure's presets file.
:::

:::{describe} jsonEncode(value) -> string / jsonDecode(text) -> any?
Thin wrappers over the `Json` codec.
:::

(config)=
### Config / EventRegistration

:::{describe} RCSF_Config
Load-time config table. `RCSF_Config.systems.<key> = false` disables an auto-system; `RCSF_Config.validateDefs = false` disables def validation.
:::

:::{describe} RCSF.enable(key) / RCSF.disable(key)
Runtime toggle for an auto-system. Keys: `roomLighting`, `spritePatcher`, `roomSync`, `materialContainers`, `plannedConstructions`. See [Vendoring](../how-to/vendoring.md).
:::

Each auto-system also exposes `registerEvents()` / `unregisterEvents()` (e.g.
`RoomLighting.registerEvents()`) - the bind / unbind lifecycle that `RCSF.enable` / `RCSF.disable`
call for you. Prefer the `enable` / `disable` shortcuts; reach for the raw lifecycle only when
driving a vendored module yourself.

(client-ui)=
### Client UI entry points

:::{describe} RCStructurePlacementUI.open(structureId, playerIndex, character, container)
The builder panel (`require("RCStructureFramework/PlacementUI")` first). `RCStructurePlacementPanel` is subclassable.
:::

:::{describe} RCStructureDisassemblyUI.open(structureId, object, character) / RCStructurePresetsWindow.openFor(...) / RCStructurePieceCatalogPanel.openFor(opts) / RCStructureSavePresetDialog.openFor(panel)
The other UI entry points.
:::

### Internal modules

Not part of the supported surface: **Migrations** (preset versions; use `Presets.load`),
**System** (room-sync event glue), and **BuildRecipeCallbacks** (routes `def.buildRecipeCallbacks`).
