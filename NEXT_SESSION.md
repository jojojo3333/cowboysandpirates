# NEXT_SESSION.md — after the corridors

Written at the end of the session that traced the new ship and stopped crew
walking through walls. Delete this file once the work in it is done.

---

## Read these first

`CLAUDE.md`, then the top of `SLICE.md`, then `ASSETS.md`.

## Where the project actually is

Slice 0 (the cargo hold rescue) plays start to finish on a new ship. The plate
is the owner's `playerwarship1.png`, 1797x875, thirteen compartments traced off
its bulkheads with a corridor graph traced off the yellow guidance stripe. Crew
walk the corridors. Rooms have capacities and `sim/` enforces them.

Both verify commands are green and the balance report reads **42.4s for both
plans**, end HP [100 ×5] hack and [75 ×5] fight. It read 39.4s on the old plate;
the difference is one transit, because turret control is now four hops from the
hold instead of three. Nothing was retuned to hide that.

```
tools/verify.sh          # both; must be green before any commit
```

The game is live at https://jojojo3333.github.io/cowboysandpirates/ — Pages
deploys on every push to `main` and to `claude/**`.

---

## The thing worth deciding before building anything else

**Crew detour into every room on the route.** A hop is room-to-room, so walking
from turret control to the hold takes TOCK *through* the magazine and *through*
the medbay — in one door and out the other — rather than straight down the
corridor past them. The log agrees with the picture ("TOCK IN MAGAZINE"), so it
is consistent rather than broken, but on a ship with one long central corridor
it reads as odd, and it did not on the old six-room plate where rooms genuinely
joined each other.

Three ways out, in ascending order of cost:

1. **Leave it.** It is honest, it is consistent with the log, and the detours
   are what make the ship feel big.
2. **Make the corridor itself the graph** — every compartment adjacent to every
   other, because that is physically true: you never pass through a room to get
   anywhere. Costs the ship all of its travel structure; every move becomes one
   transit, and the report drops to about 33.4s.
3. **Charge transit by distance rather than per hop.** The corridor polyline
   already knows how long each walk is. This is the version that makes the ship's
   size mean something, and it is a real change to `sim/` and to
   `scene_rescue.json`, so it wants its own slice and its own [PLAY-GATED] number.

This is an owner decision, not an engineering one. Do not pick one unasked.

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

- **Plate licence, still unanswered.** Two owner-supplied plates now, neither
  with a recorded origin, in a public repository that publishes to GitHub Pages.
  `ASSETS.md` has the detail. One line closes it: generated, bought, or found.
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
