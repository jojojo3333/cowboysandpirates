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

## START HERE — status, 2026-08-17

Slice 0 plays start to finish. The ship is a traced thirteen-compartment plate
with a corridor graph; crew walk the corridors and travel costs distance. Crew
are the Silver Soldier with a walk authored on his own rig, tinted per class.
All three verify commands green, balance canary **40.3s**.

```
tools/verify.sh            # rules, static, sim — all three
```

**The first three things next session, in order:**

1. ~~**Verify the Beckett / Ziva claims.**~~ Partly done 2026-08-17 — findings
   appended to `world/research/2026-08-17-beckett-ziva-agent-loop.md`. **The
   trigger fired:** Beckett is real, its free Lite edition is MIT and does
   screenshot + live tree + runtime state, and Full is $15 one-time. Deterministic
   frame stepping in `satelliteoflove/godot-mcp` is real too.
   **So item 2 changes from "build a visual test harness" to "install Beckett
   Lite in a scratch copy and read the tool list off the running server".**
   Caveat, and it matters: this container can search the web but cannot fetch
   itch.io or the Godot forum, so all of it is second-hand and nothing has been
   installed. Ziva is still unchecked.
2. ~~**Item 1a**, crew selection and multi-crew orders.~~ **Done 2026-08-17.**
   Drag a box, everyone inside it who can take an order is selected, click a
   room and they all go. Clicking one crew member selects them; clicking a tied
   captive still cuts them loose.

   **The visible half was the small half.** The simulation modelled exactly one
   mover — a scene-wide `task`/`task_target`/`route` that always meant TOCK —
   so movement had to be moved onto `CrewMember` before a squad order could
   mean anything. `Task.TRANSIT` is gone; what is left of `Task` is FREEING,
   which genuinely is scene-wide because only TOCK does it and only one at a
   time. **The balance canary did not move**, which is the evidence the
   refactor changed the shape and not the behaviour.
3. ~~**Fix the wonky walk.**~~ Done 2026-08-17, together with the camera move to
   80°. The two were the same job: the walk was wonky *because* it was built for
   a view the game did not have. See "The camera angle" in `ASSETS.md`.
   **The pitch itself is still open** — it is one constant, `CAMERA_PITCH` in
   `tools/render_soldier.gd`, and the owner has the comparison renders. Moving
   it means re-running `--mode bake` and pasting the `CREW_ART_OFFSET` it
   prints into `ui/ship_view.gd`.

### Next after crew selection: make the enemy ship look alive

The owner's read, and it is the right one — **a hostile ship with three figures
standing perfectly still is scenery, not a threat.** People moving between
compartments, working a station, reacting to being hit, is the thing that turns
the combat screen from a picture into an opponent.

**It is blocked on something unglamorous, and skipping that is the trap.** The
enemy ship has no room data at all: `assets/ship/enemywarship1.png` is a plate
and nothing else. No traced polygons, no adjacency, no corridor graph, no doors
— none of what `data/ship_layout.json` gives the player's ship, and all of which
`ui/corridor_map.gd` needs before anybody can walk anywhere. The three hostiles
currently stand at pixel coordinates measured off the image by eye.

So the order is:

1. **Trace the enemy plate** the way the player's was — rooms as polygons,
   corridor waypoints, doors. This is the whole job; everything else is small.
2. Give the enemy a crew list and a room each. Static, but *addressable*.
3. Then behaviour. Idle work at a station, walking between rooms, reacting.

Step 3 without step 1 produces figures sliding through bulkheads, which is the
exact bug the player's ship had before 2026-08-16 and which cost a session.

**Do not invent enemy mechanics while doing this.** `GAME_SPEC v0.1 §2` and
`v0.2 §3` are lists of what must not be built. Movement and presence are
presentation; boarding rules, morale and enemy AI are design, and the specs get
consulted first.

**Owner is providing:** reference images for the UI look. Nothing UI-shaped
should be built before those arrive — there is no UI art in the project at all
now, deliberately.

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
  looking at it side-on at 18 degrees and shipped at 62. It looked wonky for
  exactly that reason. `--mode preview` now shoots at `CAMERA_PITCH` so this
  cannot recur.
- **…and get the reason right, not just the conclusion.** The line above used to
  say leg swing was "heavily foreshortened" at 62°. That was backwards. Screen
  offset for a world displacement is `(dx, dy·cos p − dz·sin p)`, so raising the
  camera makes horizontal movement *more* visible, not less — it is **vertical**
  movement that vanishes. The advice happened to be right while the reasoning
  was wrong, which is the worst failure mode for a note like this, because
  nobody re-checks a rule that keeps working.
