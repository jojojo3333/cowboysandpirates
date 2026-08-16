# BACKLOG.md — what is next, and what can be handed to someone else

**This is the one file to open when you want to know what happens next.**
It is the single ordered list of everything known to be missing, wanted or
broken, and it doubles as the brief pack for work done outside this repo.

## Where things live, so this file does not duplicate them

| Question | File |
|---|---|
| **What is next?** | **this file** |
| What is the immediate next session doing? | `NEXT_SESSION.md` |
| What is the build order, and what is done? | `SLICE.md` |
| What are the rules of the game? | `GAME_SPEC.md` |
| How do `sim/` and `ui/` divide? | `ARCHITECTURE.md` |
| Where did an asset come from, and what does a new one need? | `ASSETS.md` |
| What is the world, who is in it? | `SETTING.md`, `world/` |
| How is it written? | `VOICE_AND_EVENTS.md` |

`SLICE.md` is the roadmap and stays authoritative for build order. This file is
the working queue: it holds the things that do not belong to a numbered slice,
plus the state of each slice that does.

---

## Status, 2026-08-16

Slice 0 (the cargo hold rescue) plays start to finish. Three render passes done,
the ship replaced, corridors traced, travel costing distance. Both verify
commands green, balance report **40.3s** for both plans.

**Current slice: 1** — the boarders' ship attacks. Not started.

---

## The queue

Ordered. Anything marked **[OUTSOURCEABLE]** has a brief further down.

### 1. Crew selection and multi-crew movement — *blocking, small, not started*

**Only TOCK can move.** `main.gd:_on_room_clicked` calls `order_move()`, which
is hardcoded to `scene.tock`; `_on_crew_clicked` calls `order_free()`, which only
unties. There is no "selected crew member" anywhere in the project. A crew member
you cut loose in the hold turns ACTIVE and then stands there for the rest of the
game.

This was fine when the only actor was TOCK. It blocks nearly everything below —
Slice 3 assigns crew to rooms, the boarders need someone to fight, and a tutorial
that cannot ask the player to move a person is not a tutorial.

Wants: a selection concept in `ui/`, `order_move` taking a crew member instead of
assuming TOCK, and the existing room-capacity rule applying to whoever walks.
Roughly: click a crew member to select, click a room to send them, click empty
space to deselect. Shift-click or drag-select for several is a later question.

### 2. Slice 1 — the boarders' ship attacks

Defined in `SLICE.md`. The first real combat. Do not start it before crew
movement exists.

### 3. The six visible boarders — *unblocked by room capacity, needs #1*

Three in the cockpit, three in crew quarters. Cockpit holds 4, crew quarters
holds 6, so both fit with room to send people in after them. Needs enemy crew as
a concept in `sim/`, which does not exist yet.

### 4. Crew art replacement — **[OUTSOURCEABLE]**

The Kenney crew read as too cartoonish. Two candidate packs assessed and both
fall short — `ASSETS.md` has the measurements. See **Brief A**.

### 5. UI chrome — **[OUTSOURCEABLE]**

Still the largest visual gap. Kenney's *Fantasy UI Borders* 9-slices are already
in `assets/ui/` and still unwired. Wants a design pass against the owner's
mock-up before any code. See **Brief C**.

### 6. Mission and event content — **[OUTSOURCEABLE]**

`world/` has five empty folders — `crew`, `gameworld`, `missions`, `storyboard`,
`voice`. `VOICE_AND_EVENTS.md` is the spec and only §6 is built. This is the
largest body of work that needs no code at all. See **Brief B**.

### 7. Weapon mount overlays

Small transparent PNGs at traced hull coordinates, the way FTL draws upgrades.
The plate has six turret barbettes, three top and three bottom, which are the
obvious mount points. No art exists.

### 8. Enemy ship plates — **[OUTSOURCEABLE]**

Slice 1 needs a second ship. The player plate took two attempts and a full
retrace; the spec for getting one right is in `ASSETS.md` under "Ship plate
spec". See **Brief D**.

### Known smaller gaps

- **The magazine is a thirteenth room.** The brief asked for twelve. It is a real
  walled compartment beside turret control, so it was traced in as `magazine`,
  capacity 2. Fold it into `weapons` if that is wrong.
