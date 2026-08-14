# GAME_SPEC v0.2 — "The Crew Layer"

## 0. Thesis

v0.1 proved the loop works. v0.2 makes **the crew the point**.

The named criticism of Void War is that crew have no progression and therefore
feel like ammunition. A Metacritic reviewer put it plainly: individual characters
lack the specific skills FTL gave them. Our pitch is the inverse: six people,
each of whom you would be upset to lose. Every mechanic here exists to make crew
death *cost* something.

If at the end of v0.2 you lose a crew member and feel nothing, v0.2 failed,
regardless of how many features shipped.

**Structure is unchanged from v0.1:** the same linear list of encounters with a
jump screen between them. Map, stations, boarding, hacking, currency and the
power-armour quest are all v0.3. This version changes who is on the ship, not
where the ship goes.

## 1. Convention: PLAY-GATED

Anything marked **[PLAY-GATED]** is a placeholder that must be replaced after
playing. Do not treat it as a decision. Build it as written, expose it in
`data/*.json`, move on.

## 2. Goals

- MUST: a Clone Bay, and a real cost for using it
- MUST: a class system, structurally complete but mechanically light
- MUST: Downed as a state between alive and dead
- MUST: per-system crew XP that cloning destroys
- MUST: fire — a threat power cannot solve
- MUST: a combat log — no state change may be visual-only
- MUST: encounter count raised from 5 to 6, still hardcoded and linear

## 3. Non-Goals (DO NOT BUILD — v0.3+)

- **No sector map, no node types, no stations, no shops**
- **No second currency** — v0.2 is scrap-only because there is nowhere to spend
  anything else. Sats arrive with stations in v0.3.
- **No boarding, no hacking, no ground or station assaults**
- **No power-armour components** — the quest starts in v0.3
- No crew recruitment, no upkeep, no Heat
- No hull breaches, no oxygen, no equipment slots
- No meta-progression, no unlockable ships, no difficulty tiers
- No art, no audio, no save/load
- Crew still teleport. Pathfinding is not in scope, again.

## 4. Classes

Six classes. **Structure now, tuning later** — each gets one small bonus in
v0.2, and the data format is built to carry far more.

| Class | Role | v0.2 bonus | Real payoff |
|-------|------|-----------|-------------|
| **Commander** | The captain. One per ship, cannot be replaced. | While alive, all other crew repair 25% faster | v0.3 — command abilities |
| **Soldier** | Fighter. Nothing to fight yet. | +25% firefighting speed, takes 50% fire damage | v0.3 — boarding |
| **Engineer** | Keeps it flying. | Repairs 2 damage points per interval instead of 1 | v0.4 — system overcharge |
| **Pilot** | Mans Engines for evasion. | +5% flat evasion while manning Engines | v0.3 — manoeuvres |
| **Medic** | Mans the medical slot. | Medbay heals 50% faster while manned | v0.3 — field triage |
| **Synthetic** | Combat frame with an intrusion suite. | Immune to bleed-out (see below) | v0.3 — hacking and boarding |

**Note for later:** more classes may be added — the format supports it — but the
crew stays small deliberately. Twelve people stop being people. Add depth *per
class* before adding classes.

### The Synthetic is the proof of the data-driven design
The Synthetic is a sixth class added after the format was written. **It must be
implementable in `classes.json` and `crew.json` with zero GDScript changes.**
If it cannot be, the format is wrong and the format gets fixed, not special-cased.

### Synthetic rules
- Does not go DOWNED. At 0 HP it goes **DISABLED**: inert, does not bleed out,
  does not die on a timer.
- **The Medbay cannot repair it. The Clone Bay cannot clone it.** Only a crew
  member with `can_repair_synthetics` (the Engineer) can bring it back, by
  standing in its room for 15s **[PLAY-GATED]**.
- If the ship is destroyed while it is DISABLED, it is lost like anyone else.
- Takes normal fire damage. It is a machine, not a fireproof one.

This is the best interaction in v0.2: the Synthetic is the one crew member whose
survival is completely unaffected by your Medbay/Clone Bay choice, and completely
dependent on one specific other person staying alive.

### The Soldier problem (deliberate, do not fix)
With no boarding in v0.2 the Soldier is the weakest class. Expected and correct:
the bonus is a placeholder until v0.3 gives them a war. Do not invent
compensating mechanics.

### The Medic / Clone Bay tension (deliberate, keep)
A Medic on a ship that installed a Clone Bay has almost nothing to do. That is a
real cost of the choice and one of the better things in this version. Do not
soften it.

### Data format
`data/classes.json` defines classes. `data/crew.json` assigns class and name.
**No class logic may be hardcoded in GDScript.** Adding a seventh class must
require editing JSON only.

## 5. The crew

Six crew, one per class. See `data/crew.json`.

| Slot | Class | Name |
|------|-------|------|
| 1 | Commander | Smith — gives his real name only to the core crew |
| 2 | Soldier | Bram Ostrow |
| 3 | Engineer | Juno Vela |
| 4 | Pilot | Dex Mazur |
| 5 | Medic | Sunny Kwon |
| 6 | Synthetic | TOCK (designation TK-04) |

