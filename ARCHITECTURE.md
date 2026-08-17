# ARCHITECTURE.md

How the code divides, and why the division is worth defending.

---

## 1. The one rule

**`sim/` is a headless library. `ui/` is a viewer.**

`sim/` computes the game. It has no nodes, no scenes, no input handling, no
timers owned by the engine, and it never imports anything from `ui/`. It
advances by being handed a delta and returns what changed.

`ui/` draws what `sim/` reports and turns clicks into calls back into `sim/`.
It holds no authoritative state. If the UI is deleted, the game still runs —
you just cannot see it.

### Why this is not architecture astronautics

Three concrete things depend on it, all of them already written into the specs:

- **`GAME_SPEC v0.2 §10.9`** requires 500 headless games with a balance report.
  That is impossible in any reasonable time if the simulation needs a scene tree
  and real-time timers.
- **`GAME_SPEC v0.2 §7a`** requires structured log events. The formatter lives in
  `ui/` precisely because a second consumer arrives in v0.4.
- **`VOICE_AND_EVENTS.md §6`** is that second consumer. TOCK's bark system
  subscribes to the same event stream. If `sim/` is entangled with `ui/`, adding
  it means touching every call site.

The rule also happens to be what makes this project buildable in two autonomous
phases instead of one supervised slog. See `BUILD_PLAN.md`.

---

## 2. Layout

```
main.tscn               THE ONLY SCENE. One Control node named Main.
main.gd                 attached to it; builds every UI node in code.

sim/                    plain RefCounted classes. No Node, no Control, no
                        scene API, no imports from ui/.
  game_state.gd         run state: hull, scrap, encounter index, crew roster
  ship.gd               rooms, systems, power allocation, adjacency
  system.gd             one system: damage, power, manning, repair
  crew_member.gd        HP, state machine, per-system XP (v0.2), class lookup
  combat.gd             the tick: charge, fire, resolve
  fire.gd               ignition, damage, spread, extinguish     [v0.2]
  log_event.gd          the structured event object              [v0.2]
  log_bus.gd            append-only event stream, subscribable   [v0.2]
  rng.gd                seeded RNG — every roll goes through this
  data_loader.gd        parses data/*.json into runtime structs

ui/                     Control-building code, called from main.gd.
                        NO .tscn FILES. Ever.
  combat_screen.gd      the ship view
  corridor_map.gd       expands a room hop into a corridor walk   [slice 0]
  log_view.gd           formats LogEvents into coloured text     [v0.2]
  crew_panel.gd         portraits, HP, XP, state
  jump_screen.gd        repair / upgrade between encounters

data/                   content. no logic.
  classes.json          class definitions and bonus keys         [v0.2]
  crew.json             the starting crew                        [v0.2]
  ship_layout.json      rooms, capacities, corridors, adjacency  [slice 0]
  enemies.json          encounter templates                      [slice 3]
  weapons.json          charge time, power cost, shots, damage   [slice 0]

tests/                  optional headless specs against sim/ only
tools/
  setup_godot.sh        fetches the pinned engine
  verify.sh             the two verify commands
  validate_data.gd      data contract checks
  sim_runner.gd         headless balance harness                 [slice 4]
```

**`tools/sim_runner.gd`, not `sim/sim_runner.gd`.** The path is fixed by
`GAME_SPEC v0.1` acceptance criterion 7, which spells the invocation out:
`godot --headless --script res://tools/sim_runner.gd -- --runs 200`.

**The corridor graph lives in `data/`, and walking it lives in `ui/`.** The
plate paints corridors; `ship_layout.json` traces them as waypoints and edges;
`ui/corridor_map.gd` turns a room-to-room hop into the polyline a person would
walk. `sim/` never reads a waypoint — it asks `ShipLayout.path()` for a chain of
rooms and charges one transit per hop, exactly as before. That split is why
replacing the ship plate moved the balance report and changed no simulation
code.

`ui/` filenames are indicative and may be reshaped. `sim/` and
`tools/sim_runner.gd` are not — the harness and the verify script key off them.

### The one-scene rule

`main.tscn` is the only scene file in the project. Every Control is constructed
in GDScript at runtime. Not a prohibition on scenes — it exists because
hand-edited `.tscn` files are the thing an agent most reliably corrupts: they
are line-oriented, position-sensitive, and a bad merge produces a project that
opens to a blank screen with no error.

### Pause

The simulation owns `time_scale: float`, 0.0 or 1.0. Every tick multiplies by
it. **Never `get_tree().paused`** — that freezes UI input too, so the player
cannot give orders while paused, which is how this game is meant to be played.
`_process` keeps running; the simulation does not.

