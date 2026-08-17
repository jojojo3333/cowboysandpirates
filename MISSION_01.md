# MISSION_01.md — the boarding, and what building it requires

**What this file is.** The shape of mission 1 and a complete list of what it
needs, so the size of the job is visible before any of it is started.

**What this file is not.** It is not a queue. `BACKLOG.md` is the only file that
holds one, and it decides what happens next and in what order. This file
answers "what does mission 1 consist of", not "what do we do today".

Written 2026-08-17 from the owner's description. The story beats are theirs; the
breakdown underneath each one is the engineering cost of that beat.

---

## The mission, in beats

### Act 1 — the boarding *(the demo target)*

1. **Cold open, over the comms.** The captain — the player — is asleep. TOCK
   wakes them.

   > **TOCK:** Captain, we are being boarded.
   > **CAPTAIN:** What the hell, I was just sleeping…
   > **TOCK:** My monitor tells me that half of the crew is already subdued, and it looks like you are next.
   > **CAPTAIN:** Damn…

   TOCK is voiced. The captain is text. *(Owner is writing the final lines; the
   above is placeholder phrasing from the description.)*

2. **Cutscene, in-engine.** Pirates beating crew members and dragging them to
   the cargo bay. No new renderer — the game's own ship view, its own sprites.

3. **Cut to now.** Human crew tied in the cargo bay. TOCK in his charging pod.
   This is exactly where the playable mission starts today.

4. **TOCK asks permission.** Voiced: should he hack the boarders' suits?

5. **The player chooses.** The existing two-plan choice.

6. **The hack.** Four boarders aboard, in two pairs — two in the cockpit, two in
   the mess hall / crew quarters / weapons room. TOCK hacks for **three seconds**
   and then **all four drop at once**, not one at a time.

7. **Banter.** Each crew member says something as they are freed or after.
   This is where the crew are introduced as people. It is the beat that decides
   whether a stranger cares about any of them.

8. **End of act 1.**

### Act 2 — the fight *(recorded, not being built yet)*

The pirate ship opens fire. Ship-to-ship combat, both ships visible. The player
may assign crew to stations for bonuses — the spec already defines these as
per-system manning bonuses, so this is implementing an existing design rather
than inventing one. Assigning crew is **optional**: the player can simply shoot.

See "Act 2 — what it would take" near the bottom. Nothing in it is scheduled.

---

## What already exists, and must not be rebuilt

Roughly half of act 1 is standing. Anything below that gets rewritten is time
spent going backwards.

| Already working | Where |
|---|---|
| The ship, traced: rooms, doors, corridors, capacities | `data/ship_layout.json` |
| Crew who walk the corridors, with distance-based travel | `sim/rescue.gd`, `ui/corridor_map.gd` |
| Box selection and multi-crew move orders | `ui/ship_view.gd`, `main.gd` |
| Crew sprites — walk, idle, die — at 8 facings | `assets/crew/`, `tools/render_soldier.gd` |
| Captives, cutting them loose, the whole rescue | `sim/rescue.gd` |
| The two-plan choice and the log | `main.gd`, `sim/log_bus.gd` |
| TOCK's voice lines as *text*, keyed to events | `VOICE_AND_EVENTS.md §6`, `_say()` in `sim/rescue.gd` |
| The event stream that a cutscene and a bark system both subscribe to | `sim/log_bus.gd` |
| Boarders as a *number* that the hack counts down | `boarder_count` in `data/scene_rescue.json` |

**The last row is the trap.** Boarders currently exist only as an integer.
Nothing stands anywhere, nothing is drawn, nothing can be hacked individually.

---

## Act 1 — the deliverables

Split by who can do them. Nothing here is scheduled; see `BACKLOG.md`.

### A. The owner's, and nobody else can do them

