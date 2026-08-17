# ASSETS.md

Provenance record for every imported file.

**Currently: a player plate with its derived normal map, and an enemy plate.** The hull, the
compartment floors, the bulkheads and the doors are all art. `ui/ship_view.gd`
draws none of them; it builds the scene graph and lights it. `ui/ship_overlay.gd`
draws state only.

## What may be committed

Anything with its provenance recorded in the table below. Two normal sources:
**CC0** for anything fetched from the internet, and **owner-supplied** for art
the project owner generates or commissions and hands over.

Two things stay out, and both are about legal exposure rather than taste: files
extracted from another game, and art produced from a prompt that names a
protected character, ship, logo or property. This repository is public and
publishes to GitHub Pages, so committing either is distribution, and git history
keeps it after deletion.

## Vetted CC0 sources

Checked and safe to draw from. Verify the licence on the specific pack anyway,
because collections drift.

| Source | Licence | Notes |
|--------|---------|-------|
| [Kenney](https://kenney.nl) | CC0 | 40,000+ assets, no attribution required, commercial use fine. "Roguelike Characters" and the Tiny series suit small top-down figures. |
| [OpenGameArt CC0 filter](https://opengameart.org/content/all-cc0-uploader-kenney) | CC0 | Filter to CC0 explicitly; the site hosts other licences too. |
| [itch.io CC0 assets](https://itch.io/game-assets/assets-cc0) | mixed | Licence is per pack. Read each one. |

## Imported files

| File | Source | Licence | Fetched | Used for |
|------|--------|---------|---------|----------|
| `assets/ship/hull_plate.png` | Supplied by the project owner as `playerwarship1.png`. **Origin not stated.** 1797x875. | Owner-supplied | 2026-08-16 | The player ship: hull, compartments, corridors |
| `assets/ship/hull_plate_normal.png` | Derived from the plate by `tools/make_normal_map.py` | follows the plate | 2026-08-16 | 2D lighting relief |
| `assets/ship/enemywarship1.png` | Owner-supplied. **Model-generated** (ChatGPT image generation, prompted from the player plate). 1712x919. | Owner-supplied | 2026-08-17 | The enemy ship in the combat-preview scene |
| `assets/crew/soldier_*.png` (3 sheets) | Baked by `tools/render_soldier.gd` from the Silver Soldier | follows the model | 2026-08-16 | Crew sprite sheets: walk, idle, die x 8 facings |
| `tools/crew_src/silver_soldier_animated.glb` | Sketchfab *Silver Soldier (Animated)* by **Jungle Jim** | **CC-BY 4.0** | 2026-08-16 | The only crew model. Bake source, **excluded from the web export** |

**Origin of the plates — answered, 2026-08-16. Both are model-generated.** The
question stood open through two plates: this repository is public and publishes
to GitHub Pages, and both images have the look of published RPG cartography, so
if either had come from a book, a marketplace or a VTT pack the licence would
have had to permit redistribution. The project owner has confirmed both were
generated. Nothing here is third-party artwork.

**The enemy plate — answered, 2026-08-17. Also model-generated**, from ChatGPT
image generation prompted off the player plate, which is why the two ships share
a shape language and read as belonging to the same fleet. No third-party
artwork, nothing to attribute.

Ask the same question of the next plate. It is cheap to answer at the moment an
image arrives and expensive to reconstruct later.

**A note on how this one got in.** `tools/verify.sh rules` did not object, and it
should have. The provenance check accepted a file if *its folder* was mentioned
anywhere in this document — so once `assets/ship` appeared, anything dropped
beside the existing plates counted as recorded. It now matches on filename, with
globs in this table (`assets/crew/soldier_*.png`) honoured as globs. A rule with
a hole that size is worth roughly nothing, which is the general lesson.

**It is under the resolution minimum.** The spec below asks for 2048 px on the
long axis and this plate is 1797. Nothing is broken by that — the ship still
fills the panel at the sizes the game runs at — but a larger window will reach
the plate's limit sooner than the spec intends, so a higher-resolution version
is worth asking for if one exists.

Both plates so far were owner-supplied. The prompt kept below is the spec any
commissioned replacement should be written against; the first plate was
generated from it, describing shape language only and naming no property.

## Attribution — required

Everything above was CC0 until 2026-08-16. The modular crew bodies are **CC-BY**,
which means credit is a licence condition rather than a courtesy. Any build that
ships those models must carry this, and so must any successor asset taken from
Sketchfab or OpenGameArt under the same terms.

```
Silver Soldier (Animated) — Jungle Jim (CC-BY 4.0)
  https://sketchfab.com — supplied by the project owner
```

That is the whole list. The wolkoed modular bodies were removed on 2026-08-17
along with the Kenney UI borders — neither was wired up, and both are in git
history if wanted. **There is currently no UI art in the project at all.**

## The Silver Soldier — what is in it, and what had to be authored

**It is the crew, as of 2026-08-16.** The Kenney models and their 24 sheets are
gone; every crew member including TOCK uses this one figure, separated by class
colour. `assets/crew/` now holds three sheets totalling about 650 KB.

**The rig is excellent. The animation is not a walk.** Both were measured rather
than assumed:

| | |
|---|---|
| Rig | 211 bones, Character Creator naming (`CC_Base_L_Thigh_00`, `CC_Base_R_Calf_024`) |
| Triangles | 261,035 |
| Animation | one clip, `FBXExportClip_0`, 12.72 s, 430 channels |

The clip contains three bursts of motion — 0.3-2.1 s, 5.6-6.8 s and
10.7-12.6 s — with long holds between them. The two thighs peak **0.08 s
apart**; a walk alternates them by half a stride. Whole-body pose
autocorrelation finds no repetition anywhere. He raises a rifle, aims it, and
lowers it. **His feet never leave the floor.**

So `tools/render_soldier.gd` authors the walk on his own skeleton: thigh swing,
one-way knee bend, ankle counter-rotation, a small two-handed arm swing, torso
roll and a bob twice per stride. The carry pose is sampled from his own clip so
he keeps hold of the rifle. `die` is an authored collapse; `idle` is the carry
pose with a breath on it.

**The trap that cost the most time here:** Character Creator bones do not share
an axis convention, so "rotate about local X" swings one leg forward and the
other sideways. The renderer converts a known world axis into each bone's local
frame instead — see `_swing()`.

**Two numbers that decide how this is wired.** The baked sheet measures 0.068
mean saturation, near-neutral, which is why a class tint lands as hue instead of
mud. But mean brightness is 49, dark enough that a plain multiply tint only
makes it darker — so `ui/ship_view.gd` lifts as well as tints
(`CLASS_TINT_LIFT`).

**The source is 42 MB and must never ship.** `export_presets.cfg` excludes
`tools/crew_src/*`; the web build carries only the baked PNGs. Check that filter
survives if the presets are ever regenerated.

## Crew models — what was measured, 2026-08-16

Two candidate packs were assessed to replace the Kenney crew, which the owner
finds too cartoonish. Both were judged on what the render pipeline actually
needs, not on how they look in a product shot.

**Both assessments below were made at the old 62° camera.** The camera is now
80°, which does not change either verdict — it makes the first one stronger,
since the gap between a shallow isometric sprite sheet and our view is now
wider still.

**Rejected: "400 items + base human male/orc/skeleton" (Skyzor, CC-BY 4.0).**
Not 3D — pre-rendered 2D sprites from *Siege of Avalon*, an isometric RPG. Eight
directions and eight animations, which matches our sheet layout exactly, and
none of that helps: **the camera angle is baked in**. Our crew are rendered
looking down at 80 degrees to sit on a top-down ship; those sprites were shot
from a much shallower isometric view and cannot be re-angled. The author also
notes hard alpha edges, which fray when scaled to the ~66 px crew are drawn at.

**Imported but not wired up: "Modular 3D male/female" (wolkoed, CC-BY 4.0).**
Measured directly from the FBX rather than from the description:

| | |
|---|---|
| Rig | **yes** — 54-bone humanoid, Mixamo bone names (`LeftUpLeg`, `RightToeBase`, `LeftHandThumb1`) |
| Animation clips | **none.** Zero AnimationStack, AnimationLayer and AnimationCurve records |
| Body texture | **none.** Only `Armor_d/m/n` ship; the pack says so |
| Mesh parts | 12 each — body, three cut-down bodies for wearing armour over, four armours, two boots, two bracers, plus hair on the female |

Two blockers, both needing something the pack does not contain. Rendered at the
game's own camera (`tools/preview_models.gd`) they come out as **white
untextured figures frozen in a T-pose**, and a T-pose seen from overhead is a
starfish, not a person.

**The finding that matters beyond this pack.** Side by side at true game scale,
the realistic bodies read *worse* than the Kenney ones — thin, pale, and small
in frame. Kenney's exaggerated proportions are not naivety, they are what makes
a figure legible at 66 px from overhead. **"Less cartoonish" and "readable at
crew size" pull against each other**, and the way to win both is bulk that is
*earned*: armour, a pack, a helmet — a silhouette that is wide because the
character is wearing something, not because the artist stretched it. That is the
test any replacement should be held to.

Because the rig is already Mixamo-named, Mixamo animations retarget onto it with
no bone mapping at all. That is the cheapest route to making these usable, and
it needs a browser upload, so it is the owner's step rather than an agent's.

## Ship plate spec — what the renderer needs from a ship image

A **ship plate** is one image containing the whole ship, hull *and* interior
compartments, viewed from directly overhead with the roof removed. It is the
art. The renderer draws no hull, no walls and no floors on top of it — only
state: selection, crew, doors, fire, damage, targeting, route.

Room shapes are traced from the plate once, by hand, into `ship_layout.json` as
polygons in plate coordinates. This is what FTL's `layout.txt` does and what its
Superluminal editor exists to author.

**Only one plate is generated per ship, so the plate has to serve both jobs at
once.** A second render as a flat-colour room mask would make tracing exact and
automatic, but image models do not reproduce the same ship twice, so a mask
plate would not line up with the art plate. Instead the *art* carries the
boundary information: every compartment is separated by a clearly visible
bulkhead wall, which is both realistic and traceable.

Deriving rooms from a tinted overlay was tried and does not work. In the
reference render the room tints sat 10–20 RGB apart and overlapped the bare
hull — shield room `(63,61,65)` against bare hull `(52,47,41)`. Not separable.

### Hard requirements

| | |
|---|---|
| Projection | strict orthographic top-down, no perspective, no tilt |
| Background | uniform flat black, no gradient, no vignette, no stars, no glow spill |
| Text | none anywhere — no labels, numbers, logos or watermarks |
| Room fills | none; floors are bare metal, no colour tints |
| Boundaries | every compartment separated by a visibly lighter bulkhead band, unbroken except at doorways |
| Contrast | compartment floors *darker* than the bulkhead walls |
| Lighting | one overhead source, even across the ship — code-drawn light must not fight baked side-light |
| Contents | no crew, no fire, no damage; those are drawn at runtime |
| Resolution | 2048 px or more on the long axis |

Save the plate as a **direct PNG download**. Plates arriving inside an exported
PDF are re-encoded and lose resolution.

### The generation prompt

Kept verbatim so a replacement plate can be commissioned against the same
description. Room order is bow to stern.

```
Top-down orthographic cutaway of a small military freighter, seen from directly
above with the roof removed. Grimdark science fiction: heavy worn steel plating,
low saturation, greys and browns, rust streaks, scorch marks, riveted armour.
Utilitarian and military rather than sleek — a working warship repaired badly
many times.

The interior is visible as seven compartments, bow to stern:

- PILOT DECK at the bow behind the forward canopy — the smallest compartment,
  consoles and seats facing forward
- MEDBAY — small, bunks and medical equipment
- SHIELD ROOM — a large emitter housing dominating the space
- WEAPONS / TURRET ROOM — amidships, the largest of the mid compartments,
  ammunition racks and turret mounts
- REACTOR — glowing core behind heavy shielding
- ENGINE ROOM — aft, machinery and thrust structure
- CARGO BAY at the stern end — the largest compartment, mostly open deck with
  crates lashed down

Compartments must be clearly different sizes and non-rectangular — irregular
shapes that follow the hull.

Every compartment is separated by a clearly visible bulkhead wall, drawn as a
distinctly lighter metal band roughly 10 pixels thick, unbroken except at
doorways. Room boundaries must be unambiguous. Visible doorways where
compartments connect.

Compartment floors are darker than the bulkhead walls. Interior detail is
restrained and readable, not visual noise. Hull exterior detail is denser than
the interiors: turrets, antennae, armour plating, hatches, greebles.

No text, no labels, no numbers, no logos, no watermarks. No coloured room fills
or tints — floors are bare metal. No people or crew figures. No fire, damage or
smoke. Engine glow confined to the thruster bells at the stern.

Uniform flat black background, no gradient, no vignette, no stars, no glow
spilling onto the background. Strict orthographic top-down, no perspective. One
light source directly overhead, even across the whole ship, no dramatic side
lighting.

Ship fills the frame horizontally with a small even margin. Long axis 2048
pixels or more.
```

## Where assets go

See `assets/README.md` — that file is the one the project owner reads, and it is
kept short on purpose. In brief: `assets/ship`, `assets/crew`, `assets/ui`,
`assets/audio` for anything the game loads; `tools/crew_src/` for 3D render
sources, which are build inputs and should not ship in the web export.

Prose, story, crew biographies and mission text live in `world/`, not here.

**Note on the Kenney UI borders.** They are filed and licensed but not yet used.
They are fantasy-styled: rope, wood and scroll edges. On a grimdark hull they
will need recolouring at minimum, and a sci-fi kit would be a better buy. They
are in the repository so the 9-slice mechanics can be built against something
real, and swapped later.

## Rendering our own sprites — this is built now

Kenney *Mini Characters* 1.0 (CC0, created 17-07-2024) is a pack of 3D models,
not a sprite sheet, and that is an advantage. 3D source means sprites can be
rendered at any angle, size and number of facings instead of being limited to
whatever a sheet happens to contain.

**This section described the pipeline for two sessions before anyone ran it.**
In the meantime crew were generated from pixel loops in GDScript — two ellipses
and a highlight — and looked like it. The project owner's description was
"polished dots", which was accurate, and the fix was not more parameters. A
person is not a shape derivable from two radii.

Two steps, both re-runnable:

```
xvfb-run -a godot --script res://tools/render_crew.gd   # 8 models x 3 clips
tools/grim_sprites.py assets/crew/*.png                 # into the ship palette
```

**The models are rigged.** They ship with `walk`, `idle`, `die`, `sprint`,
`holding-right`, `interact-right`, `emote-yes` and about twenty more. This was
worth checking before faking anything: an earlier version rendered one static
pose per facing and applied a sine bob to it in `ShipView` and called that a
walk. `walk`, `idle` and `die` are rendered now; the rest are there when the
mechanics that need them exist.

Output is one sheet per model per clip — **columns are frames, rows are the
eight facings** — so a `Sprite2D` picks a cell with `hframes`/`vframes`/`frame`.
`CLIP_FRAMES` in `ui/ship_view.gd` must match `CLIPS` in the render script, or
the sheet is sliced wrongly and crew animate through their neighbours' frames.

`render_crew.gd` builds a `SubViewport`, an orthographic `Camera3D` and two
`DirectionalLight3D`s in code. Two details
that are not obvious and cost a re-render each:

- The camera looks down at **80°** — near-overhead, changed from 62° on
  2026-08-17. See "The camera angle" below; the old entry here argued for 62 on
  reasoning that turned out to be untested.
- `look_at()` fails silently on a node that is not yet in the tree. Called
  before `add_child` it leaves the camera unrotated, pointing at the horizon.
  Use `look_at_from_position()` or add the node first. At **exactly 90°** it
  fails a second way: the view direction is parallel to `Vector3.UP`, there is
  no way to resolve the roll, and the camera is left unrotated again. `_aim()`
  swaps the up vector for `Vector3.FORWARD` past 89.9°.

`grim_sprites.py` desaturates to 16% and darkens to 62%. Kenney's palette is
bright pastel and reads as toys on a worn steel hull. Near-neutral output also
means the per-class tint applied at runtime lands cleanly instead of flooding
the whole figure with one colour.

The figures sit slightly low in their 128 px cell — y 22..113 — so `ShipView`
offsets the sprite by -3.5 px. Without that the crew stand below the point the
simulation says they occupy, and markers drawn at that point land on their heads.
**Do not hand-tune this figure.** `--mode bake` measures it off the sheets it has
just written and prints the value to paste in; it moves whenever the camera does.

## The camera angle — 80°, changed from 62° on 2026-08-17

The owner's observation, and it is correct: our crew were being seen from the
side while the ship was being seen from above, and the reference games do not do
that. In Void War you see helmet, shoulders, and a bit of arm and leg when
someone is moving. That is a much steeper camera than 62°.

**The old reasoning was never tested.** It said a pure overhead view of a human
"is a head and a pair of shoulders, which is the same blob the drawn version
produced". Shot properly — `--mode angles --cell 190`, five pitches from 62 to
90 side by side — that is false. The figure stays legible all the way to 90,
because this model wears a helmet and carries a rifle, and those two things give
it both a silhouette and a facing. **Nothing became a blob at any angle.** The
belief survived because nobody had rendered the comparison; `--mode angles`
exists so the next person does not have to take anyone's word for it either.

So the pitch is a taste decision, not a legibility one, and 80° is the owner's
to move. What is *not* taste is that 62° reads as a side-on figure standing on a
top-down ship.

### What moving the camera broke, and why

Raising the pitch is not a one-constant change, because it changes which
movements survive projection. A world displacement `(dx, dy, dz)` lands on
screen at `(dx, dy·cos p − dz·sin p)`. At 80° that is **sideways 1.00, forwards
0.98, upwards 0.17**.

Everything vertical is therefore worthless from overhead, and the old walk was
mostly vertical: knee lift, torso bob. Worse, **the torso hides the legs from
above**, so a stride is invisible unless the feet swing clear of the body's own
outline. The re-authored walk in `tools/render_soldier.gd` is built from what
the camera keeps:

| Cue | Why it reads from 80° |
|---|---|
| Hip / shoulder counter-rotation | pure yaw — invisible side-on, and the strongest walking cue from above |
| Leg splay on the forward swing | puts the swinging foot outside the torso silhouette so the stride is visible at all |
| Arm spread | carries the elbows past the shoulder line |
| Lateral body sway | the one whole-body movement kept at full value |
| Knee bend, torso bob | kept small; both are mostly vertical and nearly free to discard |

The `die` clip is the one thing the new camera flatters. A fall is mostly
downwards, which an overhead camera discards — so it now twists as it goes and
lands on its side. Face down from above is a backpack.

**This corrects the note in "Things that have already cost time" about the walk
being tuned side-on at 18° and foreshortening at 62°.** The direction of that
claim was wrong: fore-and-aft leg swing is *more* visible as the camera rises,
not less (`sin 18° = 0.31`, `sin 62° = 0.88`). What foreshortens with height is
everything *vertical*. The conclusion it led to — tune the walk in the view the
game actually uses — was right anyway, so `--mode preview` now shoots at
`CAMERA_PITCH` instead of dropping to 18°.

Framing took three renders. The camera's aim point is what moves the figure in
frame, and it moves it the opposite way to the intuition: aiming *higher* pushes
the body *down*. Feet clipped off the bottom of the cell twice before that
registered.
