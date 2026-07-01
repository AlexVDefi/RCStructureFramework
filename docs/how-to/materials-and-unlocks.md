# Material costs, recipes & unlock gating

How pieces cost materials, the three built-in material models, heterogeneous recipes, and
gating pieces behind skills/magazines/research.

## Per-piece cost: `materialRequirement`

The simplest cost is a single item type and count per piece:

```lua
{ spriteName = "walls_exterior_wooden_01_0", category = "wall", categoryGroup = "wall",
  materialRequirement = { fullType = "Base.Plank", count = 2 } }
```

`materialRequirement` is `{ fullType?, tag?, count }` - use `tag` to accept any item with a
build tag (e.g. `{ tag = "Plank", count = 2 }`). The active **material source** consumes it.

## Choosing a material source

Set `materialSource` on the def to pick how pieces are paid for. See
[Concepts → Material sources](../concepts/material-sources.md) for the full picture.

```{list-table}
:header-rows: 1
:widths: 18 82

* - `materialSource`
  - Consumes from…
* - `"raw"`
  - the player's **inventory**, item by item. The everyday choice.
* - `"universal"`
  - a single **container** item holding per-piece counts (a "build kit").
* - `"bag"`
  - a **bag of variant containers** (e.g. one pack per tent color).
```

For anything custom, implement `def.createMaterialSource(character, container, plan)` and
return an object with `canConsume / consume / refund / availableSummary / describe`.

## Heterogeneous recipes (`materialRecipe`)

When a piece costs *several different* things (and some are tools you keep), give it a
`materialRecipe` instead of a single `materialRequirement`. The
[`RecipeSource`](#recipesource) consumes it atomically - all or nothing:

```lua
{ spriteName = "walls_exterior_wooden_01_0", category = "wall", categoryGroup = "wall",
  materialRecipe = {
      { fullType = "Base.Plank", count = 4 },
      { fullType = "Base.Nails", count = 8 },
      { tag = "Hammer", count = 1, keep = true },   -- needed, but not consumed
  } }
```

`keep = true` means the item must be present but isn't consumed (tools). You can drive a
recipe directly:

```lua
local ok, missing = RCSF.RecipeSource.hasAll(recipe, player)
if ok then RCSF.RecipeSource.consumeAtomic(recipe, player) end
```

(unlock-gating)=
## Gate pieces behind skills, magazines, or research

Add `unlockSources` to a piece and the catalog **hides it** until the player qualifies. Any
matching source unlocks it (OR semantics within and across buckets):

```lua
{ spriteName = "walls_exterior_wooden_01_0", category = "wall", categoryGroup = "wall",
  unlockSources = {
      skill     = { Woodwork = 4 },                 -- Woodwork >= 4
      magazines = { "Base.BookCarpentry3" },         -- OR has read this magazine
      research  = { itemFullType = "Base.WoodenWall" }, -- OR researched this
  } }
```

- **Skill** is checked directly against the player's perk levels.
- **Magazine / research** knowledge comes from a **provider you register**, so the framework
  doesn't care *how* your mod tracks "known recipes":

```lua
RCSF.PieceLibrary.addRecipeKnowledgeProvider("MyMod", function(player)
    return player:getModData().MyMod_KnownRecipes   -- table<string, boolean> | nil
end)
```

Multiple providers can be registered (their results OR together), so independent mods
contribute unlocks without clobbering each other. Build a stable research key with
`RCSF.PieceLibrary.makeResearchKey(research)` and write the same key into your KnownRecipes
table.

```{important}
Unlock checks must be **re-run server-side** on save/build - a client can lie about its
perks/known recipes. The framework re-checks on the authoritative build path; if you build
[headlessly](headless-build.md), do it server-side.
```

```{seealso}
[Reference → API → PieceLibrary](#piecelibrary) for `isUnlockedFor`,
`addRecipeKnowledgeProvider`, and `makeResearchKey`.
```
