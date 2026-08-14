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
built. Then **`BUILD_PLAN.md`**, which covers the three places v0.1 and v0.2
contradict each other.

| Document | What it is |
|----------|------------|
| `CLAUDE.md` | Working agreement. Read first. |
| `SLICE.md` | The v0.1 build order. Current slice at the top. |
| `BUILD_PLAN.md` | Build phases, and the v0.1 → v0.2 deltas that need decisions. |
| `ARCHITECTURE.md` | How `sim/` and `ui/` divide, and why. |
| `GAME_SPEC_v0.1.md` | The combat loop. Authoritative. Nothing built yet. |
| `GAME_SPEC_v0.2.md` | The crew layer. Authoritative for v0.2. Not started. |
| `SETTING.md` | Sol 2100: factions, geography, and the do-not-copy boundaries. |
| `VOICE_AND_EVENTS.md` | Narrative and audio design. v0.4 — only §6 is built now. |

## Status

Pre-v0.1, slice 0 not started. Specification and verification harness only —
no game code yet.
`tools/verify.sh` is green and its data-contract check is verified to fail on
broken input.
