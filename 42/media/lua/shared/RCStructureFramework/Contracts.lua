---@meta
--- See docs/reference/data-contracts.md and docs/reference/structure-definition.md for prose.

---@class RCSFRect
---@field x integer        -- west (min) tile X
---@field y integer        -- north (min) tile Y
---@field z integer        -- floor / storey level
---@field w integer        -- width in tiles (>= 1)
---@field h integer        -- height in tiles (>= 1)
---@field kind string?     -- footprint role, e.g. "room"; nil treated as "room"

---@class RCSFWall
---@field x integer
---@field y integer
---@field z integer
---@field north boolean             -- true = north edge, false = west edge
---@field wallType string?          -- semantic piece type fed to Registry.getPieceSpriteName (e.g. "wall","door","window")
---@field slotKind string?          -- placement slot, defaults to "wall"; "door"/"window" affect engine flags
---@field spriteName string?        -- explicit sprite override; when set it wins over wallType resolution
---@field wallpaperSpriteName string? -- optional decorative wallpaper layer

---@class RCSFCell
---@field x integer
---@field y integer
---@field z integer
---@field spriteName string?  -- floor sprite; nil cell is a silent skip in the builder
---@field isRug boolean?      -- true = placed ON TOP of an existing floor (does not replace it)

---@class RCSFRoof
---@field x integer
---@field y integer
---@field z integer
---@field north boolean       -- gable facing
---@field spriteName string?  -- roof sprite; nil is a silent skip
---@field slope string?       -- optional slope hint
---@field roofKind string?    -- optional engine roof classification

---@class RCSFStair
---@field x integer
---@field y integer
---@field z integer
---@field north boolean
---@field bottomSprite string?
---@field middleSprite string?
---@field topSprite string?
---@field pillarSprite string?

---@class RCSFFootprint
---@field w integer
---@field h integer

---@class RCSFUtilities
---@field power boolean?
---@field water boolean?

---@class RCSFFurniture
---@field x integer
---@field y integer
---@field z integer
---@field facing string?       -- "N"/"E"/"S"/"W" engine facing
---@field defId string?        -- entity script id / piece def reference
---@field spriteName string?   -- nil is a silent skip
---@field footprint RCSFFootprint?
---@field anchor string?       -- placement anchor, defaults to "origin"

---@class RCSFAppliance
---@field x integer
---@field y integer
---@field z integer
---@field facing string?
---@field defId string?
---@field spriteName string?
---@field footprint RCSFFootprint?
---@field anchor string?
---@field utilities RCSFUtilities?

---@class RCSFDecorative
---@field x integer
---@field y integer
---@field z integer
---@field facing string?
---@field defId string?
---@field spriteName string?
---@field anchor string?

---@class RCSFVegetation
---@field x integer
---@field y integer
---@field z integer
---@field defId string?
---@field spriteName string?

---@stability stable
---@class RCSFPlan
---@field schemaVersion integer?   -- current = 4; the migration anchor
---@field structureId string?      -- owning structure def id
---@field variant string?          -- structure variant id (e.g. "green")
---@field color string?            -- legacy alias read as a variant fallback
---@field rects RCSFRect[]?         -- one or more footprints (canonical since multi-rect)
---@field walls RCSFWall[]?
---@field cells RCSFCell[]?
---@field roofs RCSFRoof[]?
---@field stairs RCSFStair[]?
---@field furniture RCSFFurniture[]?
---@field appliances RCSFAppliance[]?
---@field decoratives RCSFDecorative[]?
---@field vegetation RCSFVegetation[]?
---@field rect RCSFRect?           -- @deprecated legacy single rect; normalizePlan lifts it into rects[1]
---@field x integer?               -- @deprecated legacy top-level single-rect fields
---@field y integer?
---@field z integer?
---@field w integer?
---@field h integer?

---@class RCSFPlannedPiece
---@field kind string              -- piece-kind name ("wall","cell","roof",...)
---@field x integer
---@field y integer
---@field z integer
---@field north boolean?
---@field spriteName string
---@field slotKind string?
---@field defId string?
---@field materialRecipe table?    -- frozen recipe snapshot at register time
---@field builtAt integer?         -- nil = unbuilt, else build timestamp (ms)
---@field builtBy string?          -- nil = unbuilt, else ownerId that built it

---@class RCSFPlannedRecord
---@field id string                -- generated record id
---@field ownerId string           -- onlineID (MP) or "SP_<username>" (SP)
---@field blueprintItemId any      -- caller-supplied, treated as opaque
---@field plan RCSFPlan            -- world-space plan copy (original may mutate)
---@field createdAtMs integer
---@field pieces RCSFPlannedPiece[]

---@alias RCSFPiece RCStructureFrameworkPiece

---@class RCSFBuildOutcome
---@field success boolean
---@field placed IsoObject[]       -- objects placed this call (empty on failure after rollback)
---@field failed table[]           -- pieces that failed (the offending piece, if any)
---@field reason string?           -- failure reason when success == false
---@field roomCreated boolean?     -- set by RCSF.build when it materialized the IsoRoom

---@class RCSFDisassembleOutcome
---@field success boolean
---@field removed IsoObject[]
---@field reason string?

---@stability stable
---@class RCSFRoomAssignment
---@field id string                -- structure id backing the assignment (synthetic unless opts.id given)
---@field name string              -- IsoRoom name stem
---@field rects RCSFRect[]         -- assigned footprint(s)

