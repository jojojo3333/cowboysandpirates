# Beckett and Ziva — the agent-in-the-engine loop

Third research report, 2026-08-17. **Everything below is a claim, not a verified
fact.** The container this project is developed in cannot reach GitHub's web UI,
the Godot Asset Library or Sketchfab, so none of it was checked. Three times
this week a confident description of an asset turned out to be wrong when the
file was finally opened, so the verification checklist at the bottom is not
scepticism for its own sake — it is the cheapest hour anyone can spend on this
project.

## What "generation" means here

The word came out of the previous report and was adopted without defining it.
It is not a technical term and nobody outside this conversation uses it. What it
labels is **how short the loop is between the agent changing something and the
agent finding out whether that worked.**

| | The agent… | Who closes the loop |
|---|---|---|
| 1 | completes lines | the human, immediately |
| 2 | writes systems, reads compiler errors | compiler for syntax, human for behaviour |
| 3 | writes systems, runs tests, reads output, screenshots | **automated for correctness, human for feel** |
| 4 | *plays the game*, observes runtime state, asserts, corrects | automated for most behaviour too |

**This project is at 3.** Not because of the model — because `tools/verify.sh`
exists, the game can be launched headless, and screenshots and GIFs can be
captured. That is the entire reason three outside packages arrived broken this
week while the same tasks worked here. It was never a difference in
intelligence; it was a difference in whether anyone could see the result.

The gap to 4 is narrower than it looks and very specific: **poking at a running
scene is currently ad hoc.** Finding the collapsed-HUD bug meant writing a
throwaway probe script that printed node sizes. It worked, it took two minutes,
and nothing about it persists. Generation 4 is that made permanent.

## What the report claims

**Beckett** — a GDScript `EditorPlugin` that turns the Godot editor itself into
an MCP server, with no Node.js or Python bridge. An MCP client such as Claude
Code connects over localhost.

Claimed tool surface, free edition:

- *write*: `write_script`, `script_patch`, `create_node`, `delete_node`,
  `instance_scene`, `set_property`, `connect_signal`, `create_resource`
- *run*: `play_scene`, `stop_scene`, `get_play_state`, `wait_until`, `logs_read`
- *observe*: `screenshot`, `get_remote_tree`, `find_nodes`, `wait_for_node`,
  `runtime_get_property`, `monitor_properties`, `get_performance_monitors`

Claimed paid edition adds input and assertions: `simulate_input`,
`click_button_by_text`, `click_control`, `click_world`, `drag`,
`assert_node_state`, `assert_screen_text`, `compare_screenshots`, `test_run`.

Also claimed: recorded playtests replayable as deterministic regression tests,
and screenshot comparison using PSNR rather than a boolean same/different, with
the failing frame saved for a vision-capable agent to inspect.

**Ziva** — a similar idea approached from the other side: the agent lives inside
the Godot editor rather than connecting from outside. Claimed to inspect the
scene tree, edit nodes and scripts, read Godot errors, launch and screenshot the
game, and playtest it, while also exposing itself over MCP.

**`satelliteoflove/godot-mcp`** — open source, and the claim worth the most if
true: **deterministic time**. Freeze, advance exactly N frames, inject input,
advance N frames, inspect. That is what makes agent playtesting reproducible
rather than flaky, and it is the part this project would benefit from most,
because a real-time-with-pause game is exactly where frame-timing flake lives.

## Why this matters here specifically

The three items line up with what has already been decided:

- Backlog item 2 is a visual test harness built by hand. If `compare_screenshots`
  and `assert_node_state` already exist and work, **most of item 2 is bought
  rather than built.**
- Deterministic frame stepping would make the balance harness and any future
  playtest reproducible in the same way the seeded RNG already makes the
  simulation reproducible.
- The semantic-API idea at the end of the report is the strongest part and does
  not depend on any of these tools being real: **expose game state for testing
  rather than making an agent infer it from pixels.** A `GameTestAPI` answering
  "which crew member is selected", "where is TOCK", "which clip is playing",
  "what does the log say" would be worth building regardless. Screenshots
  become the visual layer; the API is the truth layer.

## Verification checklist — do this before building anything on it

Each of these is a minute, and the answers change the plan.

1. Does the **Beckett** repository exist, and when was it last committed to?
2. Is it in the **Godot Asset Library**, and does the listing say Godot 4.7?
3. Do the free-edition tool names above appear in its actual source or README —
   particularly `screenshot`, `get_remote_tree` and `runtime_get_property`?