- **The plate is 1797 px on the long axis** where `ASSETS.md` asks for 2048+.
  Nothing breaks; a bigger window reaches the limit sooner than intended.
- **`tests/` is empty.** `tools/sim_runner.gd` is the only harness. `SLICE.md`
  Slice 5 wants random legal play and a win rate once combat exists.
- **Corridors that dead-end against the hull carry no waypoints.** Cosmetic and
  intentional, noted so nobody "fixes" it.

---

## Outsourcing

### What actually separates cleanly

The `sim/` and `ui/` split is the thing that makes handing work out possible.
`sim/` is a headless library with no Node, no scene API and no imports from
`ui/`, driven by `tools/sim_runner.gd`. So there are three tracks, and someone
working in one does not need to understand the other two.

| Track | Needs | Does **not** need |
|---|---|---|
| **A — art and assets** | the asset contract below | any Godot or GDScript knowledge |
| **B — simulation** | GDScript, `tools/verify.sh` | any art, any rendering knowledge |
| **C — viewer** | GDScript, Godot 2D and lighting | any balance or rules knowledge |

Track A is the best value to send out, because it needs no code at all and it is
where the project's remaining quality gap is.

### The rules any outside work must hold to

Non-negotiable, and all of them are in `CLAUDE.md` — they are repeated here
because an outside contributor will not read it:

1. **`tools/verify.sh` must be green.** Both commands. A change is not done
   until it is.
2. **Never weaken a test to make it pass.** If a test is wrong, say why.
3. **Report balance numbers, never tune them.** If the win rate is 4%, that is
   the deliverable.
4. **`sim/` holds no Node or scene API.** Plain `RefCounted` over data.
5. **Static typing everywhere.** Godot 4.7 treats several inference warnings as
   errors.
6. **Tabs, not spaces.**
7. **Every slice ends with a running, clickable game.**
8. **Balance numbers live in `data/*.json`,** never hardcoded.
9. **Record every asset in `ASSETS.md`** with its licence and origin, before it
   is used.

---

## Brief A — crew models

**Deliverable:** one `.glb` per character.

This is the highest-value brief and the one with the sharpest contract, because
the pipeline already exists. `tools/render_crew.gd` takes a rigged model, spins
it to eight compass facings, plays its clips and bakes sprite sheets. Nobody
outside needs to touch that. They deliver a GLB that satisfies the contract.

**Acceptance criteria — all checkable in one command:**

```
xvfb-run -a godot --script res://tools/preview_models.gd -- --out /tmp/cast
```

| | Required |
|---|---|
| Format | `.glb`, single self-contained file, textures **embedded** |
| Texture size | 1024 px. We draw crew at ~66 px; 2k is downsampled into nothing |
| Rig | humanoid skeleton, skinned |
| Clips | named **exactly** `walk`, `idle`, `die`. Others are ignored, not an error |
| Walk clip | a real cycle that loops seamlessly, 8 frames sampled |
| Rest pose | **not a T-pose.** From 62° above a T-pose is a starfish, not a person |
| Height | figure roughly 1.0–2.0 units, standing on the origin, facing −Z |
| Licence | CC0 preferred. CC-BY accepted **with the credit line supplied** |

**The design test, which matters more than any of the above.** At 66 px seen
from 62° overhead, realistic proportions read *worse* than exaggerated ones —
thin, pale, hard to pick out. This was measured, not guessed; the comparison is
in `ASSETS.md`. A replacement must earn its bulk through **armour, a pack, a
helmet** — a silhouette that is wide because the character is wearing something.
"Anatomically correct" is not the goal; "recognisable as a person at 66 px" is.

**In hand and ready to go:** *Silver Soldier (Animated)*, Sketchfab, CC-BY. Take
the **GLB at 1k**. Before building on it, confirm it has a genuine **walk cycle**
— "Animated" on Sketchfab can mean a single turntable loop. The preview command
above prints the clip list.

