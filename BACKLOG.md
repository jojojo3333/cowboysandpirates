# BACKLOG.md — what is next, and what can be handed to someone else

**This is the one file to open when you want to know what happens next.**
It is the single ordered list of everything known to be missing, wanted or
broken, and it doubles as the brief pack for work done outside this repo.

## Where things live, so this file does not duplicate them

| Question | File |
|---|---|
| **What is next?** | **this file** |
| What is the build order, and what is done? | `SLICE.md` |
| What are the rules of the game? | `GAME_SPEC.md` |
| How do `sim/` and `ui/` divide? | `ARCHITECTURE.md` |
| Where did an asset come from, and what does a new one need? | `ASSETS.md` |
| What is the world, who is in it? | `SETTING.md`, `world/` |
| How is it written? | `VOICE_AND_EVENTS.md` |

**There used to be three files talking about the future** — this one,
`NEXT_SESSION.md`, and the open-questions section of whatever was edited last.
That was two too many, so `NEXT_SESSION.md` is gone and everything it held is
here. Now there is one rule:

- **`BACKLOG.md` — what happens next.** Nothing else may hold a queue.
- **`SLICE.md` — what the game is, in build order, and what is already done.**
  It records history and the shape of the thing; it does not schedule work.
- **`GAME_SPEC.md` — the rules**, including the lists of what must *not* be
  built.

If a future item ends up written anywhere else, move it here and leave nothing
behind.

---

## Status, 2026-08-16

Slice 0 (the cargo hold rescue) plays start to finish. Three render passes done,
the ship replaced, corridors traced, travel costing distance. Both verify
commands green, balance report **40.3s** for both plans.

**Current slice: 1** — the boarders' ship attacks. Not started.

---

## Things that have already cost time

Carried forward so they are not rediscovered. Every one of these was paid for.

- **Check what a model actually contains before writing code around it.** Three
  separate crew packs were described as having animation. One had a rig and no
  clips, one had neither, one had a 12.72 s clip that turns out to be a man
  raising and lowering a rifle. `tools/preview_models.gd` answers this in one
  command and `ASSETS.md` records what each pack really held.
- **`CLIP_FRAMES` in `ui/ship_view.gd` must match `CLIPS` in
  `tools/render_soldier.gd`**, or the sheets are sliced wrongly and crew animate
  through their neighbours' frames.
- **Tune art in the view the game actually uses.** The walk cycle was shaped
  looking at it side-on at 18 degrees; the game sees crew from 62 degrees, where
  a leg swing is heavily foreshortened. It looks wonky for exactly that reason.
- **`set_anchors_preset()` sets the anchors and leaves the offsets alone.** A
  Control can end up with anchors 0,0,1,1 and offsets 0,0,-1920,-1080, which is
  a 0x0 node whose children collapse into the top-left corner. Use
  `set_anchors_and_offsets_preset()`. This is the real mechanism behind the
  "game runs but the screen is empty" warning in `CLAUDE.md`.
- **A "bright pixels are bulkheads" mask reads the yellow corridor stripe as a
  wall.** Exclude yellow before thresholding.
- **Never conclude from a headless screenshot that something feels good.**
  Colour and geometry are checkable; feel is not.
- **Before saying something cannot be done, say what it would actually require
  and check each requirement.** Four times in two days the answer was "that
  needs a tool I do not have" when the real requirement was something plainly
  doable — most expensively, "animation needs Mixamo", when the walk was 200
  lines of bone rotation. The owner asking "are you sure?" is what broke each
  one; that question is worth asking every time.
- The owner is not a programmer. Explain in outcomes, not in diffs.

## What the balance number is, and is not

You will see **40.3s** quoted everywhere. It has been reported at you like a
score, which was misleading. Here is what it actually is.