| # | Deliverable | Notes |
|---|---|---|
| A1 | **The script.** Final wording for the cold open, TOCK's hack question, and one banter line per crew member. | TOCK never uses contractions and never says anything the log has not already said in plain form — `VOICE_AND_EVENTS.md §3`. |
| A2 | **Voice audio.** One file per line, TOCK only for now. | ElevenLabs. Any of `.ogg`, `.wav`, `.mp3`; **`.ogg` preferred** — Godot's web export handles it best and the file sizes are smallest. |
| A3 | **A filename per line**, matching the line ids in the script. | e.g. `tock_boarded_01.ogg`. Whatever scheme you like; it just has to be stable. |
| A4 | **The crew's characters** — enough of who they are that the banter lines sound like six different people. | `world/crew/` is the place. Currently empty. |

**Audio must never be load-bearing.** If a file is missing the line still plays
as text and the mission continues. A demo that dies because one `.ogg` did not
import is a demo that does not happen.

### B. Systems that do not exist yet

Ordered by how much else depends on them.

| # | System | What it is | Size |
|---|---|---|---|
| B1 | **Dialogue sequences** | A scripted list of lines: who speaks, what they say, which audio file, how long to hold, whether the sim is paused meanwhile. Advances on time or on click. **Skippable.** | Medium — the backbone of act 1 |
| B2 | **Boarders as actors** | Hostiles that exist in the simulation: an id, a room, a state, drawn on the plate in a hostile tint. Four of them, two pairs, placed by data. | Medium — touches `sim/` |
| B3 | **A cutscene runner** | A timeline that moves actors between rooms and plays clips at set times, with the simulation held still. Not AI; a script that says "at 2.0 s, this pirate walks to the hold". | Medium-large — the riskiest item |
| B4 | **The captain as a speaker** | The player has no representation at all today. Needs a name and somewhere for their lines to appear. No sprite required. | Small |
| B5 | **Simultaneous hack** | Three seconds, then all four boarders drop together. Today it is 18 seconds staggered 4 apart, one at a time. | Small — but see the warning below |
| B6 | **A prone/collapsed hold** | A dropped boarder must *stay* dropped, holding the last frame of `die` rather than looping. | Small |
| B7 | **Banter triggers** | Fire a dialogue sequence when a specific crew member is freed. The event stream already carries `CREW_FREED`. | Small |

**B5 will move the balance canary, and that is correct.** The number has read
40.3s through two renderer rewrites, a ship replacement and the movement
refactor. Changing the hack from 18 seconds to 3 changes how long the mission
takes *by design*. When it moves, it gets reported and stated — never tuned back.

### C. Art and animation

| # | Deliverable | Honest assessment |
|---|---|---|
| C1 | **Boarder look** | Cheapest good answer: the same rendered figure in a hostile tint, as the enemy ship's crew already use. A separate model is a want, not a need. |
| C2 | **A "beaten" beat** | We have `die` — an authored forward collapse. For a pirate striking someone, that plus a small lunge on the attacker reads well enough at this size. |
| C3 | **A "dragged" pose** | The genuinely new one. Cheapest version that reads: the victim holds a prone pose and moves with the pirate, drawn slightly behind and below. It will look clunky. That is the agreed price of act 1 existing at all. |
| C4 | **Camera focus** *(optional)* | The view currently always shows the whole ship. A cutscene reads far better if it can push in on a compartment. Genuinely optional — cut it first if time runs out. |

All three new poses are authored on the Silver Soldier's own rig, the same way
the walk was — `tools/render_soldier.gd`, `--mode preview` to judge, `--mode
bake` to ship. That path is proven and the constants are already tuned for the
80° camera.

### D. Data and content plumbing

| # | Deliverable |
|---|---|
| D1 | `data/mission_01.json` — the beats, the dialogue lines, the boarder placements, the cutscene timeline. Balance numbers live in data, per `CLAUDE.md`. |
| D2 | Boarder entries in `data/scene_rescue.json`: four of them, with rooms. |
| D3 | An audio manifest: line id → file path, with a graceful miss. |
| D4 | `assets/audio/voice/` plus rows in `ASSETS.md`. **The provenance check will fail the build until they are recorded** — that is working as intended. |

