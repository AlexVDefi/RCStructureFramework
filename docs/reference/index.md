# Reference

Complete, lookup-oriented documentation. If you're learning, start with
[Getting started](../getting-started.md) or the [tutorials](../tutorials/index.md);
come here when you need the exact signature, field, or shape.

```{toctree}
:maxdepth: 2

api
structure-definition
data-contracts
events
roadmap
```

## Quick map

- [**API reference**](api.md) - every public module and function, grouped by feature area, with a signature block for each.
- [**Structure definition**](structure-definition.md) - every field and callback of the table you pass to `registerStructure`.
- [**Data contracts**](data-contracts.md) - the plan, piece, and record table shapes you read and serialize.
- [**Events**](events.md) - the four `OnRCSF*` Lua events and their payloads.
- [**Roadmap**](roadmap.md) - what's delivered and what's proposed next.

```{tip}
Every public module ships full EmmyLua annotations, and the data structures are declared
as `@class` types in
[`Contracts.lua`](https://github.com/AlexVDefi/Structure-Framework/blob/main/42/media/lua/shared/RCStructureFramework/Contracts.lua).
A LuaLS-aware editor autocompletes the whole API.
```