`tools/sim_runner.gd` plays the rescue mission 200 times with no UI attached, as
fast as the machine can. Each run it measures how much **in-game** time passed
from the plan being chosen to the last captive being freed. 40.3s is that
figure. The 200 runs take about two seconds of real time.

**It is a canary, not a target.** Its only value is: *did it move when nothing
should have moved it?* The simulation survived two complete renderer rewrites
and a total ship replacement without breaking, and this number is how that was
known. When it did move, it moved for reasons that were stated:

| | |
|---|---|
| 39.4s | the original six-room ship |
| 42.4s | new thirteen-room ship — turret control went three hops from the hold to four |
| 40.3s | travel started costing distance instead of a flat fee per room |

**Nobody is aiming for a particular number.** There is no "good" value. A change
that moves it is fine as long as the reason is understood; a change that moves
it *unexpectedly* is a bug. `CLAUDE.md` calls these figures [PLAY-GATED] —
report them, never tune them.

The player never sees any of this. The log no longer prints mission timestamps
either: leaving the game unpaused while you make coffee produced lines like
"812.4s BOARDER DOWN", which tells you nothing except how long you were away.

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

## Two ships on one screen — measured, 2026-08-16

Slice 1 needs the player ship and an enemy ship side by side. **They fit, above
1080p.** Run it and resize the window:

```
open tools/two_ship_test.tscn in Godot, press F6
```

Both ships draw from the same plate at one shared scale — two ships at different
sizes would read as one being nearer the camera. Bands are reserved above and
below for the UI that is not built yet, so the test answers "does it fit *with*
the chrome", not "does it fit on a bare screen".

| Window | Ship scale | Room | Crew figure | |
|---|---|---|---|---|
| 1280x720 | 0.35 | ~69 px | **~23 px** | tight |
| 1600x900 | 0.44 | ~88 px | ~29 px | borderline |
| 1920x1080 | 0.53 | ~105 px | ~35 px | fine |

**Crew size is the constraint, not the ship.** Crew are the smallest thing a
player must identify and click, and they run out of room long before the hull
does. 35 px is what the current single-ship build draws them at, so 1080p with
two ships is exactly as legible as today.

**Two things worth knowing before designing the UI:**

- **The plate has almost no wasted margin** — the hull fills 95% of the width
  and 91% of the height. Cropping buys nothing. If two ships must fit at 720p,
  the answer is a smaller plate or bigger crew, not a tighter crop.
- **There is a lot of spare *vertical* room.** The plate is 2.05:1, so at 16:9
  the layout is width-constrained: at 1080p each ship draws 948x461 inside a
  band 872 tall. The UI can be generous top and bottom without shrinking the
  ships at all. Horizontal space is the scarce thing; vertical is nearly free.

## What to send someone working outside this repo

**Send the whole repository.** It is small, it is public, and the parts that
matter most are the documents. Sending a subset means the contributor cannot run
`tools/verify.sh`, which is the one thing that tells them whether they are done.

If a subset is genuinely necessary — a model with no repository access, say —
then per track:

**Track A (art and assets)** needs no code at all:
- `BACKLOG.md` (Brief A and Brief D), `ASSETS.md`, `SETTING.md`
- `tools/preview_models.gd` and `tools/render_crew.gd` — as the *contract*, so
  they can see what the pipeline expects. Not to modify.
- one existing crew sheet from `assets/crew/` as a reference for the output
- for a ship plate: `assets/ship/hull_plate.png` as the reference to match

**Track C (viewer)** needs the whole `ui/` layer and its inputs:
- `CLAUDE.md`, `ARCHITECTURE.md`, `BACKLOG.md` (Brief C)
- `main.gd`, `main.tscn`, `ui/*.gd`
- `sim/*.gd` — **read-only**. The viewer calls into it constantly and cannot be
  understood without it, but Track C must not change it.
- `data/*.json`, and `assets/` so the thing actually renders
- `tools/verify.sh`, `tools/validate_data.gd`, `tools/screenshot.gd`

