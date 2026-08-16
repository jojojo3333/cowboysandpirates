# GAME_SPEC.md

The design spec, both versions in one file. v0.1 is built; v0.2 is not started.
Where the two disagree about something already built, v0.1 wins — see
`SLICE.md` for what is actually done.

Merged from `GAME_SPEC.md` and `GAME_SPEC.md`, which had grown
overlapping goals, non-goals, determinism and acceptance sections.

---

# v0.1 — the loop works


### 0. Purpose of this version

Prove that the core loop is fun in under 10 minutes of play: **manage power, watch
timers, click things under pressure, survive 5 jumps.**

If it is not fun with grey rectangles, no amount of art will save it.

### 1. Goals

- MUST: one playable run of exactly 5 fixed encounters, start to death-or-victory
- MUST: real-time combat with a working pause (SPACE)
- MUST: power allocation between 4 systems, changeable mid-combat
- MUST: 3 crew that can be assigned to rooms, take damage, and die
- MUST: run under 10 minutes, be losable, and be winnable

### 2. Not in this version

Scope markers, not bans — they exist so v0.1 does not quietly become v0.3. If
something here turns out to be the right next thing, move it and say so.

- No fire, no hull breaches, no oxygen, no boarding, no enemy crew
- ~~No crew pathfinding~~ — superseded. Crew walk room to room through doors.
- No Clone Bay (v0.2, first item)
- No procedural map — the 5 encounters are a hardcoded list
- No shops, no weapon drops, no ship selection, no meta-progression
- No power armor quest, no story, no faction system (v0.3+)
- No save/load
- No settings menu, no main menu — the game starts at encounter 1 on launch

### 3. Presentation

Programmer art only. `ColorRect` + `Label` + `ProgressBar`, built **in code**.
Layout: player ship left half, enemy ship right half, HUD bottom.
Dark background, one accent colour per system. Readable > pretty.

### 4. State model

#### Ship (player)
- `hull: int` — start 30, max 30
- `reactor: int` — start 6 power bars
- `scrap: int` — start 0
- Systems, each: `power_assigned: int`, `damage: int` (0–3), `max_power: int`

| System  | max_power | Effect per power bar |
|---------|-----------|----------------------|
| Shields | 4         | 1 shield layer per 2 power (max 2) |
| Engines | 3         | +5% evasion (max 15%) |
| Weapons | 4         | powers weapon slots (see below) |
| Medbay  | 2         | heals crew in medbay room, 4 HP/s at any power > 0 |

A system with `damage: d` has effective power `min(power_assigned, max_power - d)`.
At `damage: 3` the system is offline.

#### Crew
3 crew, each: `name: String`, `hp: int` (max 100), `room: String`, `alive: bool`.
- Crew in a damaged room repair **1 damage point per 4 seconds**.
- Crew in an undamaged room "man" it: +10% to that system's effect
  (weapons charge 10% faster, shields recharge 10% faster, engines +5% evasion flat).
- Crew take 15 damage when their room is hit. At 0 HP they die permanently in v0.1.
- Names: Smith (captain), Vasquez, Okonkwo. Placeholder, content pass comes later.

#### Weapons
2 slots, both filled at start:
- **Laser Mk1** — 1 power, charge 8.0s, 1 shot, 1 damage
- **Burst Laser** — 2 power, charge 11.0s, 2 shots, 1 damage each

A weapon only charges if its power requirement is met by Weapons system power.
Player clicks an enemy room to set the target; the shot fires automatically when charged.

#### Combat resolution
- Hit chance = `100% - enemy_evasion`
- Each shield layer absorbs 1 damage and is consumed; layers recharge 1 per 4.0s
- Damage that gets through: −1 hull AND +1 damage to the targeted room's system
- Same rules apply to the enemy shooting the player, targeting a random player room

#### Enemy
Single ship per combat: `hull`, `evasion`, `shield_layers`, one weapon with a
fixed cooldown. Enemy picks a random player room each shot. No enemy power management.

