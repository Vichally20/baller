# Writing scenarios

Scenarios live in `assets/content/`. You only edit JSON files there, never Dart code.

```
assets/content/
  story.json            the chapters, in the order they're played
  items.json            every item a scenario can give or take
  chapters/
    01_trial.json       one file per chapter
```

## How the story plays

The game plays a chapter's scenarios in order. After every **2 scenarios** comes a **match**. If a chapter ends with one scenario left over, a match follows that too.

Each scenario shows its text and 2–4 choices. The player picks one, and the game picks one of that choice's **outcomes** at random. It shows the outcome's text and applies its **effects**.

## A chapter file

```json
{
  "id": "trial",
  "title": "The Trial",
  "when": { "pathway": ["trials"] },
  "verdict": true,
  "scenarios": [ ...scenarios, in order... ],
  "matches": [
    { "title": "Trial match", "opponent": "The other trialists" }
  ]
}
```

- `id` is a short name with no spaces. Each chapter needs a unique one.
- `matches` names the match after each pair of scenarios, in order. It's optional: unnamed matches are just called "Match".
- `when` (optional) says which players get the chapter. See [Who plays a chapter](#who-plays-a-chapter).
- `pool` (optional, `true` or `false`) makes the chapter a pool of repeatable scenes for the league season. See [Season scenes](#season-scenes).
- `verdict` (optional, `true` or `false`) is for trial chapters. When the chapter ends, the trial club gives its verdict and the player signs. "The Trial" uses it.

### Season scenes

When a player has played every chapter written for them and has signed for a club, the career carries on as a **league season**: 38 rounds against the other clubs in their division, each round **2 scenes, then the match**.

Those scenes come from **pool chapters**: chapters with `"pool": true`. They are not played in order. The game shuffles every pool scene meant for the player once per season and deals them out two per round, so a scene only comes back after the player has seen the whole pool.

```json
{
  "id": "season_pool",
  "title": "Matchweek",
  "pool": true,
  "scenarios": [ ...scenes that make sense any week of a season... ]
}
```

- Write pool scenes so they work any week: no "first day", no story that needs an earlier scene. `{opponent}` names that week's opponent.
- A pool chapter can have `when` like any chapter, e.g. a pool only for academy players (`"pathway": ["academy_abroad", "academy_home", "academy_trials"]`).
- Pool chapters can't have a `verdict`, and their `matches` are ignored: the season decides the matches.
- The more pool scenes there are, the less often they repeat. `chapters/pool_season.json` has the first eight.

### Who plays a chapter

Without `when`, every player gets the chapter. With it, only players who match **every** part you give:

```json
"when": {
  "pathway": ["trials"],
  "tier": ["average", "poor"],
  "region": ["africa"],
  "country": ["nigeria", "ghana"],
  "age": { "min": 15, "max": 16 }
}
```

| Key | Values |
|---|---|
| `pathway` | `offers` (any offer), `trials` (any trial), or exactly one of: `academy_abroad`, `academy_home`, `senior_abroad`, `senior_home`, `academy_trials`, `home_trials` |
| `tier` | `genius`, `rare`, `average`, `poor` |
| `region` | `africa`, `europe`, `south_america`, `asia` |
| `country` | starting country ids: `nigeria`, `ghana`, `england`, `spain`, `germany`, `france`, `italy`, `brazil`, `argentina`, `japan` |
| `age` | `min` and/or `max`, both inclusive |

The pathways, from docs/career-design.md §5:

| Pathway | Who |
|---|---|
| `academy_abroad` | Rare or genius, under 17, from Nigeria or Ghana: a European academy |
| `academy_home` | Rare or genius, under 17, elsewhere: a home academy |
| `senior_abroad` | Rare or genius, 17+, from Nigeria or Ghana: a European reserve or Division 2 side |
| `senior_home` | Rare or genius, 17+, elsewhere: a senior or B-team contract at home |
| `academy_trials` | Average or poor, from Nigeria or Ghana: a trial at a foreign club's African academy |
| `home_trials` | Average or poor, elsewhere: an open trial at a lower-division club at home |

Chapters play in `story.json` order, skipping the ones a player doesn't match.

To add a chapter, create `chapters/02_something.json` and add it to `story.json`:

```json
{ "chapters": ["chapters/01_trial.json", "chapters/02_something.json"] }
```

## A scenario

```json
{
  "id": "the_scout",
  "title": "The Scout",
  "text": "Saturday evening in {city}. ...\n\nAfter the game he waves you over.",
  "choices": [
    {
      "text": "\"Yes. I'll be there.\"",
      "outcomes": [
        { "text": "He writes an address...", "effects": { "morale": 10, "coach": 5 } }
      ]
    },
    {
      "text": "\"Maybe. What's in it for me?\"",
      "outcomes": [
        { "weight": 2, "text": "He laughs...", "effects": { "morale": 5 } },
        { "weight": 1, "text": "His smile fades...", "effects": { "coach": -10 } }
      ]
    }
  ]
}
```

- `id` must be unique across **all** chapters, and must never change once players have it in a save.
- `text` uses `\n\n` for a new paragraph and `\"` for a quote mark.
- Each scenario has 2–4 `choices`.
- Each choice has at least one outcome.
  - With one outcome, picking the choice always gives that outcome.
  - With several, `weight` sets the odds. In the example, "He laughs" happens 2 times in 3 and "His smile fades" 1 time in 3. A missing `weight` counts as 1.

### Placeholders

These are replaced with the player's details:

| Write | Becomes |
|---|---|
| `{first}` | first name ("Tunde") |
| `{name}` | full name ("Tunde Bakare") |
| `{shirt}` | shirt name ("BAKARE") |
| `{city}` | starting city ("Lagos") |
| `{country}` | starting country ("Nigeria") |
| `{club}` | the player's club ("Ashbury Rovers"), or the academy while on an academy trial ("Ashbury Rovers Academy Lagos") |
| `{manager}` | the club manager's name |
| `{position}` | where the manager plays the player ("Winger") |
| `{opponent}` | the next league opponent ("Ashbury Rovers U18"); outside the season, "the opposition" |

`{club}`, `{manager}` and `{position}` need a club, which every player has once they've chosen their pathway.

Write in the second person ("you"), so the text works for any player.

### Effects

All effects are optional. The numbers are **changes**, not new values.

| Key | What it changes |
|---|---|
| `money` | Cash. It starts at 100 and never goes below 0. |
| `morale` | Confidence, 0–100. It starts at 50. |
| `coach` | Relationship with the coach, 0–100. It starts at 50. |
| `teammates` | Relationship with teammates, 0–100. It starts at 50. |
| `addItems` | Item ids to give, e.g. `["second_hand_boots"]` |
| `removeItems` | Item ids to take away |

## Items

Every item a scenario uses must be listed in `items.json`:

```json
{
  "second_hand_boots": {
    "name": "Second-hand boots",
    "description": "Half a size too big, but the studs grip."
  }
}
```

## Checking your work

Run `flutter test test/content_test.dart`. It loads every file and reports the exact place of any mistake, for example a missing comma, an unknown effect name, or an item that isn't in `items.json`.
