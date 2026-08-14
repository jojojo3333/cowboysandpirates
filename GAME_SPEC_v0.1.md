# GAME_SPEC v0.1 — "The Loop"

> ## ⚠ THIS DOCUMENT IS A RECONSTRUCTION
>
> `GAME_SPEC_v0.2.md` opens with *"v0.1 proved the loop works"* and refers back
> to v0.1 in §0, §3 and §8 — but no v0.1 spec and no v0.1 code exist in this
> repository. This file was reconstructed from what v0.2 assumes, so that v0.2
> has something to build on.
>
> **Every line here is inference until confirmed.** Two markers are used:
>
> - **`[INFERRED]`** — a structural claim derived from v0.2. If one of these is
>   wrong, v0.2 is built on the wrong foundation. **These need a human read.**
> - **`[PLAY-GATED]`** — a number nobody has decided yet. Same meaning as in
>   v0.2 §1: build as written, expose in `data/`, move on.
>
> If real v0.1 code exists elsewhere, push it and delete this file. Reconciling
> it against this reconstruction is a faster read than writing the spec fresh.

---

## 0. Thesis

One ship, one enemy at a time, six fights in a row, and a decision between each.
v0.1 exists to prove that real-time-with-pause combat over a powered ship is fun
before anyone builds a crew layer on top of it.

**Crew in v0.1 are interchangeable bodies.** They man, they repair, they die and
it costs nothing but a body. Making that loss hurt is the entire job of v0.2 —
so v0.1 deliberately does not attempt it.

## 1. Non-goals

Everything in `GAME_SPEC_v0.2 §3`, plus the whole of v0.2 itself: no classes, no
crew XP, no Medbay or Clone Bay, no fire, no combat log. Crew teleport between
rooms; pathfinding is not in scope.

## 2. The ship

**[INFERRED]** Four rooms, one system each, plus a reactor that is a number
rather than a room.

| Room | System | Effect |
|------|--------|--------|
| Weapons | Weapons | Powers weapon slots. Unpowered weapons do not charge. |
| Shields | Shields | Each 2 power = 1 shield layer. |
| Engines | Engines | Converts power into evasion %. |
| Medical | — | **Empty in v0.1.** Exists in the layout so v0.2 §6 can fill it. |

`data/ship_layout.json` defines rooms, their system, and an adjacency list.
**[INFERRED]** Adjacency is unused in v0.1 — it exists because v0.2 §7 fire
spread requires it, and retrofitting the layout file later means touching
every room definition twice.

### Power
- Reactor has a pool of total power bars. Starting pool: **6 [PLAY-GATED]**.
- The player assigns bars to systems. Assigned power cannot exceed the pool.
- **A damaged system loses capacity.** A system with `damage` ≥ its power level
  cannot hold that much power; bars are dropped and must be reassigned.
- At `damage` 3 a system is **destroyed**: no power, no function, until repaired.

### Hull
- Starting hull: **30 [PLAY-GATED]**. At 0 the run ends.
- Hull damage is permanent within a run except via the jump-screen repair.

## 3. Combat

Real-time, pausable at any moment, and **fully resolvable while paused** —
orders given under pause take effect on unpause. Pause is not a menu; it is how
the game is played.

### The tick
**[INFERRED]** A fixed simulation step (**20 Hz [PLAY-GATED]**) advances, in order:

1. Weapon charge on both ships
2. Weapon fire and hit resolution
3. Shield regeneration
4. Crew action progress (manning XP is v0.2; repair here)
5. Death and destruction checks

Fixed-step rather than frame-delta, because `sim/sim_runner.gd` must run 500
games far faster than real time and get identical results.

### Weapons
**[INFERRED]** Weapons are charge-and-fire, not hitscan or projectile-travel.

- Each weapon has a charge time, a damage value, and a shield-piercing value.
- A weapon charges only while the Weapons system has power for it.
- On fire, the player has selected a target room. **[PLAY-GATED]** If no room is
  selected, it targets a random powered room.

