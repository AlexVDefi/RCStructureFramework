# Material sources

A **material source** is the framework's answer to "how does a piece get paid for?" It's a
small pluggable interface, so the builder doesn't care whether materials come from a player's
backpack, a single build-kit container, a bag of color-coded packs, or something you invent.

## The interface

A material source is any object implementing:

```lua
source:canConsume(req)  -> boolean   -- can we afford this requirement right now?
source:consume(req)     -> boolean   -- consume it (called per piece during build)
source:refund(req)      -> boolean   -- give it back (disassembly)
source:availableSummary() -> table   -- for the UI's material readout
source:describe()         -> string
```

`req` is a piece's `materialRequirement` (`{ fullType?, tag?, count }`). The builder calls
`canConsume`/`consume` once per piece; if any `consume` fails mid-build, the whole build rolls
back and already-consumed materials are refunded.

## The three built-in kinds

You pick one with `def.materialSource`:

```{list-table}
:header-rows: 1
:widths: 16 84

* - Kind
  - Model
* - `"raw"`
  - Consume straight from the **player's inventory**, item by item. The default, everyday choice - "you need 2 planks per wall, take them from your bag."
* - `"universal"`
  - One **container item** holds per-piece counts (a "build kit" you fill once). Good for a self-contained deployable.
* - `"bag"`
  - A **bag of variant containers** - e.g. a tent pack per color, each holding that variant's pieces. Used by MilitaryTents.
```

The framework registers these factories under those names; `MaterialSource.fromDef(...)`
resolves the right one from your def.

## Custom sources

For anything else, set `def.createMaterialSource(character, container, plan)` and return your
own object implementing the interface. It **wins over** `materialSource`. Example uses: pulling
from a base's connected stockpile, spending a currency, or a creative-mode "free" source that
always returns `true`.

## Recipes vs. requirements

A `materialRequirement` is *one* item type. When a piece costs **several different** things -
and some are tools you keep - use a `materialRecipe` and the
[`RecipeSource`](#recipesource), which validates and consumes the whole
recipe **atomically**:

```lua
materialRecipe = {
    { fullType = "Base.Plank", count = 4 },
    { fullType = "Base.Nails", count = 8 },
    { tag = "Hammer", count = 1, keep = true },   -- present but not consumed
}
```

`RecipeSource` is standalone (Tier-1 vendorable) - you can use it for any "do I have all these
ingredients?" check, framework or not.

```{seealso}
[How-to → Materials & unlocks](../how-to/materials-and-unlocks.md) for the practical recipes.
```