### 5. The 5 encounters (hardcoded, in this order)

| # | Type   | Content |
|---|--------|---------|
| 1 | Combat | Scout — hull 15, evasion 5%, 0 shields, weapon 1 dmg / 9.0s |
| 2 | Event  | Distress beacon. Choices: **Board it** (60% +25 scrap, 40% one crew −40 HP) / **Scan first** (+10 scrap) / **Ignore** (nothing) |
| 3 | Combat | Raider — hull 22, evasion 10%, 1 shield layer, weapon 2 dmg / 11.0s |
| 4 | Event  | Derelict hauler. Choices: **Strip it** (+20 scrap, −2 hull) / **Leave** (nothing) |
| 5 | Combat | Enforcer — hull 30, evasion 10%, 1 shield layer, two weapons (1 dmg / 7.0s, 2 dmg / 13.0s) |

Combat rewards: +15 scrap on victory.

#### Between encounters
A jump screen with two buttons, then **JUMP**:
- Repair: 15 scrap → +5 hull (capped at max)
- Upgrade: 30 scrap → +1 reactor power
Both repeatable while scrap allows.

### 6. Win / lose

- **Lose** when `hull <= 0` or all crew dead → screen: "RUN ENDED — Jump N of 5"
- **Win** after encounter 5 → screen: "RUN COMPLETE — hull X, scrap Y, crew alive Z"
- Either screen has a **RESTART** button that resets state. No persistence.

### 7. Controls

- `SPACE` — toggle pause. All simulation time stops; UI stays interactive.
- Click a crew portrait, then click a room → assign crew to room
- Click `+`/`−` on a system → move a reactor power bar in/out
- Click an enemy room → set weapon target
- The game starts **paused** at the beginning of every combat

### 8. Determinism

All randomness goes through one seeded `RandomNumberGenerator` owned by the run.
The seed is printed on screen. No calls to global `randi()` / `randf()` anywhere.
This is what makes the headless sim runner and bug reproduction possible.

### 9. Acceptance criteria

v0.1 is done when all of these are true:

1. `godot --headless --quit` exits with code 0 and no script errors
2. Launching the game shows encounter 1, paused, with all HUD elements visible
3. A human can complete all 5 encounters without touching the console
4. Pause actually stops weapon charge, shield recharge, and repair progress
5. Moving power to Shields visibly changes shield layers within 5 seconds
6. Crew death is possible and does not crash the game
7. `godot --headless --script res://tools/sim_runner.gd -- --runs 200` completes
   with zero crashes and prints a win rate
8. Target win rate for the random-play sim runner: between 5% and 40%.
   Outside that range, report it — do not silently retune the numbers.


---

# v0.2 — the crew are the point


### 0. Thesis

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

### 1. Convention: PLAY-GATED

Anything marked **[PLAY-GATED]** is a placeholder that must be replaced after
playing. Do not treat it as a decision. Build it as written, expose it in
`data/*.json`, move on.

### 2. Goals

- MUST: a Clone Bay, and a real cost for using it
- MUST: a class system, structurally complete but mechanically light
- MUST: Downed as a state between alive and dead
- MUST: per-system crew XP that cloning destroys
- MUST: fire — a threat power cannot solve
- MUST: a combat log — no state change may be visual-only
- MUST: encounter count raised from 5 to 6, still hardcoded and linear

### 3. Not in this version (v0.3+)

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

### 4. Classes

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

#### The Synthetic is the proof of the data-driven design
The Synthetic is a sixth class added after the format was written. **It must be
implementable in `classes.json` and `crew.json` with zero GDScript changes.**
If it cannot be, the format is wrong and the format gets fixed, not special-cased.

#### Synthetic rules
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

#### The Soldier problem (deliberate, do not fix)
With no boarding in v0.2 the Soldier is the weakest class. Expected and correct:
the bonus is a placeholder until v0.3 gives them a war. Do not invent
compensating mechanics.

