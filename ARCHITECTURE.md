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

## 6. What lives nowhere yet

Named so nobody invents a home for them early:

- **Sector map, nodes, stations** — v0.3. Not `sim/`, not yet.
- **Events and line pools** — v0.4, `data/events.json`, per `VOICE_AND_EVENTS.md §2`.
- **Barks and TTS** — v0.4, `data/barks.json`. Text is the source of truth and
  the game must run with zero audio files present.
- **Save/load** — explicitly out of scope in v0.2 (`§3`). Do not add a
  serialisation layer "while we are here". It will be wrong, because it will be
  written before the map exists.
