# NEXT_SESSION.md — corridors, walls and walk routes

Written at the end of the session that built the plate pipeline, for the session
that comes after it. Delete this file once the work in it is done.

---

## Read these first

`CLAUDE.md`, then the top of `SLICE.md`, then `ASSETS.md` §"Ship plate spec".

## Where the project actually is

Slice 0 (the cargo hold rescue) plays start to finish. Three render passes are
done: the ship is a painted plate, Godot's 2D lighting is on, and crew are
sprite sheets rendered from rigged CC0 3D models with real walk cycles.

Both verify commands are green and the balance report reads **39.4s for both
plans**, end HP [100 ×5] hack and [75 ×5] fight.

```
tools/verify.sh          # both; must be green before any commit
```

The game is live at https://jojojo3333.github.io/cowboysandpirates/ — Pages
deploys on every push to `main` and to `claude/**`.

## The one known bug, and the job

**Crew walk through walls.** `ShipView._walk_position()` moves them
`room centre → door point → room centre` in straight lines, so they cut across
bulkheads and sometimes cross half the ship diagonally.

The fix is not a code trick. It is data: the plate now *shows* corridors, and
the walk graph has to be traced off it.

---

## Task 1 — swap the plate

The project owner has replaced `assets/ship/hull_plate.png` with a new deck plan
and deleted the old one. It is a military ship with a full corridor network, a
yellow guidance stripe down every corridor, and roughly twelve rooms.

1. Read the new image and get its real dimensions.
2. Re-run `python3 tools/make_normal_map.py assets/ship/hull_plate.png` — the
   old `hull_plate_normal.png` belongs to the old ship and will be wrong.
3. Update `plate_size` in `data/ship_layout.json` to the new dimensions.

## Task 2 — trace the rooms

Overlay a 100px coordinate grid on the plate and read the compartments off it —
that is how the previous two plates were traced and it works. Write polygons in
plate pixels into `data/ship_layout.json`.

**Room list, with the capacities the owner decided:**

| Room | Capacity | Notes |
|---|---|---|
| Cockpit / bridge | 4 | |
| Turret & missile control | 4 | magazine should sit beside it |
| Shield room | 4 | |
| Reactor | 4 | the glowing core |
| Engine room | 4 | |
| Life support / O2 | 2 | built into the structure near the engines |
| Medbay | 4 | |
| Crew quarters + food dispenser | 6 | |
| Prison block | 4 | four cells along one wall |
| Cargo bay | 6 | |
| Greenhouse | 2 | |
| Airlock / boarding bay | 4 | where boarders come in |

**Six ids must not change**, because `data/scene_rescue.json` and the rescue
script key off them: `weapons`, `shields`, `medbay`, `reactor`, `engines`,
`cargo`. Map those onto the matching compartments; the six new rooms get new ids.

**`tock_start_room` is `weapons` and `captives_room` is `cargo`.** On the old
plate those were three hops apart, which is what the 39.4s balance figure comes
from. On a twelve-room ship they will not be three hops apart, so **the balance
report will move.** That is correct and expected. Report the new number; do not
reshape the layout to preserve 39.4s, and do not touch `data/scene_rescue.json`
timings to compensate.

## Task 3 — trace the corridor graph

New section in `data/ship_layout.json`. Suggested shape, but choose whatever is
simplest to read:

```json
"waypoints": [ {"id": "w1", "at": [x, y]}, ... ],
"corridor_edges": [ ["w1", "w2"], ["w2", "w3"], ... ],
"room_doors": [ {"room": "cargo", "waypoint": "w7", "at": [x, y]}, ... ]
```

- Follow the **yellow centre stripe** — it was put in the generation prompt
  specifically to be traced, so use it.
- Waypoints at every corridor junction, every bend, and every room doorway.
- A corridor that dead-ends against the hull gets no waypoints. The plate has a
  few of those; they are cosmetic and can be ignored.
- Validate in `tools/validate_data.gd`: every room must reach every other room
  through the graph, and every waypoint coordinate must be inside the plate.

## Task 4 — make crew follow it

- `ShipLayout.path()` currently returns a room-to-room chain from `adjacent`.
  Keep that — the simulation should stay unaware of geometry.
- In `ui/`, expand each room hop into a corridor route: room centre → its door
  → waypoints along the graph → next room's door → next room centre. A
  breadth-first search over `corridor_edges` is enough; there is no need for A*
  at this scale.
- `_walk_position()` then walks that polyline instead of a three-point line.
- `ShipOverlay._draw_route()` already draws whatever `route_points()` returns,
  so the dashed route line will follow the corridors for free.

**Check it by looking, not by reasoning.** Capture a walk with a throwaway
script (there was one last session: instantiate `main.tscn`, `choose_plan`,
`order_move`, tick, save PNGs) and assemble a GIF. If a crew member clips a
bulkhead you will see it immediately and never spot it in the numbers.

## Task 5 — room capacity

Add `capacity` per room in the layout, and enforce it in `sim/` — a room holds
at most N bodies, friend or foe. This is a simulation rule, so it goes in
`sim/`, writes a log line when a move is refused, and moves the balance report.

Not urgent. Do it after crew walk correctly, and only if there is time.

---

## Not in this session

- The six boarders as visible enemies. The owner's plan is three in the cockpit
  and three in the crew quarters, and it wants room capacity to exist first.
- UI chrome. It is the biggest remaining visual gap and it deserves its own
  session against the owner's mock-up.
- Weapon mount overlays. Agreed as the way to do upgrades later — small
  transparent PNGs placed at traced hull coordinates, the way FTL does it — but
  no art for it exists yet.

## Things that have cost time before

- **Check the crew models' capabilities before writing code around them.** They
  are rigged with `walk`, `idle`, `die`, `sprint`, `holding-right` and about
  twenty more clips. A session was spent faking a walk before anyone looked.
- **`CLIP_FRAMES` in `ui/ship_view.gd` must match `CLIPS` in
  `tools/render_crew.gd`**, or sheets are sliced wrongly.
- **The render camera's aim point moves the figure the opposite way to the
  intuition** — aiming higher pushes the body down in frame.
- **Never conclude from a headless screenshot that something feels good.**
  Colour and geometry are checkable; feel is not.
- The owner is not a programmer. Explain in outcomes, not in diffs.
