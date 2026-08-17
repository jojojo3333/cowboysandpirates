#!/usr/bin/env python3
"""The house rules, as checks instead of prose.

    tools/verify.sh rules

Every rule below is already written down in CLAUDE.md, ARCHITECTURE.md or
ASSETS.md. Several of them were still broken, because a rule in a document is
something a reader might remember and a rule in a check is something that stops
them. This file is the difference.

Add a rule here the moment one is agreed. If a check turns out to be wrong,
argue with it and change it — do not weaken it to get a green.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directories whose contents are the game, as opposed to tooling.
GAME_DIRS = ("sim", "ui")
ALL_GD = ("sim", "ui", "tools")

findings: list[tuple[str, str, str]] = []   # (severity, rule, detail)


def fail(rule: str, detail: str) -> None:
    findings.append(("ERROR", rule, detail))


def warn(rule: str, detail: str) -> None:
    findings.append(("WARN", rule, detail))


def gd_files(*dirs: str) -> list[Path]:
    out: list[Path] = []
    for d in dirs:
        out.extend(sorted((ROOT / d).rglob("*.gd")))
    if not dirs:
        out.extend(sorted(ROOT.glob("*.gd")))
    return out


def lines_of(path: Path) -> list[tuple[int, str]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    return list(enumerate(text.splitlines(), start=1))


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def strip_comment(line: str) -> str:
    """Crude, but string literals containing # are rare here and a false
    negative is much cheaper than a false positive in a rule check."""
    return line.split("#", 1)[0]


# --- Godot 4 syntax ---------------------------------------------------------
# CLAUDE.md: these are Godot 3 idioms and simply fail to run under 4.x.

def rule_godot4_syntax() -> None:
    old_connect = re.compile(r"""\.connect\(\s*["']""")
    for path in gd_files(*ALL_GD) + gd_files():
        for n, line in lines_of(path):
            code = strip_comment(line)
            if old_connect.search(code):
                fail("godot4-signals",
                     f"{rel(path)}:{n} Godot 3 connect(\"sig\", ...); use sig.connect(callable)")
            if re.search(r"\byield\s*\(", code):
                fail("godot4-await", f"{rel(path)}:{n} yield() is Godot 3; use await")
            if "OS.get_ticks_msec" in code:
                warn("godot4-timing",
                     f"{rel(path)}:{n} OS.get_ticks_msec is not gameplay timing; use the sim clock")


# --- pause ------------------------------------------------------------------
# CLAUDE.md: get_tree().paused freezes UI input too. The sim owns time_scale.

def rule_pause() -> None:
    for path in gd_files(*ALL_GD) + gd_files():
        for n, line in lines_of(path):
            if "get_tree().paused" in strip_comment(line):
                fail("pause-via-time-scale",
                     f"{rel(path)}:{n} get_tree().paused freezes UI input; the sim owns time_scale")


# --- the sim/ boundary ------------------------------------------------------
# ARCHITECTURE.md: sim/ is a headless library. No Node, no scene API, and it
# never imports ui/. This is the property that let the renderer be rebuilt twice
# and the whole ship be replaced without the simulation noticing.

SCENE_API = (
    "Node2D", "Node3D", "Control", "Sprite2D", "SubViewport", "Viewport",
    "get_tree()", "get_node(", "add_child(", "queue_redraw(", "CanvasItem",
    "AnimationPlayer", "Camera2D", "Camera3D", "PackedScene", "Skeleton3D",
)


def rule_sim_is_headless() -> None:
    for path in gd_files("sim"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"^extends\s+(Node|Control|Node2D|Node3D|CanvasItem)\b", text, re.M):
            fail("sim-headless", f"{rel(path)} extends a Node type; sim/ is RefCounted only")
        for n, line in lines_of(path):
            code = strip_comment(line)
            for token in SCENE_API:
                if token in code:
                    fail("sim-headless", f"{rel(path)}:{n} scene API in sim/: {token}")
            if re.search(r"\bres://ui/", code):
                fail("sim-imports-ui", f"{rel(path)}:{n} sim/ must never reference ui/")


# --- static typing ----------------------------------------------------------
# CLAUDE.md: not a style preference. Godot 4.7 treats several type-inference
# warnings as errors, so untyped code fails `verify static`.

UNTYPED_VAR = re.compile(r"^\s*var\s+[a-z_][a-z0-9_]*\s*(:?=)")


def rule_static_typing() -> None:
    for path in gd_files(*GAME_DIRS) + gd_files():
        bad: list[int] = []
        for n, line in lines_of(path):
            code = strip_comment(line)
            m = UNTYPED_VAR.match(code)
            if m and m.group(1) == "=":
                bad.append(n)
        if bad:
            shown = ", ".join(str(b) for b in bad[:6])
            more = f" (+{len(bad) - 6} more)" if len(bad) > 6 else ""
            fail("static-typing", f"{rel(path)} untyped var at line {shown}{more}")


# --- the invisible-Control trap ---------------------------------------------
# The number one cause of "the game runs but the screen is empty". A Control
# built in code with set_anchors_preset() keeps whatever offsets it had, which
# for a fresh node describes a 0x0 rect: anchors 0,0,1,1 with offsets
# 0,0,-1920,-1080. Its children then collapse into the top-left corner.
#
# This exact bug arrived in an outsourced UI package and cost a session.

def rule_control_sizing() -> None:
    for path in gd_files("ui") + gd_files():
        for n, line in lines_of(path):
            code = strip_comment(line)
            if "set_anchors_preset(" in code and "set_anchors_and_offsets_preset(" not in code:
                fail("control-sizing",
                     f"{rel(path)}:{n} set_anchors_preset leaves offsets alone and yields a 0x0 "
                     f"node; use set_anchors_and_offsets_preset")


# --- the sprite-sheet contract ----------------------------------------------
# The renderer and the viewer must agree on frame counts, or sheets are sliced
# wrongly and crew animate through their neighbours' frames.

def rule_clip_frames_match() -> None:
    view = (ROOT / "ui" / "ship_view.gd")
    baker = (ROOT / "tools" / "render_soldier.gd")
    if not view.exists() or not baker.exists():
        return

    def clips(path: Path, name: str) -> dict[str, int]:
        m = re.search(rf"{name}\s*:\s*Dictionary\s*=\s*\{{(.*?)\}}",
                      path.read_text(encoding="utf-8"), re.S)
        if not m:
            return {}
        return {k: int(v) for k, v in re.findall(r'"(\w+)"\s*:\s*(\d+)', m.group(1))}

    a = clips(view, "CLIP_FRAMES")
    b = clips(baker, "CLIPS")
    if not a or not b:
        warn("clip-frames", "could not read CLIP_FRAMES or CLIPS; check by hand")
        return
    for clip in sorted(set(a) | set(b)):
        if a.get(clip) != b.get(clip):
            fail("clip-frames",
                 f"'{clip}' is {a.get(clip)} in ui/ship_view.gd but {b.get(clip)} in "
                 f"tools/render_soldier.gd")


# --- the probe only reads ---------------------------------------------------
# tools/game_probe.gd answers questions about the running game. The moment it
# can also change the game it becomes a second, undocumented way to play, and
# the real one and the test one drift apart until the tests describe a game
# nobody ships. ARCHITECTURE.md 5b states this; here it is enforced.

PROBE_MUTATORS = (
    "choose_plan", "order_move", "order_free", "toggle_pause", ".tick(",
    "queue_free", "set_process", ".emit(",
)


def rule_probe_is_read_only() -> None:
    path = ROOT / "tools" / "game_probe.gd"
    if not path.exists():
        return
    for n, line in lines_of(path):
        code = strip_comment(line)
        for token in PROBE_MUTATORS:
            if token in code:
                fail("probe-read-only",
                     f"tools/game_probe.gd:{n} changes game state: {token}")


# --- the camera contract ----------------------------------------------------
# Every script that photographs a 3D model for this game must shoot it from the
# angle the game draws crew at. tools/preview_models.gd exists specifically to
# judge a candidate model "at the exact size and angle the game draws crew at" —
# so if its pitch drifts from the baker's, it silently answers the wrong
# question, and the answer is an art decision made on a false picture.
#
# This is not hypothetical. Two crew packs were assessed at 62 degrees and
# written up in ASSETS.md at 62 degrees; the game now renders at 80, and those
# write-ups cite an angle the project no longer uses.

def rule_camera_pitch_matches() -> None:
    baker = (ROOT / "tools" / "render_soldier.gd")
    preview = (ROOT / "tools" / "preview_models.gd")
    if not baker.exists() or not preview.exists():
        return

    def pitch(path: Path) -> float | None:
        m = re.search(r"const\s+CAMERA_PITCH\s*:\s*float\s*=\s*([\d.]+)",
                      path.read_text(encoding="utf-8"))
        return float(m.group(1)) if m else None

    a, b = pitch(baker), pitch(preview)
    if a is None or b is None:
        warn("camera-pitch", "could not read CAMERA_PITCH from both scripts; check by hand")
        return
    if a != b:
        fail("camera-pitch",
             f"CAMERA_PITCH is {a} in tools/render_soldier.gd but {b} in "
             f"tools/preview_models.gd; a model judged at the wrong angle is judged wrongly")


# --- asset provenance -------------------------------------------------------
# ASSETS.md: nothing is committed without its origin recorded. This repository
# is public and publishes to GitHub Pages, so committing art is distributing it.

ASSET_SUFFIXES = {".png", ".jpg", ".jpeg", ".glb", ".gltf", ".fbx", ".ogg", ".wav", ".mp3"}


def rule_assets_are_recorded() -> None:
    doc = (ROOT / "ASSETS.md")
    if not doc.exists():
        fail("asset-provenance", "ASSETS.md is missing")
        return
    text = doc.read_text(encoding="utf-8", errors="replace")
    for path in sorted((ROOT / "assets").rglob("*")):
        if not path.is_file() or path.suffix.lower() not in ASSET_SUFFIXES:
            continue
        name = path.name
        stem = re.sub(r"[_-]?\d+$", "", path.stem)
        folder = str(path.parent.relative_to(ROOT))
        if name in text or stem in text or folder in text:
            continue
        fail("asset-provenance",
             f"{rel(path)} is committed but not recorded in ASSETS.md")


# --- the web export ---------------------------------------------------------
# A 42 MB bake source once sat one empty filter away from being downloaded by
# every player.

def rule_export_excludes_sources() -> None:
    preset = ROOT / "export_presets.cfg"
    if not preset.exists():
        return
    text = preset.read_text(encoding="utf-8", errors="replace")
    m = re.search(r'exclude_filter\s*=\s*"([^"]*)"', text)
    if not (ROOT / "tools" / "crew_src").exists():
        return
    if not m or "tools/crew_src" not in m.group(1):
        fail("export-filter",
             "export_presets.cfg does not exclude tools/crew_src/*; the model source would "
             "ship to every web player")


# --- indentation ------------------------------------------------------------
# CLAUDE.md: tabs, not spaces. Mixed indentation is a parse error.

def rule_tabs() -> None:
    for path in gd_files(*ALL_GD) + gd_files():
        for n, line in lines_of(path):
            if line.startswith("    "):
                fail("tabs-not-spaces", f"{rel(path)}:{n} indented with spaces")
                break


# --- one queue --------------------------------------------------------------
# BACKLOG.md is the only file that may hold a list of future work.

def rule_one_queue() -> None:
    for path in sorted(ROOT.glob("*.md")):
        if path.name in ("BACKLOG.md", "SLICE.md", "GAME_SPEC.md"):
            continue
        text = path.read_text(encoding="utf-8", errors="replace").lower()
        if "## next session" in text or "## todo" in text or "## backlog" in text:
            warn("one-queue",
                 f"{rel(path)} looks like it holds a queue; BACKLOG.md is the only one")


RULES = [
    rule_godot4_syntax,
    rule_pause,
    rule_sim_is_headless,
    rule_static_typing,
    rule_control_sizing,
    rule_clip_frames_match,
    rule_camera_pitch_matches,
    rule_probe_is_read_only,
    rule_assets_are_recorded,
    rule_export_excludes_sources,
    rule_tabs,
    rule_one_queue,
]


def main() -> int:
    for rule in RULES:
        rule()

    errors = [f for f in findings if f[0] == "ERROR"]
    warnings = [f for f in findings if f[0] == "WARN"]

    for severity, rule, detail in warnings:
        print(f"WARN  [{rule}] {detail}")
    for severity, rule, detail in errors:
        print(f"ERROR [{rule}] {detail}", file=sys.stderr)

    if errors:
        print(f"\nhouse rules: {len(errors)} violation(s), {len(warnings)} warning(s)",
              file=sys.stderr)
        return 1
    print(f"house rules OK ({len(RULES)} rules, {len(warnings)} warnings)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
