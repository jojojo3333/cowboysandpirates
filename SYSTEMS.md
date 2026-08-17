# SYSTEMS.md — what this game can do, and what it cannot yet

**What a system is.** A general capability, not one use of it. "A thing that can
play a scripted sequence" is a system; "the boarding" is a script written
against it. The distinction is the whole reason this file is worth keeping:
building one boarding is a day's work you throw away, and building a cutscene
system means every future cutscene is a data file.

**What this file is not.** Not a queue — `BACKLOG.md` is the only one of those,
and it decides order. Not a design document — `GAME_SPEC.md` covers rules and is
being remade. This is an inventory: what exists, what half exists, what is known
to be missing, and space for what nobody has thought of yet.

**Keep it honest.** A system listed as built should be one somebody could use
tomorrow without discovering it only works for the one case it was written for.
If that turns out to be false, move it down rather than quietly fixing the list.

---

## 1. Built, working, and checked

Each of these has assertions behind it in `tools/verify.sh`. That is what
separates this section from the next one.

### Foundation

| System | What it does | Where |
|---|---|---|
| **Seeded determinism** | Every random decision goes through one seeded RNG. Same seed, same run, every time and on every machine. Without it no failure is reproducible and no balance figure means anything. | `sim/rng.gd` |
| **Data contracts** | `data/*.json` is parsed and validated on load; a missing key is a loud failure at startup, not a null three hours in. | `sim/data_loader.gd`, `tools/validate_data.gd` |
| **The event log** | An append-only stream of structured events — type, severity, subjects, values, timestamp. Multiple consumers subscribe. This is the game's spine: if something matters, it writes a line, and both the visible log and TOCK's voice read the same stream. | `sim/log_bus.gd`, `sim/log_event.gd` |
| **Pause that does not freeze the UI** | The simulation owns a time scale; the interface keeps running. That is what makes real-time-with-pause playable rather than a slideshow. | `time_scale` in `sim/rescue.gd` |

### The ship

| System | What it does | Where |
|---|---|---|
| **Ship layout** | Rooms as traced polygons, capacities, door adjacency, a corridor waypoint graph, and precomputed walk distances. The art is the source; the data describes the art. | `data/ship_layout.json`, `sim/ship_layout.gd` |
| **Pathfinding** | Room to room across the whole ship, not just to neighbours. | `ShipLayout.path()` |
| **Corridor walking** | Expands a room-to-room hop into the polyline a person actually walks, through the doorways. Nobody crosses a bulkhead. | `ui/corridor_map.gd` |
| **Ship rendering** | A painted plate with a derived normal map, one light per compartment, additive over a darkened hull — so an unpowered room can simply go dark. Code draws only what changes. | `ui/ship_view.gd`, `ui/ship_overlay.gd` |

### People

| System | What it does | Where |
|---|---|---|
| **Crew** | Id, name, class, room, health, state. Classes carry colour and bonuses from data. | `sim/crew_member.gd`, `data/crew.json` |
| **Movement** | Per person, not per scene. Several people walk at once, each with their own route and progress. Re-routable mid-walk. Travel costs distance divided by speed, so where someone is standing matters. | `sim/rescue.gd`, `sim/crew_member.gd` |
| **Squad orders** | Order many at once. Capacity is counted against everyone *committed* to a room, not just those standing in it, and departures stagger so a group walks in single file instead of merging into one figure. | `RescueScene.order_move()` |
| **Selection** | Drag a box or click a person. View state, never simulation state — the simulation receives a list of ids and knows nothing about boxes. | `ui/ship_view.gd` |
| **Hostiles** | Boarders are the same class of object as the crew — same movement, same corridors, same sprite — separated by colour and by who may command them. | `is_hostile`, `data/classes.json` |
| **Crew rendering** | Eight facings, three clips, class tint applied at runtime over a near-neutral render. | `ui/ship_view.gd` |

### Content pipeline

| System | What it does | Where |
|---|---|---|
| **Sprite baking** | Poses authored on a 3D rig and baked to 8-facing sheets. Camera pitch, framing and the sprite offset are all measured and printed rather than guessed. | `tools/render_soldier.gd` |
| **Cutscenes — movement** | A timeline of beats against the simulation: who moves where, when, and "wait until everyone has arrived". Headless, so a whole cutscene can be run and asserted with no window open. **Proved 2026-08-17: four pirates board through the airlock and cross the ship to the crew quarters with nobody touching the mouse.** | `sim/cutscene.gd`, `data/mission_01.json` |
| **Scene registry** | One list decides what the boot menu offers *and* what the checks verify exists. Registering a scene is one entry. | `ui/start_menu.gd` |

### Knowing whether it works

