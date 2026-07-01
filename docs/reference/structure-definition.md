# Structure definition

A *structure definition* ("def") is the single table you pass to
`Registry.registerStructure(def)` (or [`RCSF.defineStructure(def)`](../how-to/introspection.md)).
It describes one buildable structure: its identity, how it builds, what it costs, how it
validates, and how it tears down.

Only `id` is **required**. Every other field is optional; when a callback is absent the
framework uses a sensible no-op default. The matching EmmyLua type is `RCSFStructureDef`
in `Contracts.lua`.

```{note}
Callback signatures below are the **exact** shapes the framework invokes. The framework
binds the `structureId`, so your `def.*` callbacks do **not** receive it.
```

## Identity

```{list-table}
:header-rows: 1
:widths: 22 28 50

* - Field
  - Type
  - Notes
* - `id`
  - `string`
  - **Required.** Unique structure id.
* - `roomName`
  - `string?`
  - `IsoRoom` name stem. **No room is created without it.** Multi-rect plans get suffixed names (`MyModShed`, `MyModShed_1`, …).
* - `variants`
  - `table<string, boolean>?`
  - Variant set (keys are variant ids, e.g. `{ green = true, yellow = true }`).
* - `variantIds`
  - `string[]?`
  - Derived (sorted) from `variants` when omitted.
```

## Build mode

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `useGenericBuilder`
  - `boolean?`
  - `true` = use the built-in per-piece `Builder` loop. `false`/`nil` = legacy path (the framework calls `buildFromContainer` and nothing else).
* - `buildFromContainer`
  - `fun(character, container, plan): boolean`
  - Legacy whole-structure build. Only used when `useGenericBuilder ~= true`.
* - `synthesizeRoofs`
  - `fun(plan)`
  - Generic-builder hook: populate `plan.roofs` before placement (e.g. derive a gable roof from the rect).
* - `beforeBuild`
  - `fun(plan, character, placed, materialSource, options): boolean`
  - Return `false` to abort and roll back.
* - `afterBuild`
  - `fun(plan, character, placed, materialSource, options): boolean`
  - Return `false` to abort and roll back. Typical place to create the room / finalize.
* - `getPieceMaterialRequirement`
  - `fun(piece): table?`
  - Per-piece material requirement fed to the active [MaterialSource](../concepts/material-sources.md).
* - `configureWallObject` / `configureCellObject` / `configureRoofObject`
  - `fun(obj, piece, plan)`
  - Mutate the placed `IsoObject` (flags, modData). Furniture/appliance/decorative/vegetation use the same pattern via `configure<Category>Object`.
* - `buildCompletion`
  - `fun(object, character): boolean`
  - Finalize a placed structure (e.g. via `Builder.buildCompletion`).
```

## Disassembly

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `getRemovableObjects`
  - `fun(data): IsoObject[]`
  - Objects to remove for a teardown.
* - `beforeDisassemble`
  - `fun(objects, data, character, materialSource): boolean`
  - Return `false` to abort.
* - `afterDisassemble`
  - `fun(objects, data, character, materialSource, removed)`
  - Post-teardown hook (bulk refunds, cleanup).
* - `refundViaMaterialSource`
  - `boolean?`
  - `true` = per-piece refund via the modData stamp on each removed object.
```

## Material

Pick **one** of `materialSource` or `createMaterialSource`. See
[Concepts → Material sources](../concepts/material-sources.md).

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `materialSource`
  - `string?`
  - `"raw"` (player inventory), `"universal"` (one container holding per-piece counts), or `"bag"` (a bag of variant containers).
* - `createMaterialSource`
  - `fun(character, container, plan): table?`
  - Custom source factory; wins over `materialSource`. Must return an object implementing `canConsume/consume/refund/availableSummary/describe`.
* - `materialContainer`
  - `table?`
  - Legacy single-container config (tags etc.); see `MaterialContainers.lua`.
* - `getMinimumContainerMaterialCount`
  - `fun(): integer`
  - Minimum material count gate for container flows.
```

## Validation

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `validation`
  - `{ useDefaults: string[] }?`
  - Opt into built-in validators by name (see [DefaultValidators](#defaultvalidators)).
* - `validateContainerPlacement`
  - `fun(character, container, plan): boolean, string?, table?`
  - `(ok, reasonKey?, data?)`. Runs *after* the default validators.
* - `validateCompletion`
  - `fun(character, object): boolean, string?, table?`
  -
* - `validateDisassembly`
  - `fun(character, object): boolean, string?, table?`
  -
```

Available default validator names: `noEmptyPlan`, `noOverlap`, `slotKindCompatible`,
`roofNeedsWallUnder`, `floorNeedsCell`, `zAboveEmpty`, `minimumRoomRectSize`, `stairLinks`,
`obstructionFree`, `footprintFitsInRect`, `multiRectEdgeConnectivity`.