### Hit resolution
1. Roll evasion. On success: miss, no damage. Log a miss.
2. Subtract shield layers. Each layer absorbs 1 damage and is stripped.
3. Remaining damage hits hull, and the same amount damages the struck room's
   system.

**[INFERRED]** Damage hits hull *and* system, rather than one or the other.
This is what makes targeting a choice — shoot Shields to open them up, shoot
hull to win — and v0.2 §7's "a hit has a 20% chance to start a fire in the
struck room" assumes a struck room exists.

### Shields
- `floor(power / 2)` layers. **[PLAY-GATED]**
- One layer regenerates every **4s [PLAY-GATED]**, from zero upward.
- Layers regenerate during combat only.

### Evasion
- `engine_power × 5%`, capped at **60% [PLAY-GATED]**.
- **[INFERRED]** Manning Engines adds a bonus. v0.2 §4 gives the Pilot class
  "+5% flat evasion **while manning Engines**", which only parses if manning
  already did something in v0.1.

### Crew
- HP: **100 [PLAY-GATED]**. No classes, no XP, no states beyond alive/dead.
- Crew occupy a room and are moved by clicking. Movement is instant.
- **Manning:** a crew member in a room with a system improves it by
  **+15% [PLAY-GATED]**. One manner per system.
- **Repair:** a crew member in a damaged room removes 1 damage point per
  **2s [PLAY-GATED]**. While repairing they are not manning.
- Crew die at 0 HP. **[INFERRED]** In v0.1 death is immediate — the DOWNED state
  and the bleed-out timer are introduced in v0.2 §5.

### The enemy
- Same ship model, same rules: hull, power, shields, evasion, systems, crew.
- **[PLAY-GATED]** Enemy AI: target the highest-power enemy system that is not
  already destroyed; re-target on destruction. Enemy crew repair the most
  damaged room.
- Enemies are templates in `data/enemies.json`, difficulty rising by index.

### Ending an encounter
- Enemy hull 0 → victory, award scrap.
- Player hull 0 → run over.
- **[PLAY-GATED]** Scrap reward: `15 + 5 × encounter_index`.

## 4. Structure

**Five hardcoded encounters, linear, no branching.** No map, no node types, no
choice of route. v0.2 raises this to six; v0.3 replaces it with a map.

Between encounters, a jump screen with exactly two options, both repeatable
while scrap lasts:

- **Repair:** 15 scrap → +5 hull
- **Upgrade:** 30 scrap → +1 reactor power

These two numbers are quoted verbatim in `GAME_SPEC_v0.2 §8` and are the one
part of this document that is **not** inferred.

Surviving all five encounters wins the run.

## 5. Acceptance criteria

1. `tools/verify.sh` is green, both commands.
2. A human can complete a full 5-encounter run.
3. Power can be assigned, a system can be destroyed by damage, and the assigned
   bars are dropped when its capacity falls.
4. A crew member can man a system, be reassigned to repair, and die.
5. Shields strip and regenerate; evasion produces misses.
6. `sim/sim_runner.gd` runs 500 games with zero crashes and reports win rate and
   average encounter of death.
7. **A run seed reproduces a run exactly.** Same seed, same outcome, every time.
8. The simulation runs headless with no scene tree. `sim/` imports nothing from
   `ui/`.

## 6. Open questions for the human

Answer these before Phase 1 builds on them — they are the inferences that would
be expensive to reverse:

1. **Four rooms, or more?** Four is the minimum that `crew.json` starting rooms
   imply. A larger ship makes fire spread (v0.2 §7) more interesting and makes
   targeting a real decision. Recommend six: add Reactor and Cargo as rooms that
   can burn but hold no combat system.
2. **How many weapons does the starting ship carry?** Two is the FTL default and
   makes the Weapons power decision meaningful. Currently unspecified anywhere.
3. **Does damage hit hull and system, or one or the other?** §3 assumes both.
4. **Is the medical room present-but-empty in v0.1, or added in v0.2?**
   Present-but-empty means the layout file never changes shape.