**Also in the repo, blocked:** `assets/crew_src_modular/{male,female}.fbx`,
CC-BY 4.0. Rigged on a Mixamo-named skeleton but with **no animation clips and
no body texture**. Because the bone names are Mixamo's, Mixamo animations
retarget onto them with no bone mapping. That is the cheapest way to unblock
them, and it needs a browser upload, so it cannot be done from inside this repo.

**Watch the repo size.** 40 MB per source model does not scale to six crew.
Decide whether source models are committed or only the baked sheets.

---

## Brief B — mission and event writing

**Deliverable:** prose in `world/`, in the folders that already exist.

No code. The largest single body of outstanding work.

- Read `SETTING.md` first — Sol in 2100, a gold rush, **no aliens and no
  faster-than-light travel**. Those two are hard rules, not flavour.
- Read `VOICE_AND_EVENTS.md`. §3 is binding on TOCK: no contractions, states
  probabilities unprompted and does not soften them, and **never says anything
  the log has not already stated in plain form**. A line carrying information
  the log does not is a bug.
- `world/README.md` sets the direction: **prose in, JSON out, never the reverse
  without saying so.** The writer writes prose. Converting it to `data/*.json` is
  a separate job and belongs to whoever holds the code.
- Crew names follow the rule in `data/crew.json`: two syllables where possible,
  hard consonants, spellable on first hearing, must survive being shouted across
  a burning room, distinct initials.

**Acceptance:** a human reads it and it sounds like the setting. There is no
machine check for this and pretending otherwise is the main way it goes wrong.

---

## Brief C — UI chrome

**Deliverable:** a design, then an implementation.

Two stages, and the design must land first.

1. **Design pass.** Mock-ups against the owner's reference. The visual target is
   **Void War** — dark techno-gothic, low saturation, heavy detail — *not* FTL's
   bright primaries. `CLAUDE.md` is explicit about this and about the four places
   FTL is still legitimately cited.
2. **Implementation.** Kenney *Fantasy UI Borders* 9-slices are already in
   `assets/ui/`, CC0, unwired.

**The trap, and it has bitten this project before:** every UI node must sit
inside a container, or have an explicit `position` **and** `custom_minimum_size`.
A free-floating `Control` defaults to zero size at (0,0) and becomes invisible.
`CLAUDE.md` names this the number one cause of "the game runs but the screen is
empty".

**Also:** `ui/ship_overlay.gd` is deliberately unshaded. The 2D lights exist to
make the hull read as metal and must never dim a name plate or a progress bar.
Readability of state outranks lighting.

---

## Brief D — enemy ship plate

**Deliverable:** one PNG.

`ASSETS.md` "Ship plate spec" is the contract and is not negotiable — it was
written after two plates failed. The hard requirements in short: strict
orthographic top-down, flat black background, **no text anywhere**, no room
colour fills, every compartment separated by a visibly lighter bulkhead band
unbroken except at doorways, compartment floors darker than the bulkheads, one
even overhead light source, no crew or damage, 2048 px minimum on the long axis,
delivered as a direct PNG download.

**Add this, and it is the single thing that made the current ship tractable:**
paint a **guidance stripe down the centre of every corridor** in a colour used
nowhere else on the plate. The current ship uses yellow. It exists so the
corridor network can be traced automatically instead of guessed, and it turned a
day of eyeballing into one pass.

**State the origin on delivery** — generated, bought, or found. This repository
is public and publishes to GitHub Pages, so it matters, and it is far cheaper to
answer when the image arrives than to reconstruct later.

---

## How to hand a task out

A brief that works contains four things, and the fourth is the one usually
missed:

1. **The deliverable.** One sentence. A file, at a path, in a format.
2. **The acceptance test.** A command to run, or a named human who looks at it.
3. **The constraints that are not obvious.** The stripe on a ship plate. The
   non-T-pose. TOCK's contractions rule.
4. **What "done" explicitly does not include.** Scope discipline is in
   `CLAUDE.md` for a reason: `GAME_SPEC v0.1 §2` and `v0.2 §3` are lists of
   things that must **not** be built, and they are not advisory. The Soldier is
   deliberately the weakest class and the Medic deliberately near-useless
   alongside a Clone Bay. Both are correct. Do not let anyone invent
   compensating mechanics.