---@alias RCSFRoomEvent RCSFRoomAssignment

---@stability stable
---@class RCSFStructureBuiltEvent
---@field structureId string
---@field plan RCSFPlan
---@field character IsoPlayer?
---@field placed IsoObject[]       -- objects placed this build (empty for legacy builders)

---@stability stable
---@class RCSFStructureDisassembledEvent
---@field structureId string
---@field character IsoPlayer?
---@field removed IsoObject[]

---@class RCSFEditorConfig
---@field allowCells boolean?      -- whether the floor/cell paint phase is offered
---@field pieceTypes table?        -- ordered list of paintable piece-type descriptors

---@class RCSFValidationConfig
---@field useDefaults string[]?    -- e.g. { "noOverlap", "slotKindCompatible", "roofOnlyOnTopStorey", "stairLinks" }

---@class RCSFStructureDef
---@field id string                                 -- REQUIRED. Unique structure id.
---@field roomName string?                          -- IsoRoom name stem; no room is created without it
---@field variants table<string, boolean>?          -- variant set; keys are variant ids
---@field variantIds string[]?                      -- derived from `variants` when omitted (sorted)
---@field useGenericBuilder boolean?                 -- true = use Builder's piece-kind loop; false/nil = legacy buildFromContainer
---@field buildFromContainer fun(character: IsoPlayer, container: InventoryItem, plan: RCSFPlan): boolean   -- legacy build path (used only when useGenericBuilder ~= true)
---@field synthesizeRoofs fun(plan: RCSFPlan)        -- generic-builder hook: populate plan.roofs before placement
---@field beforeBuild fun(plan: RCSFPlan, character: IsoPlayer, placed: IsoObject[], materialSource: table?, options: table): boolean  -- return false to abort+rollback
---@field afterBuild fun(plan: RCSFPlan, character: IsoPlayer, placed: IsoObject[], materialSource: table?, options: table): boolean   -- return false to abort+rollback
---@field getPieceMaterialRequirement fun(piece: table): table?   -- per-piece material req for the active MaterialSource
---@field configureWallObject fun(obj: IsoObject, wall: RCSFWall, plan: RCSFPlan)
---@field configureCellObject fun(obj: IsoObject, cell: RCSFCell, plan: RCSFPlan)
---@field configureRoofObject fun(obj: IsoObject, roof: RCSFRoof, plan: RCSFPlan)
---@field buildCompletion fun(object: IsoObject, character: IsoPlayer): boolean   -- finalize a placed structure (e.g. create room)
---@field getRemovableObjects fun(data: table): IsoObject[]
---@field beforeDisassemble fun(objects: IsoObject[], data: table, character: IsoPlayer, materialSource: table?): boolean  -- return false to abort
---@field afterDisassemble fun(objects: IsoObject[], data: table, character: IsoPlayer, materialSource: table?, removed: IsoObject[])
---@field refundViaMaterialSource boolean?           -- true = per-piece refund via stamped mod-data during disassembly
---@field getDisassemblyRefundPreview fun(...): any  -- consumer-defined refund preview (not called by core)
---@field materialSource string?                     -- "raw" | "universal" | "bag"; mutually exclusive with createMaterialSource
---@field createMaterialSource fun(character: IsoPlayer, container: InventoryItem, plan: RCSFPlan): table?  -- custom source factory; wins over materialSource
---@field materialContainer table?                   -- legacy single-container config; see MaterialContainers.lua
---@field getMinimumContainerMaterialCount fun(): integer
---@field validation RCSFValidationConfig?
---@field validateContainerPlacement fun(character: IsoPlayer, container: InventoryItem, plan: RCSFPlan): boolean, string?, table?  -- (ok, reasonKey?, data?)
---@field validateCompletion fun(character: IsoPlayer, object: IsoObject): boolean, string?, table?
---@field validateDisassembly fun(character: IsoPlayer, object: IsoObject): boolean, string?, table?
---@field isSelectionValid fun(...): boolean         -- consumer-defined selection gate (not called by core)
---@field getPieceSpriteName fun(variant: string?, pieceType: string, north: boolean): string?
---@field getCellSpriteName fun(variant: string?, cell: RCSFCell): string?
---@field getPlacementSummary fun(plan: RCSFPlan): table
---@field getFootprintFromPlan fun(plan: RCSFPlan): table?
---@field getGableAxis fun(width: integer, height: integer, requestedAxis: string?): string?
---@field getRoofPieceCount fun(rect: RCSFRect, gableAxis: string?): integer
---@field getRoofPreview fun(rect: RCSFRect, variant: string, gableAxis: string?): table
---@field buildRecipeCallbacks table?                -- named callbacks routed by BuildRecipeCallbacks.call
---@field editor RCSFEditorConfig?
---@field presetsFile string?                        -- custom presets file name (defaults per structure)
---@field useCatalogUI boolean?
---@field selectTitleKey string?                     -- IGUI_ key: footprint-select phase title
---@field editTitleKey string?                       -- IGUI_ key: edit phase title
---@field placeLabelKey string?                      -- IGUI_ key: place/confirm button
---@field invalidSizeTooltipKey string?
---@field incompletePerimeterTooltipKey string?
---@field invalidPlacementTooltipKey string?
---@field materialTooltipKey string?
---@field allowMultiStorey boolean?
---@field singleStorey boolean?
---@field disableZControl boolean?
---@field requireSingleRect boolean?

return {}