- **A camera angle is not one constant.** Moving it changes which movements
  survive projection, so the animation has to be re-authored, not rescaled, and
  every script that photographs a model has to move with it. `tools/verify.sh
  rules` now checks `render_soldier.gd` and `preview_models.gd` agree.
- **Render the comparison before believing the reasoning.** "A pure overhead
  view of a human is a blob" sat in `ASSETS.md` for a day and decided the camera
  angle. It took one contact sheet to show it was false at every angle tested.
- **A view that builds itself lazily can be clicked before it exists.**
  `ShipView` creates its Node2D world on the first `_process` that has a scene
  and a layout, but `_gui_input` starts arriving the moment the node is in the
  tree — and the pointer is usually already over the window when a scene loads.
  The first mouse motion hit a null `_world` and killed the combat screen on
  load. Guard the coordinate helpers, not just the click handler.
- **A GDScript runtime error does not fail anything by itself.** It prints
  `SCRIPT ERROR`, carries on, and leaves the exit code at 0, so no assertion
  inside the script can ever see it and a run full of null dereferences reports
  itself green. `tools/verify.sh play` now greps its own output, the same way
  `static` always has.
- **Beware frame-timing races in the checks themselves.** The first attempt at a
  regression test for the bug above poked a real scene after one frame — and
  whether the world had been built by then varied between scenes and between
  runs. It passed on the broken build. The version that works constructs a bare
  `ShipView` that is guaranteed to have nothing built.
- **A mutation test needs a re-import to mean anything.** Editing a `.gd` file
  and re-running `--script` uses Godot's cached compile, so the "broken" build
  is quietly still the working one. Two mutation tests here reported green
  against code that was genuinely broken before this was noticed. Run
  `--headless --import` between the edit and the test.
- **`set_anchors_preset()` sets the anchors and leaves the offsets alone.** A
  Control can end up with anchors 0,0,1,1 and offsets 0,0,-1920,-1080, which is
  a 0x0 node whose children collapse into the top-left corner. Use
  `set_anchors_and_offsets_preset()`. This is the real mechanism behind the
  "game runs but the screen is empty" warning in `CLAUDE.md`.
- **A "bright pixels are bulkheads" mask reads the yellow corridor stripe as a
  wall.** Exclude yellow before thresholding.
- **Never conclude from a headless screenshot that something feels good.**
  Colour and geometry are checkable; feel is not.
- **Before saying something cannot be done — or is hard — say what it would
  actually require and check each requirement.** Five times in two days the
  answer was "that needs a tool I do not have" or "that is bigger than it
  looks", when the real requirement was something plainly doable. Most
  expensively: "animation needs Mixamo", when the walk turned out to be 200
  lines of bone rotation. Most recently: "making corridors walkable changes what
  a location is", when a room is six fields and a corridor has all six. The
  owner asking "are you sure?" broke every one of them. **Check the actual
  requirement before estimating.**
- The owner is not a programmer. Explain in outcomes, not in diffs.

**Most of the list above is now enforced rather than remembered.**
`tools/check_rules.py` turns them into checks that run as `tools/verify.sh
rules`. That file exists because the owner noticed that roughly every third
exchange contained "you are right, and it was already in our documents". A rule
in a document is something a reader might remember; a rule in a check is
something that stops them. **Add a check in the same breath as agreeing a
rule.**

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

### 0. Verify the agent-loop tools — *ten minutes, reorders everything below*

`world/research/2026-08-17-beckett-ziva-agent-loop.md` claims two Godot plugins
let an agent run the game, read the live scene tree, screenshot it, inject input
and assert on the result. If true, that is most of item 2 off the shelf.
**Unverified — this container cannot reach GitHub's web UI or the Asset
Library.** Three asset descriptions were wrong this week; check before building.

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

### 2. A visual test harness — *new, and it changes how everything else goes*

The simulation has an automatic answer to "did I break it". Art has none, which
is why every visual change costs a human looking at it, and why two days went on
crew sprites. The research in `world/research/` lays out three layers; the
middle one is the surprise and the reason this is worth building:

- **Golden-frame comparison** with SSIM and a tolerance, not pixel equality.
- **Silhouette and contact-point contracts.** Give each entity an expected
  bounding box, centroid and ground point, render a flat debug pass, and assert
  against it. This catches the class of bug where *the art looks fine but the
  position is wrong* — and it would have caught the HUD collapse instantly:
  expected 1920x1080, actual 845x568.
