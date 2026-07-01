# Assign a room (without building)

`RCSF.Rooms` claims an arbitrary area as a real, persisted `IsoRoom` - **decoupled from the
build pipeline**. Use it for quest areas, safe zones, prefab interiors, or any time you want
the engine to treat a region as a room without placing a single wall.

A framework room is a first-class `IsoRoom`: it shows on the map, drives room detection,
participates in [room lighting](#roomlighting),
persists across relogs, and syncs to MP clients.

```{important}
`RCSF.Rooms.assign` / `unassign` are **server-authoritative** - they run on the MP server
and in singleplayer; on an MP client they're a no-op. Call them from server-side quest /
prefab logic. The resulting room reaches clients through the framework's normal room-record
sync. See [Concepts → Authority & rooms](../concepts/authority-and-rooms.md).
```

## Assign a single rectangle

```lua
local assignment = RCSF.Rooms.assign(
    { x = 10600, y = 9420, z = 0, w = 6, h = 5 },   -- the area
    "QuestVaultRoom"                                 -- the IsoRoom name
)
-- assignment = { id = "RCSFRoom_QuestVaultRoom", name = "QuestVaultRoom", rects = { … } }
```

`assign` returns a descriptor (or `nil` on bad input / MP client). Hold onto it - you can pass
it straight back to `unassign`.

## Assign multiple rectangles

Pass a list of rects (or `{ rects = {…} }`). Connected rects become one building with one
`IsoRoom` per rect (suffixed `Name_1`, `Name_2`, …); disjoint groups become separate
buildings.

```lua
RCSF.Rooms.assign({
    { x = 10600, y = 9420, z = 0, w = 6, h = 5 },
    { x = 10606, y = 9420, z = 0, w = 4, h = 5 },   -- edge-adjacent → same building
}, "QuestVaultRoom", { id = "quest_vault" })
```

### `opts`

```{list-table}
:header-rows: 1
:widths: 20 80

* - Option
  - Effect
* - `id`
  - Explicit structure id backing the assignment (default: a namespaced derivation of `name`). Reuse the same `id` + `name` to grow/replace an assignment.
* - `stairs`
  - Stair list `{ {x,y,z,north}, … }` for cross-storey connectivity (joins rects across Z into one building).
```

## Unassign

Tear down the building(s) and forget the persisted record. Pass the descriptor `assign`
returned, or the same rects plus the `id`/`name` you used:

```lua
RCSF.Rooms.unassign(assignment)                       -- easiest: the descriptor
-- or:
RCSF.Rooms.unassign({ x = 10600, y = 9420, z = 0, w = 6, h = 5 }, { name = "QuestVaultRoom" })
```

```{tip}
The single-vs-multi rect shape must match the original `assign` call. If you assigned a list,
unassign with the same list (the descriptor carries it for you).
```

## React to assignment

`assign` fires `OnRCSFRoomAssigned`, `unassign` fires `OnRCSFRoomUnassigned`, both with
`{ id, name, rects }`:

```lua
Events.OnRCSFRoomAssigned.Add(function(info)
    print("claimed " .. info.name .. " (" .. #info.rects .. " rect(s))")
end)
```

See [React to framework events](events.md).

## How it persists (so you don't have to)

Under the hood `assign` registers a lightweight synthetic structure def (`{ id, roomName }`)
and uses the same `RoomPersistence` machinery as a built structure. The room record stores
the id + name, so on a later session - or on an MP client receiving the sync - the framework
reconstitutes that def automatically before recreating the room. **You don't re-register
anything**; the assignment just survives.

```{seealso}
[Tutorial → Claim a quest room](../tutorials/claim-a-room.md) for an end-to-end example with
a trigger and cleanup.
```