4. Is `compare_screenshots` free or paid? This decides whether item 2 is bought
   or built.
5. Same three questions for **Ziva**, and whether it needs a subscription.
6. Does `satelliteoflove/godot-mcp` exist, and does it really do deterministic
   frame stepping?
7. **Licences.** Anything installed as an editor plugin is a dependency; a
   proprietary one that stops being maintained is a problem later.

**If Beckett is real and its free edition can screenshot and read the remote
scene tree, reorder the backlog and try it before writing item 2 by hand.** If
it is not, item 2 stands exactly as written — the research in
`2026-08-17-machine-checkable-visuals.odt` is enough to build it without any
plugin.

One caution the report makes itself and which is worth repeating: both projects
are young, with the significant capabilities recent. Depending on either for the
core development loop is a bet. Building the semantic test API ourselves is not.

---

# Checked, 2026-08-17 — partly

**How much to trust this section.** The container reached web *search* but not
the pages themselves: `beckettlabs.itch.io` and `forum.godotengine.org` are both
blocked by the egress proxy. So everything below comes from search-result
summaries, which are themselves someone's paraphrase of a page. That is one
source better than the original report and one worse than reading the thing.
**Nothing here has been installed or run.** Treat it as "the product exists and
is described this way", not as "this works".

| # | Question | Answer |
|---|---|---|
| 1 | Does Beckett exist? | **Yes.** Listed on itch.io as *Beckett — MCP for Godot* by beckettlabs, with a devlog at v1.9, and an announcement thread on the official Godot forum. |
| 2 | Godot version? | Described as **Godot 4.2+**. We are on 4.7 — not explicitly confirmed, and worth checking on install. |
| 3 | Architecture as claimed? | **Yes.** "One GDScript plugin, no bridge, fully local. Zero-sidecar — no Node.js, no Python. The addon is the server." That matches the report exactly. |
| 4 | Free vs paid, and where does the split fall? | **Free "Lite" is MIT.** Full is **$15 one-time.** Lite "already sees the running game — screenshot, live tree, runtime state", and `get_performance_monitors` samples over a window returning min/avg/p95/max. Full adds the playtest loop: find and click UI in 2D and 3D, drive input, assert. |
| 5 | Is `compare_screenshots` free or paid? | **Still not answered directly.** But the split above puts every *asserting* tool in Full, so assume paid until seen otherwise. |
| 6 | `satelliteoflove/godot-mcp`, and is the deterministic stepping real? | **Yes, and it is described as a core feature** — freeze the game clock, step exact slices of game time or step until a condition holds, with inputs riding inside the window. Input injection covers named actions with analog strength, joypad buttons and sticks, raw keys with modifiers, mouse-look and typing. |
| 7 | Licences | Beckett Lite **MIT**, Full proprietary at $15. `satelliteoflove/godot-mcp` is on GitHub and npm with a LICENSE file; the licence itself was not read. Ziva **not checked**. |

## What this changes

**The backlog's own trigger has fired.** It said: *if Beckett is real and its
free edition can screenshot and read the remote scene tree, reorder the backlog
and try it before writing item 2 by hand.* It is, and it does. Item 2 should be
"install Beckett Lite and find out", not "build a visual test harness".

**And the $15 question is smaller than it looked.** Full is a one-time $15,
which is less than an hour of anyone's time. The decision is not "is it worth
the money", it is "is it worth the dependency".

**One correction to the framing.** The report treats the semantic test API as
the idea that needs no plugin — still true, and still the strongest item. But
`satelliteoflove/godot-mcp` is described as already exposing live entity state
— positions, velocities, animation state, custom data — as structured JSON,
"without relying solely on screenshots". That is the same idea, shipped. So the
choice is not build-versus-nothing, it is build-versus-adopt, and the argument
for building it ourselves is now specifically that **our truth layer should
speak in our own nouns** — which crew member is selected, where TOCK is, what
the log said — rather than in generic node positions.

## Still open

- Ziva: not checked at all.
- Whether any of it works on **4.7** specifically.
- Whether `compare_screenshots` exists under that name in either edition.
- All of it is second-hand. **The next step is to install Beckett Lite in a
  scratch copy of this project and read the tool list off the running server.**
  That answers every remaining question at once and costs about ten minutes.
