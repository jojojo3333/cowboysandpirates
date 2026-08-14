# GAME_SPEC v0.1 — "Deadweight" (working title)

## 0. Purpose of this version

Prove that the core loop is fun in under 10 minutes of play: **manage power, watch
timers, click things under pressure, survive 5 jumps.**

If it is not fun with grey rectangles, no amount of art will save it.

## 1. Goals

- MUST: one playable run of exactly 5 fixed encounters, start to death-or-victory
- MUST: real-time combat with a working pause (SPACE)
- MUST: power allocation between 4 systems, changeable mid-combat
- MUST: 3 crew that can be assigned to rooms, take damage, and die
- MUST: run under 10 minutes, be losable, and be winnable

## 2. Non-Goals (DO NOT BUILD)

Everything here is v0.2+. If the plan mentions any of it, the plan is wrong.

- No fire, no hull breaches, no oxygen, no boarding, no enemy crew
- No crew pathfinding — crew teleport instantly to the assigned room
- No Clone Bay (v0.2, first item)
- No procedural map — the 5 encounters are a hardcoded list
- No shops, no weapon drops, no ship selection, no meta-progression
- No power armor quest, no story, no faction system (v0.3+)
- No sprites, no imported assets, no audio, no animation beyond bar fills
- No save/load
- No settings menu, no main menu — the game starts at encounter 1 on launch

## 3. Presentation

Programmer art only. `ColorRect` + `Label` + `ProgressBar`, built **in code**.
Layout: player ship left half, enemy ship right half, HUD bottom.
Dark background, one accent colour per system. Readable > pretty.

## 4. State model

### Ship (player)
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

### Crew
3 crew, each: `name: String`, `hp: int` (max 100), `room: String`, `alive: bool`.
- Crew in a damaged room repair **1 damage point per 4 seconds**.
- Crew in an undamaged room "man" it: +10% to that system's effect
  (weapons charge 10% faster, shields recharge 10% faster, engines +5% evasion flat).
- Crew take 15 damage when their room is hit. At 0 HP they die permanently in v0.1.
- Names: Smith (captain), Vasquez, Okonkwo. Placeholder, content pass comes later.

### Weapons
2 slots, both filled at start:
- **Laser Mk1** — 1 power, charge 8.0s, 1 shot, 1 damage
- **Burst Laser** — 2 power, charge 11.0s, 2 shots, 1 damage each

A weapon only charges if its power requirement is met by Weapons system power.
Player clicks an enemy room to set the target; the shot fires automatically when charged.

### Combat resolution
- Hit chance = `100% - enemy_evasion`
- Each shield layer absorbs 1 damage and is consumed; layers recharge 1 per 4.0s
- Damage that gets through: −1 hull AND +1 damage to the targeted room's system
- Same rules apply to the enemy shooting the player, targeting a random player room

### Enemy
Single ship per combat: `hull`, `evasion`, `shield_layers`, one weapon with a
fixed cooldown. Enemy picks a random player room each shot. No enemy power management.

## 5. The 5 encounters (hardcoded, in this order)

| # | Type   | Content |
|---|--------|---------|
| 1 | Combat | Scout — hull 15, evasion 5%, 0 shields, weapon 1 dmg / 9.0s |
| 2 | Event  | Distress beacon. Choices: **Board it** (60% +25 scrap, 40% one crew −40 HP) / **Scan first** (+10 scrap) / **Ignore** (nothing) |
| 3 | Combat | Raider — hull 22, evasion 10%, 1 shield layer, weapon 2 dmg / 11.0s |
| 4 | Event  | Derelict hauler. Choices: **Strip it** (+20 scrap, −2 hull) / **Leave** (nothing) |
| 5 | Combat | Enforcer — hull 30, evasion 10%, 1 shield layer, two weapons (1 dmg / 7.0s, 2 dmg / 13.0s) |

Combat rewards: +15 scrap on victory.

### Between encounters
A jump screen with two buttons, then **JUMP**:
- Repair: 15 scrap → +5 hull (capped at max)
- Upgrade: 30 scrap → +1 reactor power
Both repeatable while scrap allows.

## 6. Win / lose

- **Lose** when `hull <= 0` or all crew dead → screen: "RUN ENDED — Jump N of 5"
- **Win** after encounter 5 → screen: "RUN COMPLETE — hull X, scrap Y, crew alive Z"
- Either screen has a **RESTART** button that resets state. No persistence.

## 7. Controls

- `SPACE` — toggle pause. All simulation time stops; UI stays interactive.
- Click a crew portrait, then click a room → assign crew to room
- Click `+`/`−` on a system → move a reactor power bar in/out
- Click an enemy room → set weapon target
- The game starts **paused** at the beginning of every combat

## 8. Determinism

All randomness goes through one seeded `RandomNumberGenerator` owned by the run.
The seed is printed on screen. No calls to global `randi()` / `randf()` anywhere.
This is what makes the headless sim runner and bug reproduction possible.

## 9. Acceptance criteria

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