---

## 3. Determinism

**Every random decision goes through `sim/rng.gd`, seeded per run.**

No `randf()` scattered through combat code. A run seed must reproduce a run
exactly, because the 500-run harness is worthless if a failure cannot be replayed,
and because "it only happens sometimes" is otherwise unfixable.

The seed is printed in the balance report and accepted as a CLI argument.

---

## 4. The log bus

`sim/` pushes `LogEvent` objects onto an append-only stream. Consumers subscribe.

```gdscript
# sim/log_event.gd
var type: String        # "SYSTEM_DESTROYED", "CREW_DOWNED", "CLONE_RESTORED"
var severity: String    # "neutral" | "warning" | "critical"
var subjects: Array     # crew ids, system ids
var values: Dictionary  # damage amounts, timers
var t: float            # seconds since encounter start
```

Consumers, in order of arrival:

| Consumer | Version | Reads |
|----------|---------|-------|
| `ui/log_view.gd` | v0.2 | everything, formats to coloured text |
| `tools/sim_runner.gd` | v0.2 | counts deaths, clone restores, encounter index |
| bark system | v0.4 | a subset, per `VOICE_AND_EVENTS.md §4` |

**No consumer may mutate an event.** The stream is the record of what happened.

The event vocabulary is a closed set defined in `sim/log_event.gd`. Adding a
`type` is a deliberate act — the v0.4 trigger table in `VOICE_AND_EVENTS.md §4`
maps onto these names, so inventing one ad hoc creates a bark trigger that will
never fire.

---

## 5. Data contracts

`data/*.json` is content and may change without code changes. **Ids may not
change**, because save data and (from v0.4) event scripts key off them.

`sim/data_loader.gd` validates on load and fails loudly. A missing key is a
crash at startup, not a null at hour three. `tools/verify.sh static` runs this
validation as its main job.

The `bonuses` dict in `classes.json` is deliberately sparse — the format carries
far more than v0.2 populates. **Unknown bonus keys must load without error and
be ignored**, so that v0.3 keys can be authored before the code reads them.
Known-but-unimplemented is a warning; malformed is a failure.

---

## 5a. Three scenes, and which one boots

Since 2026-08-17:

| Scene | Script | What it is |
|---|---|---|
| `main.tscn` | `ui/start_menu.gd` | **The boot scene.** A development menu listing what can be launched. Not a title screen. |
| `main_combat.tscn` | `ui/combat_preview.gd` | Ship-to-ship composition and HUD test: two plates at equal scale, ours left, theirs right. **No combat rules.** |
| `rescue_scene.tscn` | `main.gd` | The playable cargo-hold mission. What `verify.sh play`, `screenshot.gd` and `walk_frames.gd` drive. |

The one-scene rule below is superseded to exactly this extent and no further:
**a menu plus one scene per launchable thing.** It is not licence for a scene
per screen.

`main.gd` is the *mission*, not the boot scene, and has been since the split.
The name is now misleading and is kept only because three tools load it by
path; rename it and them together or not at all.

**Registering a scene is one entry.** `ui/start_menu.gd`'s `ENTRIES` list is
read twice: once to build the menu, once by `tools/play.gd` to assert every
listed scene exists and loads. A scene that is offered and missing fails the
build rather than waiting to be clicked.

**This split has a sharp edge, and it drew blood immediately.** Every existing
check pointed at the mission scene, so when the combat scene stopped compiling,
all of them stayed green and the project would not open. `verify.sh static` was
the only thing that caught it, because it inspects the whole import rather than
one scene. `play.gd` now also instantiates the boot scene and checks it builds
something — see 5b for what that does and does not cover.

**The enemy ship is a picture, not a place.** `ui/enemy_preview_view.gd` draws
`enemywarship1.png` with three crew standing at hand-measured pixel positions.
There is no traced room polygon, no adjacency, no corridor graph — none of what
`data/ship_layout.json` gives the player's plate. Nothing can ask "which room is
this hostile in?", because the answer does not exist. **Tracing the enemy plate
is the prerequisite for enemy crew that do anything at all**, and it comes
before behaviour work, not after.

## 5c. Selection is view state

Who the player has selected lives on `ShipView`, not on `RescueScene`. The
simulation does not care, and the moment it does care, the rule in section 1
starts leaking: `sim/` would gain a concept that exists only because there is a
mouse.

The order path is the test of it. `ShipView` emits a set of crew ids;
`main.gd` turns that into `scene.order_move(room_id, ids)`; the simulation
receives a list of people and a destination and knows nothing about boxes,
clicks or highlighting.

