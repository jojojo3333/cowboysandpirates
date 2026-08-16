# Silver Soldier crew replacement

This change starts from the original repository, not the experimental Vengeance HUD versions.

## Asset

`tools/crew_src/silver_soldier_animated.glb` is the supplied Silver Soldier model. It contains one exported animation clip named `FBXExportClip_0` with substantial humanoid animation. The source does not expose separately named Idle/Walk/Death clips.

## Render

Run:

```text
godot --headless --script res://tools/render_silver_soldier.gd
```

The renderer produces:

- `assets/crew/silver_soldier_walk.png` — 8 frames × 8 facings
- `assets/crew/silver_soldier_idle.png` — held pose × 8 facings
- `assets/crew/silver_soldier_die.png` — held pose placeholder × 8 facings

The walk renderer disables root-position tracks so the exported locomotion becomes an in-place walk suitable for the existing Sprite2D system.

## Game integration

`ui/ship_view.gd` automatically prefers the Silver Soldier sheets when they exist. Until the renderer has been run, it falls back to the original crew sheets so the project remains playable. Once the three Silver Soldier sheets exist, all crew members use the same silhouette. Class differences are applied as restrained tints: commander amber, soldier red, engineer green, pilot cool blue, medic blue, synthetic cyan.

Enemies are not changed yet because the current original repository does not have an enemy crew renderer/state. When boarding combat is implemented, use the same model with a charcoal/black tint for enemy crew.

## Why not directly render the GLB in the ship scene?

The current game deliberately uses 2D Sprite2D crew sheets. Keeping that architecture avoids turning the whole ship renderer into a mixed 2D/3D scene and preserves the existing hit-testing, animation-frame, facing and movement code. The supplied GLB is therefore treated as a source asset for high-quality 2D renders.
