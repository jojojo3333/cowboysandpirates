# VOICE_AND_EVENTS.md

Design for narrative and audio. **This is a v0.4 document.** It exists now so
that the combat log built in v0.2 carries the right hooks, instead of being
retrofitted later.

**Nothing in this file is built before v0.4 except §6.**

---

## 1. The narrative model: situations, not story

FTL sold millions with no plot. No chapters, no protagonist arc, no dialogue
worth skipping — every text moment is a self-contained vignette with a choice
and a consequence, over in fifteen seconds. There was never anything long
enough to skip.

Trigon did the opposite and players skipped it. Its story is chapter-gated, so
dying means re-reading the same dialogue and re-running the same quests, and
reviewers described the writing as lacking context and the characters as
uninteresting. In a roguelike, **static story text becomes skip-fodder by run
three regardless of how well it is written.**

### Our model
- **No chapters. No gating. No plot the player must sit through.**
- Events are short situations: 2–4 sentences, 2–3 choices, immediate consequence.
- **One throughline only:** the power-armour quest, delivered in fragments of
  1–2 lines. Never a cutscene.
- **Skip is instant, always available, and never penalised.** If a player skips
  everything, the game must still be fully playable and fully legible.

### The one rule that makes this work
**Text is conditional on crew state, not authored as plot.**

One event, authored once, reads differently every run depending on who is alive,
who is owed shares, and who is good at what. That is roughly a 4x content
multiplier for a 1.3x authoring cost, and it turns narrative into a readout of
*your* run rather than a script you have already read.

---

## 2. Event format

Events live in `data/events.json`. Every text field is a **line pool**: a list
of candidates with optional conditions. The engine picks the highest-priority
line whose conditions are met, breaking ties with the run RNG.

```json
{
  "id": "derelict_hauler",
  "title": "Derelict Hauler",
  "body": [
    { "text": "A hauler drifts with no transponder. The cargo bay is intact.",
      "priority": 0 },
    { "text": "A hauler drifts with no transponder. Vela reads the hull and does not like what it tells her.",
      "priority": 10, "if": { "crew_alive": ["vela"] } }
  ],
  "reactions": [
    { "speaker": "vela", "priority": 10,
      "if": { "crew_alive": ["vela"] },
      "text": "Reactor's been cold three weeks. Whatever happened, it happened fast." },
    { "speaker": "vela", "priority": 20,
      "if": { "crew_alive": ["vela"], "crew_xp_at_least": { "vela": { "engines": 60 } } },
      "text": "Cold three weeks. Scuttled from inside. Somebody wanted it dead." },
    { "speaker": "tock", "priority": 10,
      "if": { "crew_active": ["tock"] },
      "voice": true,
      "text": "Survivor probability: four percent. I have included the optimistic model." },
    { "speaker": "ostrow", "priority": 30,
      "if": { "crew_alive": ["ostrow"], "unpaid_shares_at_least": 2 },
      "text": "Whatever's in there, I'd like my cut of it this time." }
  ],
  "choices": [
    { "text": "Strip it", "effects": { "scrap": 20, "hull": -2 } },
    { "text": "Leave it", "effects": {} }
  ]
}
```

### Condition keys (extend freely, never hardcode)
`crew_alive` · `crew_dead` · `crew_active` (alive and not Downed/Disabled) ·
`crew_xp_at_least` · `unpaid_shares_at_least` · `heat_at_least` ·
`hull_below` · `sats_below` · `has_component` · `medical_slot` ·
`encounter_index_at_least`

### Authoring rules
- Priority 0 lines are the fallback and **must always exist**. An event with no
  valid line is a bug that only appears when half the crew is dead.
- Reactions are optional garnish. The event must read fine with none of them.
- Maximum 2 reactions shown per event. More is a wall of text.
- Body: 2–4 sentences. Reactions: one sentence. No exceptions.

---

## 3. TOCK

The only voiced character in the game. This is a design decision, not a budget
decision, and it must read that way.

### Why only TOCK
A synthetic is the one role where TTS artifacts are characterisation rather than
cheapness. Flat prosody, slightly wrong emphasis, a beat of latency — on a human
these read as a corner cut; on a machine they read as correct. Everyone else
gets text speech bubbles, which is defensible in fiction: TOCK is on the
intercom, everyone else is shouting inside their own room.

**Do not add a second voice.** One voice among silent crew is a design. Two
voices is a budget, and players immediately notice who was left out. Voicing a
second character is a commitment to voicing all six.

### Voice rules
- Answers questions completely and literally, including rhetorical ones.
- Delivers catastrophic news in the same register as the time of day.
- States probabilities unprompted. They are usually bad. He does not soften them.
- Has never made a joke and is regularly the funniest thing aboard.
- **Never uses contractions.** This is the single cheapest tell that he is not
  a person, and it must be consistent in every line, including the sad ones.