**Movement is per crew member.** Until 2026-08-17 the scene held one
`task`/`task_target`/`route`, and they always meant TOCK, because for one slice
only TOCK could move. Selecting five people and ordering them somewhere is not a
bigger version of that — it is the same state owned by the right object, so it
now lives on `CrewMember`. `Task.TRANSIT` is gone; `Task` is FREEING and IDLE,
because cutting a captive loose genuinely is scene-wide: only TOCK does it, and
only one at a time.

Two things fall out of that and are worth knowing before touching it:

- **Capacity is counted on committed occupancy**, not current — everyone in the
  room plus everyone walking towards it. Without that, five crew asked one after
  another all see the same empty room and all set off for it.
- **`order_move` succeeds if anybody accepts.** Ordering six people into a room
  with space for four should move four and refuse two, not refuse all six.

## 5b. The truth layer — `tools/game_probe.gd`

**Ask the running game what is true. Do not infer it from pixels.**

`GameProbe` reads the assembled game and answers in the game's own nouns: which
crew member is where, what the sprite is actually drawn at, which clip is
playing, what the log recorded, how every Control resolved. `tools/play.gd`
plays a scripted mission against it and asserts.

This closes a specific gap. The three older checks each see part of the game:

| | sees | cannot see |
|---|---|---|
| `verify.sh static` | does it parse and import | anything about behaviour |
| `verify.sh sim` | the simulation, no UI attached | anything the UI does |
| `tools/screenshot.gd` | pixels were drawn | whether they are the right pixels |
| **`verify.sh play`** | **the assembled game, played** | how it feels |

`sim_runner.gd` survived two complete renderer rewrites without noticing, which
is the point of it and also its limit: it cannot see a crew member drawn outside
the compartment they are standing in.

**Three rules keep it honest.**

1. **The probe only reads.** A probe that can move a crew member is a second,
   undocumented way to play the game, and the two will drift.
2. **The probe reports; `play.gd` judges.** What is *measured* and what is
   *expected* have to be arguable separately.
3. **Drive through the real path.** `play.gd` presses the actual `Button` and
   emits `ShipView`'s actual `room_clicked`, rather than calling
   `scene.choose_plan()` and `scene.order_move()`. Calling into the simulation
   directly is what `sim_runner.gd` already does; doing it twice would test
   main.gd's wiring not at all.

**Determinism.** `main.gd`'s `_process` is switched off and stepped by hand at a
fixed 1/30 s, then the whole run is played twice and the traces compared. Same
seed, same steps, same answers — the same property `sim/rng.gd` gives the
simulation, extended to the UI. Wall-clock frame timing is the one source of
flake a real-time-with-pause game cannot afford in its own tests. The harness
independently reaches **40.3s**, the balance canary's number, by a completely
different route.

**A check that cannot fail is worth nothing**, so each was tried against a
deliberately broken build before being kept. Two of the first three attempts
were themselves wrong, which is the argument for doing it:

- Crew drawn at the wrong point — **caught.**
- A wrong sprite art offset — **missed at first.** The probe was comparing
  `crew_position()`, which the art offset does not touch, so it would not have
  caught the bug fixed the same day. It now reports where the *picture* lands as
  well as where the crew member stands.
- A collapsed HUD Control — **missed twice.** `BACKLOG.md` describes it as "a
  0x0 node", so the probe looked for zero sizes and found none: a *Container*
  with stale offsets does not collapse to zero, it shrinks to fit its children.
  Reproduced deliberately, the top-level margin came back 1071x609 in a 1280x720
  window. Not zero, just wrong. The check that bites compares anchors against
  resolved size — "claims to fill its parent, does not fill its parent".

**Layout assertions need a display.** Headless Godot lays the root Control out
against a 64x64 stand-in window while its children resolve against the project
viewport, so the sizes come back internally inconsistent and every layout
assertion passes on numbers that mean nothing. `play.gd` checks the root against
the *project's configured* viewport and reports those checks as **skipped**
rather than green when it cannot trust them. `verify.sh play` uses `xvfb-run`
when it is available.

## 6. What lives nowhere yet

Named so nobody invents a home for them early:

- **Sector map, nodes, stations** — v0.3. Not `sim/`, not yet.
- **Events and line pools** — v0.4, `data/events.json`, per `VOICE_AND_EVENTS.md §2`.
- **Barks and TTS** — v0.4, `data/barks.json`. Text is the source of truth and
  the game must run with zero audio files present.
- **Save/load** — explicitly out of scope in v0.2 (`§3`). Do not add a
  serialisation layer "while we are here". It will be wrong, because it will be
  written before the map exists.
