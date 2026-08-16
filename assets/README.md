# assets/ — the art drop

**You put things in. I wire them up.** Everything the running game loads lives
here. If you buy or generate art, drop it in the right folder below and tell me
it is there; I will import it, record it in `ASSETS.md` and connect it.

| Folder | What goes in it |
|--------|-----------------|
| `ship/` | Ship plates — one image per ship, hull and interior together, seen from directly overhead. `ASSETS.md` has the full spec and the generation prompt. Enemy ships go here too. |
| `crew/` | Crew sprite sheets. Currently rendered from 3D models by `tools/render_crew.gd`; bought sheets go here as well. |
| `ui/` | Panels, borders, icons, HUD chrome, fonts. |
| `audio/` | Music and sound effects. Nothing here yet. |

**One thing I need from you with every drop: where it came from.** A licence
file, a shop link, or "I generated this" — one line is enough. It goes into
`ASSETS.md` next to the file. This repository is public and publishes to the
web, so an asset with no recorded origin is a problem waiting to happen, not a
formality.

3D models used to *make* sprites are not assets — they are build inputs and live
in `tools/crew_src/`, because they should not ship in the web export.
