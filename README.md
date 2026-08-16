# Cowboys and Pirates

A real-time-with-pause roguelike in the Void War lineage. Godot 4.7, GDScript.

Sol, 2100. No aliens, no faster-than-light, no time travel — a gold rush in its
second decade, run by four corporations that own movement, breathing, dying and
digging. You are a smuggler with a small ship and six people who depend on you.

The design goal is one sentence: **losing a crew member has to cost you
something.**

## Play it

**In a browser** — pushes to `main` or `claude/**` publish to GitHub Pages via
`.github/workflows/web.yml`. Nothing to install.

**On your own machine** — download [Godot 4.7 stable](https://godotengine.org/download),
a single binary with no installer, then open `project.godot` and press **F5**.
On macOS the first launch needs right-click → Open, or Gatekeeper refuses it.
There is nothing to import and no dependencies: every asset in this project is
a coloured rectangle drawn at runtime.

Both are the same build. The web export is an additional target, not a fork —
Godot exports Windows, macOS, Linux and Web from this one project, which is
what keeps a Steam release available later.

## Working on it

```bash
tools/setup_godot.sh          # fetches the pinned Godot 4.7 into .godot-bin/
tools/verify.sh               # both verify commands; green before any commit
tools/build_web.sh --serve    # web export on http://127.0.0.1:8099
```

## Where to look

Start with **`CLAUDE.md`** — the working agreement, the Godot 4 gotchas, and the
verify contract. Then **`SLICE.md`**: the current slice is the only thing being
built. Then **`BUILD_PLAN.md`**, which records how the four places v0.1 and v0.2
contradicted each other were settled.

| Document | What it is |
|----------|------------|
| `CLAUDE.md` | Working agreement. Read first. |
| `SLICE.md` | The v0.1 build order. Current slice at the top. |
| `BUILD_PLAN.md` | Build phases, and the settled v0.1 → v0.2 deltas. |
| `ARCHITECTURE.md` | How `sim/` and `ui/` divide, and why. |
| `GAME_SPEC.md` | The combat loop. Authoritative. Nothing built yet. |
| `GAME_SPEC.md` | The crew layer. Authoritative for v0.2. Not started. |
| `SETTING.md` | Sol 2100: factions, geography, and the do-not-copy boundaries. |
| `VOICE_AND_EVENTS.md` | Narrative and audio design. v0.4 — only §6 is built now. |

## Status

Slice 0 is the current target: one playable combat. The tree holds the specs,
the boot scaffold (`main.tscn` + `main.gd`, prints `BOOT OK`), and the
verification harness. No game code yet.

`tools/verify.sh` is green, and its data-contract check is verified to fail on
broken input.
