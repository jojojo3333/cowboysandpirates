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