- Never says anything the text log has not already said in plain form.

### The quiet ship
**When TOCK is DISABLED, the ship goes silent.**

The text log continues at full detail, so no information is lost and nothing
becomes unplayable. What is lost is the company. This is the strongest
consequence in the game for a state that costs nothing to implement — it is
simply the bark system checking whether he is ACTIVE.

Restoring him plays one specific line, reserved, heard at most once per run.

---

## 4. Barks

### The failure mode we are avoiding
Trigon's speech bubbles were pure information — "one more shot and their ship
will go down." The log already says that. A voice that repeats the UI becomes
noise within an hour and then players mute it, and once muted it never comes
back on.

**A bark must add a read on the situation, not a report of it.**

- Log: `SHIELDS OFFLINE.`
- TOCK: "We are now relying on evasion. Mazur, this is your moment.
  Statistically, it is not."

### Hard rules
1. **No bark is load-bearing.** Everything TOCK says also exists in the text
   log. Muting the game must cost atmosphere and nothing else. This rule
   outranks every other consideration in this file.
2. **Minimum 8s between barks**, 12s for the same trigger. Silence is what makes
   the lines land.
3. **Never fire for something already loud on screen.** Redundancy kills the
   feature.
4. **Rarity tiers** (below). A perfect line heard three times in one fight is a
   worse line.
5. **Condition on crew state**, using the same condition keys as events.
6. Barks never fire while paused. They queue and drop if stale.

### Rarity tiers
| Tier | Variants needed | Frequency |
|------|-----------------|-----------|
| Common | 10+ | Any time, subject to cooldown |
| Uncommon | 5+ | Max twice per encounter |
| Rare | 3+ | Max once per encounter |
| Signature | 1 | Max once per **run** |

Signature lines are the ones people quote. Spend them: first crew death, first
clone returning at zero, TOCK restored, final encounter start, run won.

### Trigger table

**In combat**
| Trigger | Tier |
|---------|------|
| Combat start | Common |
| Enemy shields down | Uncommon |
| Our shields down | Uncommon |
| System destroyed (ours) | Uncommon |
| Fire started aboard | Uncommon |
| Crew Downed | Rare |
| Crew died | Signature (first per run) |
| Clone returned at zero XP | Signature |
| Hull below 25% | Rare |
| Enemy hull below 25% | Uncommon |
| Victory | Common |

**Out of combat**
| Trigger | Tier |
|---------|------|
| Jump completed | Common |
| Arriving at a station | Common |
| Shares deferred | Rare |
| Heat tier increased | Uncommon |
| Power-armour component acquired | Signature |
| TOCK restored from DISABLED | Signature |
| Run lost | Signature |

### Line budget for v0.4
Roughly **180 lines**. That is a weekend of writing and an afternoon of
generation, not a production. Do not scope it larger before it has been heard
in-game.

---

## 5. TTS pipeline and licensing

**Settle licensing before generating 400 lines and building a pipeline around
them.** Commercial-use terms for synthesised speech vary significantly between
services; some restrict or prohibit shipping in a commercial game, some require
attribution, and any voice modelled on a real performer carries separate legal
risk. This is a cheap check now and an expensive one after a Steam page exists.

Checklist, before any bulk generation:
- [ ] Written confirmation that commercial game distribution is permitted
- [ ] Confirm whether attribution is required, and where it must appear
- [ ] Confirm the voice is not modelled on an identifiable performer
- [ ] Confirm terms survive a change of pricing tier or a service shutdown
- [ ] Keep every generated line's source text in `data/` so the whole set can be
      regenerated with a different vendor if terms change

### Pipeline
- Lines live as text in `data/barks.json`. **Text is the source of truth.**
- A build script generates audio to `audio/tock/<line_id>.ogg`.
- Missing audio file = the line still fires as text. **The game must never
  require the audio to exist.** This keeps the text/audio split honest and keeps
  the game shippable mid-generation.

---

## 6. What v0.2 must do now

Only this. Nothing else in this document is built yet.

The combat log in `GAME_SPEC v0.2 §7a` must emit **structured events**, not
formatted strings:

```gdscript
# sim/log_event.gd
var type: String        # "SYSTEM_DESTROYED", "CREW_DOWNED", "CLONE_RESTORED"
var severity: String    # "neutral" | "warning" | "critical"
var subjects: Array     # crew ids, system ids
var values: Dictionary  # damage amounts, timers
```

The UI formats these into text. In v0.4 the bark system subscribes to the same
stream and needs no changes to the simulation.

**If the log emits pre-formatted strings, the bark system will require a rewrite
of every logging call site.** This is the entire reason this file exists now.
