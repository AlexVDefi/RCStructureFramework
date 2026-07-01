# Authority & rooms

Two intertwined ideas underpin everything multiplayer: the framework is
**server-authoritative**, and it creates **real runtime rooms**. This page explains the model
so the [multiplayer rules](../how-to/multiplayer.md) make sense.

## The authority model

- **The server owns persistent state**: room records, planned-construction records, and light
  on/off state. It mutates ModData and broadcasts; clients hold read-only caches.
- **Clients own presentation**: the placement UI, ghost rendering, and pushing room lights
  into the local cell render list.
- **Builds and disassembly run through a server-authoritative timed action.** The action
  validates and mutates the world on the **server** - and in MP a listen host is itself a
  client driving a background server, so "the server" still means the authoritative side.

Why so strict? Project Zomboid's inventory/world sync helpers are server-only no-ops on a
client; a client that mutates locally desyncs from everyone else. So the framework funnels
every persistent mutation through a side it can trust.

### Which subsystem binds which side

Each auto-system registers vanilla events, but its **side-checks live inside the handlers** -
so it binds correctly regardless of whether it's enabled by config:

- `MaterialContainers` `OnClientCommand` handler registers **server/SP only** (client command
  handlers don't run on clients).
- Room sync (`RoomPersistence`/`System`): the client branch does `ModData.request`; the server
  branch does `restorePersistedRooms`.
- `RoomLighting`: every side registers the switch and the server owns `lightsActive`; only
  client/SP push `IsoRoomLight`s into the cell.
- `PlannedConstructions`: mutations (`register`/`cancel`/`markBuilt`) early-return on clients;
  only the server writes.

```{note}
Opting a system out via `RCSF_Config` controls **whether it loads at all** - it never changes
which side a handler binds to. See [Vendoring](../how-to/vendoring.md).
```

## Runtime rooms

Vanilla only wires `IsoRoom`s at chunk-load from the map data. A *player-built* (or
[*assigned*](../how-to/rooms.md)) structure appears at runtime, so the framework has to create
the room itself - that's `RoomPersistence`.

A framework room is a genuine `IsoRoom`/`IsoBuilding`: it drives room detection, shows on the
map, and participates in lighting. The catch is **persistence and sync**, because the engine
won't save a runtime room for you:

1. The server creates the room via the `BuildingRoomsEditor` and records it in global ModData
   (`RCStructureFrameworkRooms`).
2. `ModData.transmit` pushes the records to clients; each client recreates the same rooms
   locally from the synced records.
3. On reload, the server restores rooms from the records before the world is interacted with.

This is why a framework room survives a relog and looks identical on every client - and why
room creation is **server-authoritative** just like building.

### Grid power (lights, appliances)

A framework room is also what puts a player-built structure **on the world power grid**. The
engine only grants world-grid power to a square that is *not* in a user-defined room
(`IsoGridSquare.hasGridPower()` is `!isNoPower() && SandboxOptions.doesPowerGridExist()`, and
`isNoPower()` is true for a `userDefined` room). `RoomPersistence` clears `userDefined` on the
rooms it creates, so a framework-roomed square behaves exactly like a vanilla building square:
its lights and appliances draw world power while the grid is up, and require a generator once
the grid shuts off. Because the room is persisted and restored (above), that power **survives a
reload** - without the room, a build draws power only from the roof's transient
`roofHideBuilding`, which the engine drops on reload, so the lights go dark until a generator is
placed.

A structure becomes a room as soon as its **walls** (and any planned roofs) are built;
**floor tiles are optional**. Earlier the build-completion gate required a built floor on every
interior tile, so a house raised on bare ground never became a room and so lost grid power on
every reload. Completion now tracks the perimeter, matching what a player calls "a finished
house". A one-time load-time reconcile (`PlannedConstructions.reconcileRoomsOnLoad`) repairs
structures built before this rule changed, so existing saves recover their power without a
rebuild.

### Rooms without a build

[`RCSF.Rooms.assign`](../how-to/rooms.md) exposes exactly this machinery decoupled from the
build pipeline: it registers a lightweight synthetic def (`{ id, roomName }`), then uses the
same create-record-transmit-restore path. The record carries the id + name, so the synthetic
def is **reconstituted automatically** on a later session or on an MP client - you never
re-register it.

```{seealso}
- [How-to → Ship safely to multiplayer](../how-to/multiplayer.md) - the concrete rules.
- [How-to → Assign a room](../how-to/rooms.md) - the headless room API.
```
