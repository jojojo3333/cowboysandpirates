# ASSETS.md

Provenance record for every imported file, required by `CLAUDE.md` rule 2.

**Currently: three sprites.** Everything structural — hull, nacelles, rooms,
walls, doors, crew, starfield — is still drawn at runtime in `ui/ship_view.gd`
from rectangles, polygons, lines and the engine's fallback font. The only
imported art is the furniture inside rooms, listed below.

**That split was wrong and this file previously said so in the other direction.**
It claimed the sprite count in a game like this is small and that everything
else is geometry and lighting. Checking how the reference games are actually
built shows the opposite: FTL ships are a hand-drawn `ship_base` PNG plus one
authored PNG per interior room, positioned by a layout file; Void War's hull
detail is authored pixel art by a contract artist. The art comes first and the
data describes the art. Drawing the ship from primitives has a ceiling that more
primitives do not raise. See `SLICE.md`, "Where the ship art has to come from".

## The rule

An imported asset may enter this repository only if it is **CC0** and appears
in the table below. No exceptions, including "just a placeholder we will swap
later" — placeholder art is the normal way unlicensed art ends up shipped.

**Assets extracted from another game are never acceptable**, whatever the
extraction tool makes technically possible and whatever the intended lifespan.
That includes GameMaker `data.win` files, Unity asset bundles and unpacked
`.pck` archives. Those files are the developer's copyrighted artwork; this
repository is public and publishes to GitHub Pages, so adding one is
distribution, and git history keeps it after deletion.

Studying another game to understand *why* something reads well is fine and
encouraged. Copying the file is not. Same principle as `SETTING.md §6`: take
the shape, never the specifics.

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
| `assets/props/bed-single.png` | Kenney, *Space Station Kit* 1.0 — `Previews/bed-single.png` | CC0 1.0 | 2026-08-15 | Medbay beds |
| `assets/props/computer.png` | Kenney, *Space Station Kit* 1.0 — `Previews/computer.png` | CC0 1.0 | 2026-08-15 | Medbay console |
| `assets/props/container.png` | Kenney, *Space Station Kit* 1.0 — `Previews/container.png` | CC0 1.0 | 2026-08-15 | Medbay supply drum |

Licence verified at the source, not at a mirror: *Space Station Kit* 1.0 ships a
`License.txt` reading "Creative Commons Zero, CC0", created 10-04-2024,
distributed by Kenney (www.kenney.nl). Attribution is not required. The pack was
downloaded by the project owner and handed over directly, because this session's
proxy blocks kenney.nl — which is the correct way round: a file pulled from some
mirror cannot have its licence checked where it was published.

**What these files actually are.** The pack is a set of 97 3D models
(`.glb`/`.fbx`/`.obj`) plus a 512×512 colour atlas. It contains no sprite sheet.
The 2D PNGs are 64×64 catalogue thumbnails, one per model, rendered from a fixed
isometric camera — but they carry alpha, so they work as sprites as-is. The
three above are used unmodified.

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

## Rendering our own sprites

Also held locally, not yet imported: Kenney *Mini Characters* 1.0 (CC0, created
17-07-2024, 26 models). Neither pack is a 2D asset pack, and that turns out to
be an advantage rather than a shortfall. 3D source means sprites can be rendered
at any angle, size and number of animation frames instead of being limited to
whatever a sheet happens to contain — so "the pack is missing the frame we
need" stops being possible.

When crew sprites are wanted, the route is a `tools/` script that renders the
models through a `SubViewport` and a `Camera3D` built in code, exactly as
`tools/screenshot.gd` already builds a scene tree at runtime. **No `.tscn` is
created**, so `CLAUDE.md` rule 1 holds. Rendered output lands in `assets/` and
gets its own rows in this table, naming the pack it came from.