## Sprites & geometry

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `getPieceSpriteName`
  - `fun(variant, pieceType, north): string?`
  - Resolve a wall/piece sprite when a piece doesn't carry an explicit `spriteName`.
* - `getCellSpriteName`
  - `fun(variant, cell): string?`
  - Resolve a floor sprite for a cell.
* - `getPlacementSummary`
  - `fun(plan): table`
  - UI summary (counts, completeness).
* - `getFootprintFromPlan`
  - `fun(plan): table?`
  - Override footprint derivation.
* - `getGableAxis` / `getRoofPieceCount` / `getRoofPreview`
  - `fun(...)`
  - Roof gable axis, piece count for costing, and preview tiles.
* - `buildRecipeCallbacks`
  - `table?`
  - Named callbacks routed by `BuildRecipeCallbacks.call`.
```

## UI & flags

```{list-table}
:header-rows: 1
:widths: 28 32 40

* - Field
  - Type
  - Notes
* - `editor`
  - `{ allowCells: boolean?, pieceTypes: table? }?`
  - Whether the floor paint phase is offered and which piece types are paintable.
* - `presetsFile`
  - `string?`
  - Custom presets file name.
* - `useCatalogUI`
  - `boolean?`
  - Use the scrollable catalog picker.
* - `selectTitleKey` / `editTitleKey` / `placeLabelKey`
  - `string?`
  - `IGUI_` translation keys for the UI phases/buttons.
* - `invalidSizeTooltipKey` / `incompletePerimeterTooltipKey` / `invalidPlacementTooltipKey` / `materialTooltipKey`
  - `string?`
  - `IGUI_`/`Tooltip_` keys.
* - `allowMultiStorey` / `singleStorey` / `disableZControl` / `requireSingleRect`
  - `boolean?`
  - Footprint / Z constraints.
```

## Worked example A - minimal (raw inventory, generic builder)

```lua
RCSF.Registry.registerStructure({
    id                = "MyMod_Shed",
    roomName          = "MyModShed",
    useGenericBuilder = true,
    materialSource    = "raw",
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
})
```

## Worked example B - heavily customized (MilitaryTents-style)

A def that overrides most of the pipeline (bag-of-containers materials, custom roofs,
custom validation, per-object configuration):

```lua
RCSF.Registry.registerStructure({
    id                = "military_tent",
    roomName          = "MilitaryTentRoom",
    variants          = { green = true, yellow = true },
    useGenericBuilder = true,
    materialSource    = "bag",
    requireSingleRect = true,
    singleStorey      = true,
    disableZControl   = true,
    editor            = { allowCells = false, pieceTypes = { "wall", "door", "window" } },
    validation        = { useDefaults = { "noOverlap", "slotKindCompatible" } },

    -- sprites & geometry
    getPieceSpriteName  = Tent.getWallSpriteName,
    getPlacementSummary = Tent.getPlacementSummary,
    getGableAxis        = Tent.getGableAxis,
    getRoofPieceCount   = Tent.getRoofPieceCount,
    getRoofPreview      = Tent.getRoofPreview,
    synthesizeRoofs     = Tent.synthesizeRoofs,

    -- build
    beforeBuild                      = Tent.beforeBuild,
    afterBuild                       = Tent.afterBuild,
    configureWallObject              = Tent.configureWallObject,
    configureRoofObject              = Tent.configureRoofObject,
    getPieceMaterialRequirement      = Tent.getPieceMaterialRequirement,
    getMinimumContainerMaterialCount = Tent.getMinimumPackPieceCount,
    buildCompletion                  = Tent.buildRoofAndRoom,

    -- validate & disassemble
    validateContainerPlacement = Tent.validatePackPlacement,
    validateCompletion         = Tent.validateRoofBuild,
    validateDisassembly        = Tent.validateDisassembly,
    getRemovableObjects        = Tent.getRemovableTentObjects,
    beforeDisassemble          = Tent.beforeDisassemble,
    afterDisassemble           = Tent.afterDisassemble,
})
```

## Registration is validated

`Registry.registerStructure` validates your def. It **errors** only when `id` is missing;
otherwise it **warns** (and continues) on:

- an unknown top-level key (with a "did you mean …?" suggestion for likely typos),
- a `materialSource` value outside `{ "raw", "universal", "bag" }`,
- both `materialSource` and `createMaterialSource` set (createMaterialSource wins),
- a `validation.useDefaults` name that isn't a known validator.

Warn-don't-throw keeps the framework forward-compatible with consumers built against a
newer version. Disable validation entirely with `RCSF_Config.validateDefs = false`.
```{tip}
[`RCSF.defineStructure(def)`](../how-to/introspection.md) wraps registration with the same
validation, fills a default variant, and batch-registers an inline `pieces` array - a nice
one-call shorthand.
```