This is a system too, and arguably the one that made the rest possible.

| System | What it does | Where |
|---|---|---|
| **The truth layer** | Ask the running game what is true, in its own nouns — who is selected, where someone is drawn, which clip is playing, what the log said. Not inferred from pixels. | `tools/game_probe.gd` |
| **Scripted playthrough** | Presses the real buttons, drives real mouse events, steps the clock by hand at a fixed rate, plays a mission to the end and asserts. Runs twice and compares, so non-determinism is caught rather than suffered. | `tools/play.gd` |
| **House rules as checks** | The written rules of the project, executable. A rule in a document is something a reader might remember; a rule in a check is something that stops them. | `tools/check_rules.py` |
| **Balance harness** | The mission played many times headlessly, reporting how long it takes. A canary: it exists to move when nothing should have moved it. | `tools/sim_runner.gd` |

---

## 2. Half built

Listed separately because calling these done would be a lie that costs somebody
a day.

| System | What works | What does not |
|---|---|---|
| **Cutscenes — actions** | Moving actors, staging them, waiting for arrival. | Cannot trigger a clip, cannot make one actor do something *to* another, cannot change anyone's state. Every beat is a move order. |
| **The hack** | Boarders go down on a timer and the log says so. | The four boarders that now exist as actors are not connected to it — the countdown still works off a number. They do not fall over. |
| **TOCK's voice** | Lines fire on events and appear as text. | No audio, no timing control, no sequencing, no way to write a conversation. |

---

## 3. Known to be needed

Nothing here is scheduled. `BACKLOG.md` decides that.

### For mission 1

| System | Why |
|---|---|
| **Dialogue sequences** | A conversation is a list of lines with a speaker, timing, and the ability to skip. Act 1 opens with one. See `MISSION_01.md` B1. |
| **Audio playback** | Voice files, with a manifest and a graceful miss — a missing file must degrade to text, never break the build. |
| **Clip triggering in cutscenes** | So a beat can say "play this pose" and not only "walk there". |
| **Actor state changes in cutscenes** | So a beat can restrain someone, or knock them down, and the mission afterwards inherits that state instead of setting it up separately. |

### For the fight

| System | Why |
|---|---|
| **Ship systems and power** | Hull, reactor, shields, engines, weapons, medbay; power assigned across them; damage reducing effective power. |
| **Weapons and the combat loop** | Charge, fire, resolve. |
| **Weapon fire, seen** | A shot crossing between the hulls and landing. *"You took 2 damage"* with nothing on screen is not a fight. |
| **Compartment damage** | A hit room goes dark. The lighting already supports this; nothing drives it. |
| **Crew stations** | Standing at a system does something. Optional for the player by design. |
| **The enemy ship as a place** | It is currently a picture: no rooms, no corridors, no doors. Nothing can stand anywhere meaningful, let alone move. Everything about enemy crew is blocked on this. |
| **Enemy behaviour** | Making a hostile ship look busy rather than like scenery. |

### For a game rather than a mission

| System | Why |
|---|---|
| **Run structure** | More than one encounter, and something connecting them. |
| **Save and load** | Currently nothing persists. Cheap to add early, expensive to retrofit once there is a lot of state. |
| **Crew consequence** | Injury, death, and whatever replaces someone. The stated design goal is that losing a crew member costs something; no system currently makes that true. |
| **Settings** | Volume above all, once there is audio. A demo with no volume control is a demo you cannot show in a quiet room. |
| **Text as data** | Every player-facing string currently lives where it is used. Pulling them into one place is dull and easy now, and miserable later — and it is the difference between the game being translatable and not. Worth deciding early rather than discovering. |

---

## 4. Known fixable

Things that work but look or feel wrong. **Named as a category on purpose**, so
they stop being a nagging worry and become a decision: we know what it is, we
know it is repairable, and we have chosen not to repair it yet.

The test for this list is narrow. An entry belongs here only if **the mechanism
underneath is sound and the fix is understood**. Anything where the fix is
unknown is not "known fixable", it is a risk, and it belongs somewhere honest.

