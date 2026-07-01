# Define & introspect structures

Two convenience APIs for working with the registry: a one-call **definer** and a read-only
**introspector**.

## `RCSF.defineStructure` - register in one call

`defineStructure` wraps `registerStructure` + `registerPieces` with validation, so you don't
hand-assemble a large def and register pieces separately. It:

- validates the def (warns on typos, bad `materialSource`, unknown validators),
- fills a single implicit `{ default = true }` variant when you give none,
- batch-registers an inline `pieces` array,
- returns the stored def (or `nil` if `id` is missing).

```lua
local def = RCSF.defineStructure({
    id                = "MyMod_Shed",
    roomName          = "MyModShed",
    useGenericBuilder = true,
    materialSource    = "raw",
    getPieceMaterialRequirement = function(piece)
        return { fullType = "Base.Plank", count = 1 }
    end,
    pieces = {                                    -- ← batch-registered for you
        { spriteName = "walls_exterior_wooden_01_0", category = "wall", pieceType = "wall",
          categoryGroup = "wall" },
        { spriteName = "floors_exterior_natural_01_0", category = "floor",
          categoryGroup = "floor" },
    },
})
```

It's exactly equivalent to calling `registerStructure` then `registerPieces` - use whichever
reads better. See [Structure definition](../reference/structure-definition.md) for the fields.

## `RCSF.Introspect` - read-only registry queries

`Introspect` answers "what's registered?" for other mods, debug tools, and compatibility
checks. Every result is a **plain summary or shallow copy** - you can't mutate the registry
through it, and it never hands back the live def (with its callbacks).

### List and inspect structures

```lua
for _, id in ipairs(RCSF.Introspect.listStructureIds()) do
    local s = RCSF.Introspect.getStructure(id)
    print(("%s: %s build, %s materials, %d pieces"):format(
        s.id, s.buildMode, tostring(s.materialSource), s.pieceCount))
end
```

A structure summary is
`{ id, roomName, variantIds[], useGenericBuilder, materialSource, materialSourceKind,
buildMode, hasValidation, pieceCount }`, where `buildMode` is `"generic"`, `"legacy"`, or
`"none"`.

### Query pieces

```lua
-- every wall piece registered by a specific structure:
local walls = RCSF.Introspect.listPieces({ structureId = "MyMod_Shed", category = "wall" })

-- count by tag, list categories in use:
local n = RCSF.Introspect.countPieces({ tag = "salvaged" })
local cats = RCSF.Introspect.listCategories()
```

### Full surface

```{list-table}
:header-rows: 1
:widths: 44 56

* - Call
  - Returns
* - `hasStructure(id)`
  - `boolean`
* - `listStructureIds()`
  - sorted `string[]`
* - `getStructure(id)` / `listStructures()`
  - summary table(s)
* - `listVariants(id)`
  - `string[]`
* - `getPiece(pieceId)`
  - shallow-copy piece (treat as read-only)
* - `listPieces(filter?)` / `countPieces(filter?)`
  - filtered pieces / count - `filter = { structureId?, category?, categoryGroup?, variant?, pieceType?, tag? }`
* - `listCategories()` / `listCategoryGroups()`
  - sorted distinct values
```

```{tip}
Use `Introspect` for cross-mod compatibility - e.g. "if another structure mod registered a
`wall` category I can extend, add my pieces to it." The lower-level
`Registry.getAllStructures()` / `PieceLibrary` are still available when you need the live
tables.
```