### E. Checks — what "done" means

Not optional, and cheap now that the harness exists.

| # | Check |
|---|---|
| E1 | `verify.sh play` runs act 1 start to finish with audio disabled, deterministically. |
| E2 | Every dialogue line in `data/mission_01.json` either has an audio file or is explicitly marked text-only — no silent misses. |
| E3 | Four boarders exist, in the rooms the data names, and all four go down within one tick of each other after the hack. |
| E4 | The cutscene ends with the crew in the cargo bay and TOCK in his pod — i.e. it hands over to the playable state cleanly. |
| E5 | The whole act is skippable, and skipping lands in the same state as watching. |
| E6 | Every new pose is checked the way the walk was: rendered at the game's camera, not judged side-on. |

---

## Two spec markers this crosses, deliberately

`GAME_SPEC v0.1 §2` calls itself "scope markers, not bans — if something here
turns out to be the right next thing, move it and say so." So, saying so:

- **"No boarding, no enemy crew."** Mission 1 is a boarding, with enemy crew
  standing in our compartments. This marker is superseded by the mission itself.
- **"No story"** (marked v0.3+). A voiced cold open and an in-engine cutscene
  are story. This is a deliberate move, made because a stranger seeing the game
  for the first time needs to care about the people in it, and no amount of
  mechanics does that job.

Neither is being smuggled in. Both are recorded here so the specs can be updated
rather than quietly contradicted.

**What is *not* being moved:** the Soldier stays the weakest class and the Medic
stays near-useless alongside a Clone Bay. `GAME_SPEC v0.2 §3` is explicit that
both are correct, and no compensating mechanic gets invented while building this.

---

## Act 2 — what it would take

**Recorded, not scheduled.** Captured now so the shape is known.

The pirate ship opens fire. Both ships on screen — the composition already
exists in `main_combat.tscn`. The player may put crew on stations for bonuses,
or may simply shoot.

| Piece | Notes |
|---|---|
| **Ship-to-ship combat loop** | Weapon charge, fire, resolve. `GAME_SPEC v0.1 §4` already specifies hull, reactor, shields, engines, weapons, medbay and the power-per-system table. This is implementing a written design. |
| **Power allocation** | Reactor bars assigned across systems; a damaged system loses effective power. Specified. |
| **Weapon fire, seen** | The owner's point, and it is the right one: *"you got hit for 2 damage"* with nothing on screen is not a fight. Needs a shot travelling between the two hulls and an impact on the struck compartment. |
| **Damage to compartments** | A hit room goes dark, which the lighting already supports — an unpowered compartment can simply stop being lit. |
| **Manning stations for bonuses** | Already designed: per-system XP, +20% at level 1, +35% at level 2, `GAME_SPEC v0.2`. **Optional for the player** — that is a deliberate design choice and should stay one. |
| **Enemy ship needs tracing first** | It is a picture, not a place: no rooms, no corridors, no doors. Enemy crew cannot stand anywhere meaningful, let alone move, until it is traced. Already recorded in `BACKLOG.md`. |
| **Enemy behaviour** | Making the hostile ship look busy. Blocked on the tracing above. |

---

## If time runs short, cut in this order

The demo's job is that one person feels what this becomes. Judged only against
that:

1. **Camera focus (C4).** Nice, not necessary.
2. **The dragging cutscene (B3, C3).** Expensive, and the cold open plus the cut
   to tied-up crew already tells the story. A line of TOCK's voice over a black
   screen does most of this beat's work.
3. **Per-crew banter (B7)** down to one or two lines rather than six.

**Do not cut:** the cold open (A1, A2, B1) or the simultaneous hack (B5). The
voice is the single cheapest thing that makes this feel like a game with people
in it, and the hack is the moment the player's decision visibly does something.