| What | Why it is safe to leave | What fixing it involves |
|---|---|---|
| **The walk looks weird.** Crew and pirates both — they are the same sprite sheets, so it is one problem, not two. | It reads as a person moving from A to B, which is all the mission needs today. | Re-authoring the pose constants at the top of `tools/render_soldier.gd` and re-baking. The pipeline is proven; nothing structural is in the way. Judge it with `--mode preview`, which now shoots at the game's own camera. |
| **The camera pitch is unconfirmed.** 80° is a pick, not a measured answer. | Legibility was tested at every angle from 62 to 90 and the figure survives all of them, so this is taste rather than function. | One constant, then `--mode bake`, then paste the `CREW_ART_OFFSET` it prints. |
| **Crew ordered separately can still overlap.** The squad stagger only spaces people ordered *together*. | Two people standing in the same pixel is untidy, not wrong, and the common case — a squad order — is handled. | Real avoidance means crew occupying space along a corridor rather than a point on it. That is a genuine system, not a tweak, and is not on this list because of it. |
| **Our ship's engines are cropped in the combat view.** | Deliberate: the zoom exists so crew stay large enough to see, which matters more than showing the whole hull. | Either a camera that can frame each ship independently, or plates with less empty margin. Both are real work; neither is urgent. |
| **The boarders are not connected to the hack.** They stand there and do not fall over. | They are visibly aboard, which is the thing that was missing. | Wiring the countdown to the actors and dropping them together. Deliberately held back so the balance canary moves once, for one stated reason. |

**When something leaves this list, say which.** The value is in the list being
short and true; a "known fixable" that nobody ever fixes is just a fault with a
comforting label on it.

## 5. The ones nobody has thought of yet

There will be many, and that is normal. Two things make them cheaper.

**Notice when you are building the second one of something.** The first
cutscene was a script. Writing a second one by hand would have been the mistake;
turning the first into a system was not obvious until there was a reason to
believe a second would follow. The signal is usually "I am about to copy this
and change three lines".

**Add it here when it appears**, in whichever section is true, and say plainly
what it cannot do. A system described more generously than it deserves is worse
than an absent one, because somebody plans around it.

---

## 6. How it got here

*Folded in from `SLICE.md`, 2026-08-17, when that file was retired.* Kept
because each entry is evidence for a decision that still holds.

**Where the ship art comes from — settled.** Void War is two people plus a
contract artist; FTL ships are a hand-drawn hull plus one authored image per
room, positioned by a layout file; Cosmoteer assembles ships from hand-drawn
modules. In all three, **the art comes first and the data describes the art**,
which is why this project traces rooms out of a painted plate rather than
drawing a hull from polygons. Drawing from primitives has a ceiling that more
polygons do not raise: a painted hull carries thousands of individually decided
pixels, while rules produce regularity, and the eye reads regularity as
machine-made.

**A render pass may never change a simulation number.** If the balance report
moves during presentation work, something has leaked from `ui/` into `sim/`.
The report read 39.4s before and after all of the first three passes. Replacing
the *ship* is not a render pass — a new plate changes distances, and distance is
a simulation number.

| Pass | What changed | Why it is worth remembering |
|---|---|---|
| **1** — "it looked like a text adventure" | Six flat grey rectangles became a drawn hull with chamfers, nacelles and lit interiors. | All of it was deleted in pass 2. It is the evidence that drawing a hull from code has a ceiling. |
| **2** — the plate is the ship | A painted plate replaced every drawn primitive; rooms became traced polygons; grid coordinates were deleted because adjacency is what the art shows. | The simulation only ever read `adjacent`, so this cost `sim/` nothing — the first proof that the `sim`/`ui` split was worth its cost. |
| **3** — crew are people | Rendered figures on 8-facing sheets replaced two ellipses and a highlight. | Three rounds of tuning the ellipses could not have got there. Some problems are the wrong approach, not the wrong parameters. |
| **4** — seen from above | The render camera went from 62° to 80°, and the walk was rebuilt rather than rescaled. | The ship was drawn from above and the crew from the side. Also where "render the comparison before believing the reasoning" was learned. |

**Corridors, 2026-08-16.** Crew used to walk room centre → door → room centre in
straight lines, cutting through bulkheads. The fix was data, not code: a plate
with a painted corridor stripe, traced into waypoints. All 78 room-to-room
routes were checked against the bulkheads in the art; none crosses one.

**Travel costs distance, 2026-08-16.** Not a flat fee per room. Crossing the
whole ship has to cost more than stepping across a corridor, or the layout means
nothing and it does not matter where anyone stands. This is what moved the
canary to 40.3s, deliberately.

**The old slice plan is gone with it.** `SLICE.md` carried slices 1–5 written in
the first hour — four rooms per ship as labelled `ColorRect`s, programmer art,
no plate. Every one of them was overtaken by what actually got built. Keeping a
plan that describes a different game is worse than having none.

## 7. What is deliberately not a system

Kept short, and here so the list above does not swallow everything.

- **One mission's content.** `data/scene_rescue.json`, `data/mission_01.json`
  and the crew roster are scripts written against systems, not systems.
- **Art.** The ship plates and crew sheets are assets. The *pipeline* that bakes
  them is a system and is listed above; the images are not.
- **The look of a screen.** A HUD layout is a design; the things it reads from
  are systems.