- **A contact sheet.** Not a test — the human review interface for the tests.

Build it small and project-owned rather than adopting a framework. It slots into
`tools/verify.sh` as a third command alongside `static` and `sim`.

### 3. Slice 1 — the pirates open fire (phase B)

Defined in `SLICE.md`. The first real combat. Do not start it before crew
movement exists.

### 4. The six visible boarders — *unblocked by room capacity, needs #1*

Three in the cockpit, three in crew quarters. Cockpit holds 4, crew quarters
holds 6, so both fit with room to send people in after them. Needs enemy crew as
a concept in `sim/`, which does not exist yet.

Note the enemy ship's interior is deliberately **not** drawn — you cannot see
inside a ship you have not boarded. Only its hull.

### 5. Crew art replacement — **[OUTSOURCEABLE]**

The Kenney crew read as too cartoonish. Two candidate packs assessed and both
fall short — `ASSETS.md` has the measurements. See **Brief A**.

### 6. UI chrome — **[OUTSOURCEABLE]**

Still the largest visual gap. The Kenney fantasy borders have been **deleted** — 281 files,
never wired up, and ornate fantasy frames were wrong for a grimdark
freighter anyway. There is now no UI art in the project at all, which is
the right starting point. See **Brief C**.

### 7. Mission and event content — **[OUTSOURCEABLE]**

`world/` has five empty folders — `crew`, `gameworld`, `missions`, `storyboard`,
`voice`. `VOICE_AND_EVENTS.md` is the spec and only §6 is built. This is the
largest body of work that needs no code at all. See **Brief B**.

### 8. Weapon mount overlays

Small transparent PNGs at traced hull coordinates, the way FTL draws upgrades.
The plate has six turret barbettes, three top and three bottom, which are the
obvious mount points. No art exists.

### 9. Enemy ship plates — **[OUTSOURCEABLE]**

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
| Rest pose | **not a T-pose.** From 80° above a T-pose is a starfish, not a person |
| Height | figure roughly 1.0–2.0 units, standing on the origin, facing −Z |
| Licence | CC0 preferred. CC-BY accepted **with the credit line supplied** |

**The design test, which matters more than any of the above.** At 66 px seen
from 80° overhead, realistic proportions read *worse* than exaggerated ones —
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

**E1 — Can "does this look right" be machine-checked?** — **ANSWERED 2026-08-17.**
Report in `world/research/`; what to build with it is item 2 in the queue. The
remaining text is kept because the brief is a good template for E2 and E3.

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
(`tools/render_soldier.gd`). The camera is 80 degrees above horizontal.

**Partly answered in-house on 2026-08-17** — the walk was rebuilt around hip and
shoulder counter-rotation, leg splay, arm spread and lateral sway, on the
reasoning that only horizontal movement survives an overhead projection. That is
derived from the projection, not from anyone who animates for a living, and it
has only been judged on stills in a GPU-less container.

Still wanted, and now more specific: whether the counter-rotation should lead or
lag the leg swing; whether feet should be pinned to the floor and how; how many
frames a walk needs to read at ~35 px; and whether 8 frames at 11 fps is the
right budget. **Deliverable:** concrete numbers we can put straight into the
constants at the top of that file.

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

## Mission 1 — the shape, decided 2026-08-17

**It is one mission in two phases, not two missions.** The player never sees a
break. The whole thing is the tutorial and there is no separate tutorial mode.

**Phase A — take the ship back.** Both ships are on screen from the first frame.
The enemy hull is visible but its interior is not: you cannot see inside a ship
you have not boarded. Your crew are in the cargo bay, restrained. A deal went
wrong and they were taken by surprise — not beaten in a fair fight, which
matters for how the crew talk about it afterwards. The pirates think it is over.
TOCK is loose, and the crew can arm themselves once freed.

**Phase B — the pirates object.** Control of the ship is yours, and immediately
the pirate ship opens fire. The first shots take shields, not hull, so you are
not dying — you are *behind*. The crew you just freed are the resource, and they
now have to be somewhere: stations manned, systems powered, someone in the
cockpit.

**Why this shape works.** Phase A teaches one verb — move a person, and moving
is all you can do. Phase B keeps that verb and adds a reason to move *fast* and
*to the right place*. Relief, then pressure. The crew you rescued become the
crew you have to deploy, so the tutorial's reward is the next scene's mechanic.

**It also resolves the conflict flagged yesterday.** Phase B is ship-to-ship
gunnery, which is exactly `SLICE.md` Slice 1. Boarding is only in phase A, and
only in the abstracted form that already exists — the hack/fight choice — so
nothing here needs the full boarding mechanic that `GAME_SPEC v0.2 section 3`
defers. If phase A ever grows into a real room-by-room fight, that is a separate
decision.