### Crew states
`ACTIVE` → `DOWNED` (0 HP, cannot act, bleeds out in 30s **[PLAY-GATED]** unless
reached by the Medbay) → `DEAD`.
Synthetics use `ACTIVE` → `DISABLED` → `DESTROYED` and skip the timer.

### Crew XP
- 1 XP per 5s manning an undamaged system.
- Level 1 at 20 XP (+20% manning bonus), Level 2 at 60 XP (+35%) **[PLAY-GATED]**.
- XP is **per system**. A Pilot who has only ever manned Engines is not an expert
  at Weapons. This is what makes a *specific* dead crew member irreplaceable.
- Synthetics gain XP at the same rate but **never lose it** — there is no clone
  to reset. Repairing a Synthetic restores it intact.

## 6. Medbay OR Clone Bay — one slot

The ship has **one** medical slot: a Medbay or a Clone Bay, never both.
No swapping in v0.2 (no stations exist) — dev key `F1` toggles it for testing.

### Medbay (default at run start)
- Heals crew in the room: 4 HP/s per power bar, max 2 power.
- Revives a Downed crew member in the room to 20 HP.
- Does nothing for the dead, and nothing for Synthetics.

### Clone Bay
- On death, the crew member re-materialises after 12s **[PLAY-GATED]** at full HP.
- **The clone loses all XP in every system.** The person returns; the expertise
  does not.
- Cannot heal. Chip damage never goes away mid-combat.
- **If the Clone Bay is offline (damage 3) when someone dies, they are gone
  permanently.**
- Does not work on Synthetics.

The Clone Bay is not a safety net, it is a bet: healing and expertise traded for
a second chance that can itself be shot out from under you.

## 7. Fire

- A hit has a 20% chance **[PLAY-GATED]** to start a fire in the struck room.
- Fire deals 1 damage per 2s to the room's system and 5 HP/s to crew present.
- Fire spreads to an adjacent room every 8s **[PLAY-GATED]** at 30% chance.
- Crew extinguish in 6s **[PLAY-GATED]**, taking damage throughout. While
  firefighting they cannot repair or man.
- Requires a room adjacency list in `data/ship_layout.json`.
- Enemy ships burn too.

## 7a. Combat log — READABILITY IS A MECHANIC

Reviewers' sharpest criticism of Trigon was that combat feels arcade-y rather
than strategic, because it is easy to lose track of a crew member or a damaged
system amid the explosions and damage numbers. We are building the cheap
insurance against that now, while the game is still grey rectangles.

- A scrolling text feed, 6 visible lines, bottom of the HUD, timestamped.
- **Every state change writes a line:** hits landed and taken, shields dropped,
  system damaged or destroyed, fire started or extinguished, crew injured,
  Downed, dead, cloned, Disabled, repaired, level-up.
- Colour-coded by severity: neutral / warning / critical.
- Pause freezes the feed. Unpausing resumes it. Log survives across encounters
  within a run.
- **Hard rule: no visual effect may ever be the only indication that something
  happened.** If it matters, it writes a line. This rule outranks aesthetics
  permanently, including after the art pass.
- **The log emits structured events, never pre-formatted strings.** `sim/` pushes
  objects with `type`, `severity`, `subjects` and `values`; `ui/` formats them
  into text. See `VOICE_AND_EVENTS.md` §6 — TOCK's voice system subscribes to
  this same stream in v0.4, and if the log emits strings, every logging call
  site has to be rewritten then. This costs nothing now.
- Loud events get loud lines. A clone returning at zero XP is a critical-colour
  line reading e.g. `KWON restored from pattern. All training lost.`

## 8. Encounters

Hardcoded linear list, jump screen between each. Raised from 5 to **6 combats**,
all fights, no events, so fire and crew death have room to play out.

Enemies live in `data/enemies.json`, six templates, difficulty rising by index.
Jump screen keeps the v0.1 options: repair 15 scrap → +5 hull,
upgrade 30 scrap → +1 reactor power. **Scrap only. No second currency in v0.2.**

## 9. Balance safeguards

1. **Death spiral.** If sim runs show >20% of losses in the first two encounters,
   fire chance is too high.
2. **Clone Bay dominance.** If the Clone Bay is strictly better, the choice is
   fake. Report win rates for both loadouts separately.
3. **Synthetic dominance.** A crew member immune to bleed-out may simply be
   better. Report win rate with TOCK alive at end of run versus destroyed.

## 10. Acceptance criteria

1. Both verify commands stay green (see CLAUDE.md).
2. A human can complete a full 6-combat run.
3. A crew member can go Downed, be revived, and later die permanently.
4. Cloning visibly resets that crew member's XP display to zero **and writes a
   critical-colour log line.**
5. A fire can destroy a system if ignored, and be extinguished if answered.
6. TOCK can be Disabled and repaired by Juno Vela, and by nobody else.
7. Adding a seventh class requires editing JSON only — no GDScript changes.
   Test this: add a throwaway class, confirm it loads, delete it.
8. Nothing in the game is communicated by colour or animation alone.
9. `sim_runner.gd` runs 500 games with zero crashes and reports: overall win
   rate, win rate by medical loadout, win rate by TOCK survival, average
   encounter of death, and % of losses in the first two encounters.
10. Target win rate 15–35% **[PLAY-GATED]**. Report; do not silently retune.