The one thing to say out loud in either brief, because it is not obvious from
reading the files: **`sim/` and `ui/` are separate on purpose and the separation
is load-bearing.** It is why the renderer could be rebuilt twice and the whole
ship replaced without the simulation noticing. A contributor who "helpfully"
reaches across it has broken something they cannot see.

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

## Brief E — research, not building

Three questions to send out. Research is the right job for a model that cannot
run the code: it produces something usable even when it cannot test anything.
The trap is vagueness, so each of these names its deliverable.

**E1 — Can "does this look right" be machine-checked?** *(the most valuable of
the three)*

This is the project's real bottleneck. The simulation has an automatic answer to
"did I break it" — `verify.sh` plus the balance canary — which is why it has
survived two renderer rewrites untouched. Art and feel have no such signal, so
every visual change needs a human to look, and that is where the last two days
went.

Wanted: how 2D games actually automate this. Golden-image comparison and its
tolerance problem, perceptual diffs, silhouette and contrast metrics at target
resolution, contact sheets for human review, animation smoothness measures.
**Deliverable:** three techniques described in enough detail to implement in
Godot 4, plus an honest section on what genuinely still needs eyes.

**E2 — Walk cycles from a Character Creator rig, seen from steeply above.**

We author a walk on the model's own bones and bake it to 8-direction sprites
(`tools/render_soldier.gd`). It reads as wonky. The camera is 62 degrees above
horizontal, which foreshortens leg swing badly.

Wanted: what swing angles, knee timing and foot-plant handling read correctly at
a steep overhead camera; whether feet should be pinned to the floor and how;
how many frames a walk needs to read at ~35 px. **Deliverable:** concrete
numbers we can put straight into the constants at the top of that file.

**E3 — Godot 4 web export budgets.**

We publish to GitHub Pages on every push. Nobody has measured what the build
costs a player.

Wanted: realistic download and load-time budgets for a Godot 4.7 web export,
which texture compression settings matter, what actually dominates size, and
the common mistakes that bloat a build. **Deliverable:** a target size, the
settings to reach it, and how to measure the current build against it.

**Not being outsourced: the tutorial.** That is a design question and it is the
owner's. The angle is not "how do tutorials work" but **"what do people hate
about tutorials"** — see below.

## The tutorial — the shape it is taking

Two missions, and the first one *is* the tutorial. No separate mode, no lesson.

1. **Rescue your crew** — the cargo hold. Built and playable.
2. **Repel the boarders** — the pirate ship that just took your crew has people
   aboard your ship. Not built.

Both must work before the run of five jumps exists.

**This conflicts with the current build order and someone has to decide.**
`SLICE.md` Slice 1 is ship-to-ship gunnery: two hulls, weapons charging,
click an enemy room to target it. What is described above is **boarding
combat** — enemies walking your corridors, your crew fighting them — and
`GAME_SPEC v0.2 section 3` currently lists boarding as deferred, do-not-build.

So one of three things has to happen, and it is an owner call:
- the spec changes and boarding moves into v0.1, or
- mission 2 becomes ship-to-ship after all, or
- mission 2 is a cut-down boarding fight scoped tightly enough not to be the
  full v0.2 mechanic.

Whichever way it goes, **item 1 in this queue blocks it**: you cannot defend a
ship when only TOCK can be given an order.

**On tutorials people hate.** Worth stating the design position rather than
researching it:

- Being told what is already on screen.
- Modal boxes that stop play to explain play.
- One permitted solution, enforced, before you may continue.
- Walls of text before any input.
- **And for a roguelike specifically: a tutorial you replay.** This is the big
  one. Players will restart constantly, and anything unskippable becomes poison
  by the fourth run. "The tutorial is mission 1" solves that — but only if
  mission 1 is still worth playing on the twentieth run. That is the bar it has
  to clear, and it is a higher bar than "teaches the controls".

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