**What blocks it:** item 1. Both phases are unplayable while only TOCK takes
orders.

## Item 1, expanded — how crew movement should actually work

Split into two pieces because the second is bigger than it looks.

### 1a. Selection and multi-crew orders

- Click a crew member to select. Click another to switch. Click empty space to
  clear.
- **Drag a box to select several**, the way every squad game does it. Shift-click
  to add and remove individuals.
- With a selection, clicking a destination orders everyone in it.
- `order_move` takes a crew member instead of assuming `scene.tock`. Room
  capacity already exists and applies to whoever walks.

### 1b. Corridors as destinations

**This was written up as the hard half. It is not, and the first assessment of
it was wrong.** Recorded because the mistake is the same shape as the others in
the list above.

A "room" in this project is exactly six fields: `id`, `label`, `system`,
`polygon`, `capacity`, `adjacent`. Nothing else. Hit-testing, capacity checks,
pathfinding, lighting and crew placement all run off those six. **A corridor
segment has all six.** So corridors become destinations by adding entries to
`rooms[]` in `data/ship_layout.json` with polygons traced along the corridor
stretches — the same tracing already done for the compartments — and the
existing machinery picks them up for free.

`system` is empty, which is already supported: the reactor and the cargo bay
have no system either.

Three real consequences, none of them blockers:

- **Adjacency changes shape and gets more honest.** Today every compartment on
  the corridor is adjacent to every other, which is a shortcut standing in for
  "they share a corridor". With corridor segments as places, it becomes
  compartment to corridor to compartment, which is what the ship actually is.
  Travel already costs distance rather than hops, so this moves the balance
  number only by the small difference between routing via a corridor centroid
  and routing along the stripe.
- **`_slot()` in `ui/ship_view.gd` places crew in a grid around the centroid.**
  A long thin corridor wants them strung out along its length instead. One
  function.
- **Corridors would get a `PointLight2D` each**, since lights are added per
  room. Probably an improvement; may want a dimmer, longer light for a corridor
  than for a compartment.

The `walk_distances` table is regenerated by the same script that produced it.

**Do 1a first anyway** — not because 1b is hard, but because 1a alone unblocks
phase A and the two are easier to judge separately.

## A note on the research, and on unverified claims

`world/research/2026-08-17-ai-assisted-godot-games.odt` describes four
generations of AI-assisted development, ending with one where the model can
inspect the running game rather than guess at it. That framing is worth keeping.

**We are further along it than the report assumes.** This project already runs
the game headless, screenshots it, renders walk cycles to GIF, reads binary GLB
files and runs a 50-run simulation harness. The reason three outside packages
arrived broken this week and the same tasks worked here is exactly that loop —
not a better model.

~~What is genuinely missing is that the loop is **ad hoc**.~~ **Built, 2026-08-17.**
Poking at a running scene used to mean writing a throwaway probe each time —
that is how the HUD anchoring bug was found, in two minutes, by a script that
was then thrown away. `tools/game_probe.gd` is that probe kept, and
`tools/verify.sh play` runs a whole mission against it. `ARCHITECTURE.md 5b` has
the design.

**What it cost to make it real, which is the part worth remembering.** Writing
the checks took an hour; finding out they *worked* took longer and was the
valuable half. Three deliberate breakages, and the first two passed:

- the sprite art offset — the probe was comparing the wrong number, so it would
  have missed the very bug fixed that morning;
- the collapsed HUD Control — `BACKLOG.md` called it "a 0x0 node", so the probe
  hunted for zero sizes; a *Container* with stale offsets shrinks to fit its
  children instead, coming back 1071x609 in a 1280x720 window;
- and beneath both, the layout assertions had been passing on numbers that meant
  nothing, because headless Godot lays the root Control out against a 64x64
  stand-in window.

**So: break it on purpose before believing it.** That is now in `CLAUDE.md`.
It is the same lesson as the camera angle earlier the same day — a confident
description of how something behaves is not evidence of how it behaves.

**The named games and tools in that report were unverified.** Beckett and
`satelliteoflove/godot-mcp` have since been checked as far as this container
allows — see the appendix to
`world/research/2026-08-17-beckett-ziva-agent-loop.md`. FARLUME, Void Balls,
Ziva, GDSnap and Stagehand are still unchecked. Treat the *pattern* as sound and
the remaining *citations* as leads.

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
