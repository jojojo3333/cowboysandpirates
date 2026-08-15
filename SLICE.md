# SLICE.md

**CURRENT SLICE: 0**

Build only the current slice. When it runs and is committed, stop and wait.

**One mission, not a chain.** The immediate target is a single combat that a
human can play start to finish. The encounter chain — five in `GAME_SPEC_v0.1
§5`, six in `GAME_SPEC_v0.2 §8` — is deferred, and its length is an open number
to be decided after the single mission has been played. Both counts in the
specs are superseded until then. Slice 3 stays written as-is because the jump
screen and reward numbers are still what it needs to build; only the count is
open.

---

## Slice 0 — "It's a game" (target: 30 min)

The smallest thing that is genuinely playable. One combat, nothing else.

- Player ship: `hull = 30`. Enemy ship: `hull = 15`, evasion 0%.
- One player weapon: charge 8.0s, 1 damage. Fires automatically when charged
  at the currently selected enemy room.
- Enemy has one weapon: 1 damage every 9.0s, hits a random player room
  (rooms exist as clickable boxes only — no systems behind them yet).
- 4 rooms per ship, drawn as labelled `ColorRect`s. Click an enemy room to
  select it as the target; it highlights.
- `SPACE` toggles pause. The game **starts paused**. A visible "PAUSED"
  label. Weapon charge bars must visibly stop when paused.
- Enemy hull 0 → "VICTORY" screen. Player hull 0 → "DESTROYED" screen.
  Both have a RESTART button.

**Done when:** a human can launch it, unpause, watch bars fill, click a target,
and reach either end screen without touching the console.

## Slice 1 — Power and shields (target: 25 min)

- Reactor with 6 power bars, `+`/`−` buttons per system.
- Systems: Shields, Engines, Weapons (Medbay deferred).
- Shields: 1 layer per 2 power, max 2, recharge 1 layer / 4.0s.
  Each layer absorbs 1 damage.
- Engines: +5% evasion per power bar, max 15%. Applies to incoming shots.
- Second weapon: Burst Laser, 2 power, charge 11.0s, 2 shots × 1 damage.
- Weapons only charge if their power cost is covered.
- Enemy gets 1 shield layer.

## Slice 2 — Crew and system damage (target: 25 min)

- 3 crew: Smith, Vasquez, Okonkwo. HP 100. Assign by clicking crew, then room.
  Crew teleport instantly — no pathfinding.
- Damage that gets through shields: −1 hull AND +1 damage to that room's
  system (0–3, at 3 the system is offline). Crew in the room take 15 damage.
- Crew in a damaged room repair 1 damage point per 4.0s.
- Crew in an undamaged room man it: +10% to that system's effect.
- Crew death at 0 HP. Permanent in v0.1. Must not crash.

**Crew XP is not in this slice.** It was listed here originally, but
`GAME_SPEC_v0.1` does not mention XP and `GAME_SPEC_v0.2 §5` introduces it as
new. XP is the first mechanic that makes a *specific* crew member
irreplaceable, which is what v0.2 is for. v0.1's job is to prove the loop is
fun with interchangeable crew.

## Slice 3 — The run (target: 25 min)

- The 5 hardcoded encounters from the spec, in order.
- Jump screen between encounters: repair 15 scrap → +5 hull,
  upgrade 30 scrap → +1 reactor. Then JUMP.
- The two text events with their choices.
- End screens report jump number, hull, scrap, crew alive.

## Slice 4 — Harness (do last, or in session 2)

- `tools/sim_runner.gd` extending `SceneTree`, random legal play,
  `--runs N`, prints win rate and the seed of any crashing run.
- Target win rate 5–40%. Report the number; do not silently retune.

---

## Deferred to v0.2 (do not build)

Clone Bay · boarding · equipment slots · commander abilities · Medbay ·
branching sector map · fire · breaches · oxygen · shops · procedural events ·
save/load · art · audio
