# Cowboys and Pirates

A real-time-with-pause roguelike in the FTL lineage. Godot 4.7, GDScript.

Sol, 2100. No aliens, no faster-than-light, no time travel — a gold rush in its
second decade, run by four corporations that own movement, breathing, dying and
digging. You are a smuggler with a small ship and six people who depend on you.

The design goal is one sentence: **losing a crew member has to cost you
something.**

## Getting started

```bash
tools/setup_godot.sh     # fetches the pinned Godot 4.7 into .godot-bin/
tools/verify.sh          # both verify commands; must be green before any commit
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
| `GAME_SPEC_v0.1.md` | The combat loop. Authoritative. Nothing built yet. |
| `GAME_SPEC_v0.2.md` | The crew layer. Authoritative for v0.2. Not started. |
| `SETTING.md` | Sol 2100: factions, geography, and the do-not-copy boundaries. |
| `VOICE_AND_EVENTS.md` | Narrative and audio design. v0.4 — only §6 is built now. |

## Status

Slice 0 is the current target: one playable combat. The tree holds the specs,
the boot scaffold (`main.tscn` + `main.gd`, prints `BOOT OK`), and the
verification harness. No game code yet.

`tools/verify.sh` is green, and its data-contract check is verified to fail on
broken input.
