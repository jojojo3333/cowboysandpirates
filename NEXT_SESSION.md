# NEXT_SESSION.md — after the corridors

Written at the end of the session that traced the new ship and stopped crew
walking through walls. Delete this file once the work in it is done.

---

## Read these first

`CLAUDE.md`, then the top of `SLICE.md`, then `ASSETS.md`.

`BACKLOG.md` is the ordered queue of everything known to be missing or wanted,
and holds the briefs for work being done outside this repo. This file is only
the handover from the last session; the backlog is the standing list.

## Where the project actually is

Slice 0 (the cargo hold rescue) plays start to finish on a new ship. The plate
is the owner's `playerwarship1.png`, 1797x875, thirteen compartments traced off
its bulkheads with a corridor graph traced off the yellow guidance stripe. Crew
walk the corridors, take no detours through rooms they are only passing, and
travel costs distance rather than a flat fee per room. Rooms have capacities and
`sim/` enforces them.

Both verify commands are green and the balance report reads **40.3s for both
plans**, end HP [100 x5] hack and [75 x5] fight. It read 39.4s on the old ship
and 42.4s on this one before travel costed distance. Nothing was retuned.

```
tools/verify.sh          # both; must be green before any commit
```

The game is live at https://jojojo3333.github.io/cowboysandpirates/ — Pages
deploys on every push to `main` and to `claude/**`.

---

## Where the crew art stands

The Kenney crew are still live and still too cartoonish for the owner's taste.
Two candidate replacements were measured and both fall short — `ASSETS.md` has
the full assessment. The short version:

- The Skyzor sprite pack is **rejected outright**: pre-rendered at a fixed
  isometric camera that cannot be re-angled to our 62-degree overhead view.
- The wolkoed modular bodies are **in the repo but not wired up**. Rigged with a
  Mixamo-named skeleton, but shipping **no animation clips and no body texture**.
  As-is they render as white figures in a T-pose.

**The lesson worth keeping:** at 66 px from overhead, the realistic bodies read
*worse* than the cartoon ones — thin, pale, small. Kenney's exaggerated
proportions are what make a figure legible at that size. Anything that replaces
them needs bulk it has *earned* — armour, a pack, a helmet — not just realistic
anatomy. Photograph any candidate with `tools/preview_models.gd` before
committing to it; it uses the game's own camera and settles the question in one
image.

## Not built, and asked for explicitly: crew movement

**Only TOCK can move.** `main.gd:_on_room_clicked` calls `order_move()`, which is
hardcoded to `scene.tock`, and `_on_crew_clicked` calls `order_free()`, which only
unties. There is no "selected crew member" concept anywhere in the project, so a
crew member cut loose in the hold turns ACTIVE and then stands still for the rest
of the game.

The owner spotted this from play and asked for it to be recorded rather than
built. It is item 1 in `BACKLOG.md` and it blocks the boarders, Slice 3 and any
tutorial that asks the player to move a person.

## Carried forward, not done

- **The six boarders as visible enemies.** The owner's plan is three in the
  cockpit and three in the crew quarters. Room capacity now exists, which was
  the stated prerequisite. Note the cockpit holds 4 and crew quarters holds 6.
- **UI chrome.** Still the biggest remaining visual gap, still deserves its own
  session against the owner's mock-up. Kenney's fantasy border 9-slices are
  already in `assets/ui/` and still unwired.
- **Weapon mount overlays.** Small transparent PNGs at traced hull coordinates,
  the way FTL does upgrades. No art for it exists yet. The new plate has six
  turret barbettes on the hull, three top and three bottom, which are the
  obvious mount points.

## Open questions for the owner

- ~~Plate licence.~~ **Answered 2026-08-16: both plates are model-generated.**
  Nothing in `assets/ship/` is third-party artwork. Ask the same question of the
  next plate, at the moment it arrives.
- **The magazine is a thirteenth room.** The brief asked for twelve. The plate
  has a fully walled compartment full of missile racks beside turret control,
  with its own doorway onto the corridor, so leaving it out would have left a
  visible room nobody could ever enter. It is in as `magazine`, capacity 2. Say
  if it should be folded into `weapons` instead.
- **Two service nooks are not rooms.** A closet off the engine room and a
  vestibule between the reactor and the corridor. Both are narrow, both are
  full of equipment, neither is somewhere a person stands. They are walkable in
  the sense that the reactor's route passes through the vestibule; they are just
  not compartments.

## Things that have cost time before

- **Check the crew models' capabilities before writing code around them.** They
  are rigged with `walk`, `idle`, `die`, `sprint`, `holding-right` and about
  twenty more clips.
- **`CLIP_FRAMES` in `ui/ship_view.gd` must match `CLIPS` in
  `tools/render_crew.gd`**, or sheets are sliced wrongly.
- **The render camera's aim point moves the figure the opposite way to the
  intuition** — aiming higher pushes the body down in frame.
- **Never conclude from a headless screenshot that something feels good.**
  Colour and geometry are checkable; feel is not.
- **A "bright pixels are bulkheads" mask reads the yellow guidance stripe as a
  wall.** That cost a confusing round of false positives while checking the
  routes. Exclude yellow before thresholding.
- The owner is not a programmer. Explain in outcomes, not in diffs.
