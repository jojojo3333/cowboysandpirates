# world/ — the writing room

**This folder is yours.** It is where the game's content lives in plain words:
who the crew are, what happens to them, what the places are like. Nothing here
is code and nothing here needs to be. Write in whatever shape suits you — notes,
bullet lists, half-finished scenes, contradictions you have not resolved yet.

I read from here. When something in this folder is ready to become a thing the
game does, I turn it into the JSON under `data/` and tell you what I changed.
The reverse direction never happens silently: I do not edit your files to match
the code. If a mission you wrote cannot work as written, I say so and we decide.

## What goes where

| Folder | What belongs in it |
|--------|--------------------|
| `storyboard/` | The arc. What a run feels like start to finish, what the player learns and when, how it ends. |
| `crew/` | The six. Names, histories, how they talk, what they want, who they cannot stand. One file per person is fine. |
| `missions/` | Individual encounters. The situation, the choices, what each choice costs. |
| `gameworld/` | Places, factions, ships, technology, rumours. The stuff `SETTING.md` covers at a high level and you want to go deeper on. |
| `voice/` | Barks, log lines, TOCK's phrasing, anything about how the game sounds. |

## Two things that make my job easier, neither of them required

**Say when something is decided.** A line like `STATUS: decided` or
`STATUS: thinking out loud` at the top of a file tells me whether to build on it
or leave it alone. Without it I will ask.

**Name the crew by their id when you mean a specific one.** The six ids in
`data/crew.json` are what the code keys off. If you write "Mazur" I will know who
you mean, but the id is what survives a rename.

## What already exists elsewhere

`SETTING.md` (Sol in 2100, regions and factions) and `VOICE_AND_EVENTS.md`
(writing rules, event structure) were written before this folder existed. They
still hold. Treat this folder as where you go deeper, not as a replacement — and
if you want either of them moved in here, say so and I will move it.