#### The Medic / Clone Bay tension (deliberate, keep)
A Medic on a ship that installed a Clone Bay has almost nothing to do. That is a
real cost of the choice and one of the better things in this version. Do not
soften it.

#### Data format
`data/classes.json` defines classes. `data/crew.json` assigns class and name.
**No class logic may be hardcoded in GDScript.** Adding a seventh class must
require editing JSON only.

### 5. The crew

Six crew, one per class. See `data/crew.json`.

| Slot | Class | Name |
|------|-------|------|
| 1 | Commander | Smith — gives his real name only to the core crew |
| 2 | Soldier | Bram Ostrow |
| 3 | Engineer | Juno Vela |
| 4 | Pilot | Dex Mazur |
| 5 | Medic | Sunny Kwon |
| 6 | Synthetic | TOCK (designation TK-04) |

#### Crew states
`ACTIVE` → `DOWNED` (0 HP, cannot act, bleeds out in 30s **[PLAY-GATED]** unless
reached by the Medbay) → `DEAD`.
Synthetics use `ACTIVE` → `DISABLED` → `DESTROYED` and skip the timer.

#### Crew XP
- 1 XP per 5s manning an undamaged system.
- Level 1 at 20 XP (+20% manning bonus), Level 2 at 60 XP (+35%) **[PLAY-GATED]**.
- XP is **per system**. A Pilot who has only ever manned Engines is not an expert
  at Weapons. This is what makes a *specific* dead crew member irreplaceable.
- Synthetics gain XP at the same rate but **never lose it** — there is no clone
  to reset. Repairing a Synthetic restores it intact.

### 6. Medbay OR Clone Bay — one slot

The ship has **one** medical slot: a Medbay or a Clone Bay, never both.
No swapping in v0.2 (no stations exist) — dev key `F1` toggles it for testing.

#### Medbay (default at run start)
- Heals crew in the room: 4 HP/s per power bar, max 2 power.
- Revives a Downed crew member in the room to 20 HP.
- Does nothing for the dead, and nothing for Synthetics.

#### Clone Bay
- On death, the crew member re-materialises after 12s **[PLAY-GATED]** at full HP.
- **The clone loses all XP in every system.** The person returns; the expertise
  does not.
- Cannot heal. Chip damage never goes away mid-combat.
- **If the Clone Bay is offline (damage 3) when someone dies, they are gone
  permanently.**
- Does not work on Synthetics.

The Clone Bay is not a safety net, it is a bet: healing and expertise traded for
a second chance that can itself be shot out from under you.

### 7. Fire

- A hit has a 20% chance **[PLAY-GATED]** to start a fire in the struck room.
- Fire deals 1 damage per 2s to the room's system and 5 HP/s to crew present.
- Fire spreads to an adjacent room every 8s **[PLAY-GATED]** at 30% chance.
- Crew extinguish in 6s **[PLAY-GATED]**, taking damage throughout. While
  firefighting they cannot repair or man.
- Requires a room adjacency list in `data/ship_layout.json`.
- Enemy ships burn too.

### 7a. Combat log — READABILITY IS A MECHANIC

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

### 8. Encounters

Hardcoded linear list, jump screen between each. Raised from 5 to **6 combats**,
all fights, no events, so fire and crew death have room to play out.

Enemies live in `data/enemies.json`, six templates, difficulty rising by index.
Jump screen keeps the v0.1 options: repair 15 scrap → +5 hull,
upgrade 30 scrap → +1 reactor power. **Scrap only. No second currency in v0.2.**

### 9. Balance safeguards

1. **Death spiral.** If sim runs show >20% of losses in the first two encounters,
   fire chance is too high.
2. **Clone Bay dominance.** If the Clone Bay is strictly better, the choice is
   fake. Report win rates for both loadouts separately.
3. **Synthetic dominance.** A crew member immune to bleed-out may simply be
   better. Report win rate with TOCK alive at end of run versus destroyed.

### 10. Acceptance criteria

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
