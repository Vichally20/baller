# Career design: talent tiers, country, position, pathways, clubs

Status: **agreed**. The open questions were decided on 2026-11-09 (see §9). Numbers are starting points to tune.

## 1. New creation flow

| # | Screen | What happens |
|---|---|---|
| 1 | Identity | Name, shirt name, foot (built) |
| 2 | **Country** | The player **chooses** where to start. Each country shows its benefit. *(Was random; it now comes before the stats so its bonus is visible.)* |
| 3 | **Position** | The player picks the position they'd *like* to play |
| 4 | Stats | Wheels for age + 6 skills (built); the country bonus is added on top |
| 5 | Talents | Innate / Logic draw (built) |
| 6 | **Scout report** | Talent tier, rating, the scout's recommended positions, the player's wish vs the fit |
| 7 | **Your pathway** | Offers (rare/genius) or open trials (average/poor), shaped by country and age |
| 8 | Career hub | Story begins at the chapter that matches the pathway |

## 2. Country benefits

Each country gives **+5 to one stat** and **one perk**. The bonuses are based on football culture and systems, never on ethnicity (e.g. no "African players are faster").

| Country | Identity | Stat | Perk |
|---|---|---|---|
| Nigeria | Street football | +5 Shot | **Scouts' radar**: rare/genius under 17 get offers from European academies |
| Ghana | Academy pipeline | +5 Physical | **Mentors**: start with +10 coach relationship; European academy route as Nigeria |
| England | Academy intensity | +5 Physical | **Big money**: wages and value ×1.25 |
| Spain | Rondo culture | +5 Pass | **Technical schooling**: Pass/Dribble improve faster in training *(later)* |
| Germany | Clear pathway | +5 Defence | **B-teams**: young players get more minutes |
| France | Talent factories | +5 Pace | **Wide net**: more clubs scout you (one extra offer or trial) |
| Brazil | Futsal roots | +5 Dribble | **Flair**: +10 starting morale |
| Argentina | Potrero grit | +5 Shot | **Grit**: morale never drops below 20 |
| Japan | Discipline | +5 Defence | **Professionalism**: start with +10 coach and +10 teammates |
| Italy | Tactical school | +5 Defence | **Tactical brain**: always start with at least one Logic talent |

## 3. Talent tiers

**Talent score** = average of the 6 skills (after the country bonus) **+ 3 if the player has an Innate talent**.

| Tier | Score | Share of players* | Meaning |
|---|---|---|---|
| **Genius** | 68+ | ~8% | Generational. Clubs fight over you. |
| **Rare talent** | 62–67 | ~25% | Clearly special. Several clubs come calling. |
| **Average** | 52–61 | ~55% | Decent. You earn your chance at trials. |
| **Poor** | under 52 | ~12% | Raw. Open trials at small clubs, and a long road. |

\*Exact odds from the wheels (skills 35, 40 … 75, 80: 10 equal slots), including the country's +5 and the 30% Innate chance. History: 2026-11-12 the top slot went from 75 to 80 (Genius 64+, ~7.5%); later that day 70 and 75 were added and the cutoffs moved from 50 / 59 / 64 to 52 / 62 / 68 to keep similar shares. NPCs use the same cutoffs.

## 4. Position

**Positions**: outfield only, since there's no goalkeeping stat yet. They are CB, FB, DM, CM, AM, W, ST.

**Rating per position**: a weighted average of the six skills.

| | Pace | Shot | Pass | Dribble | Defence | Physical |
|---|---|---|---|---|---|---|
| ST | .15 | .35 | .10 | .15 | .05 | .20 |
| W | .30 | .15 | .15 | .30 | .05 | .05 |
| AM | .10 | .20 | .30 | .25 | .05 | .10 |
| CM | .15 | .10 | .30 | .15 | .15 | .15 |
| DM | .10 | .05 | .25 | .05 | .30 | .25 |
| FB | .30 | .00 | .15 | .10 | .30 | .15 |
| CB | .10 | .00 | .15 | .00 | .40 | .35 |

1. **The player picks** a preferred position (screen 3).
2. **The scout recommends** the top 3 positions by rating, shown as a "fit" on the scout report.
3. **The manager decides**, based on their philosophy:
   - **Traditional** plays you where your rating is highest. Preference ignored.
   - **Modern progressive** honours your preference if it's within 5 of your best rating.
   - **New hybrid** honours your preference if it's within 3. It may use you in two positions.

## 5. Pathways (how the story takes shape)

| Tier | Age | Africa (Nigeria, Ghana) | Elsewhere |
|---|---|---|---|
| Genius / Rare | under 17 | **Shipped abroad**: offers from European club academies (England, Spain, France, Germany, Italy) | **Lobbied**: 2–4 domestic big clubs with academies compete to sign you |
| Genius / Rare | 17+ | Offers from European clubs' reserve or second-division sides | Senior or B-team contract offers (Genius: Div 1 · Rare: Div 1–2) |
| Average | any | Trials at **foreign clubs' academies in Africa** (e.g. "Ashbury Rovers Academy Lagos"); earn a move abroad | Trials at Div 2–3 clubs |
| Poor | any | Open trials at foreign clubs' African academies (the smaller clubs' academies) | Open trials at Div 3 clubs |

**Which clubs come for you**: every club has a **playing style**, and each style values certain stats. The clubs whose style best fits your top stats make the offers or hold the trials, so a dribbler attracts possession sides and a powerful runner attracts direct sides.

| Style | Values most |
|---|---|
| Possession | Pass, Dribble |
| High press | Pace, Physical, Defence |
| Counter-attack | Pace, Shot |
| Direct | Physical, Shot |
| Low block | Defence, Physical |

**As built (phase 3):**

- **How many**: Genius 4 offers, Rare 3, trials 3. France's Wide net adds one.
- **Which clubs**: each eligible club scores its fit, plus its stars (×6 for a genius, ×3 for a rare talent, nothing for trials), plus a little seeded chance. The best scores are picked. Abroad, they come from different countries where possible. The list shows the best fit first, and the same player and world always give the same list.
- **Fit %** = ¾ style fit + ¼ position fit.
  - Style fit = the player's average in the style's key stats ÷ their best skill.
  - Position fit = 100 if the manager would play them where they want, minus 5 per rating point otherwise.
- **Eligible clubs**:

  | Pathway | Clubs |
  |---|---|
  | Academy abroad | Clubs with academies in England, Spain, Germany, France and Italy |
  | Academy at home | Home clubs with academies |
  | Senior abroad | Genius: European Div 1 reserve sides and Div 2. Rare: Div 2 |
  | Senior at home | Genius: Div 1. Rare: Div 1–2 |
  | Academy trials (Africa) | Average: Div 1–2 European clubs' academies. Poor: Div 2–3. Held in Lagos, Ibadan, Abuja and Port Harcourt, or Accra, Kumasi, Tema and Cape Coast |
  | Trials at home | Average: Div 2–3. Poor: Div 3 |

- **Offers**: pick a club → signing screen → hub.
- **Trials**: pick a trial → the trial chapter → the club's verdict → signing → hub. A successful academy trialist moves to the parent club.
- **The verdict is always yes for now.** Failing a trial, and what it depends on, is still to decide.
- **The save** keeps the pathway, the club, the academy city and whether the player has signed. A save from before pathways asks for one on the hub, and its story starts over.

**Story**: each pathway starts its own chapter. The existing "The Trial" chapter becomes the average/poor opening. Genius and rare players need new chapters, such as "The Offers" and "Moving Abroad". Chapters gain **conditions** in the content format (tier, region, age, pathway) so writers can target them.

## 6. Clubs & leagues

- **Leagues**: England, Spain, Germany, France, Italy, Argentina, Brazil, Japan. Each has **3 divisions × 20 clubs**, playing a **38-game** home-and-away season. The top 3 go up and the bottom 3 go down.
- **No leagues in Nigeria or Ghana.** Foreign clubs run academies there instead, which is where African players trial.
- **Players are outfield only.** Squads still list 2 goalkeepers as background NPCs so teams look real, but they have no stats beyond a rating.
- **Club**:
  - generated name (fictional, built from per-country patterns such as "Ashbury Rovers", "Real Valmora CF", "SV Rheinfeld 04", "Olympique Saint-Clair", "AC Monteverde", "Esporte Clube Serra Azul", "Club Atlético Villa Esperanza", "Hoshigawa FC"; never a real club's name)
  - **strength stars**: Div 1 = 3–5★, Div 2 = 2–4★, Div 3 = 1–3★
  - playing style
  - manager
  - squad of up to 22
  - reputation and budget
- **Academies**: the top ~6 clubs in each Div 1 have one.
- **The world is generated once per career** from a seed stored in the save, so it's the same every time you load and different in each slot.
- **Squads**: 22 players each, with name, age, position, ratings, value, and nationality (mostly domestic).

## 7. Managers

| Philosophy | Plays | Picks players by | Youth trust | Example quirk |
|---|---|---|---|---|
| **Traditional** | 4-4-2, direct, compact | Experience and best-fit position | Low | Rewards hard work, punishes flair that fails |
| **Modern progressive** | 4-3-3, possession, high press | Technique and preference | High | Gives young players minutes, values Logic talents |
| **New hybrid** | Changes per opponent | Form and versatility | Medium | Uses players in two positions, rotates a lot |

Each manager has a name, age, philosophy, favourite formation, youth trust (1–5★) and temperament (calm / demanding / volatile).

## 8. Player value

`value = base(rating) × age × tier × league × division`

- **base**: €50k × 1.15^(rating − 50), so 50 → €50k, 60 → €202k, 70 → €818k, 80 → €3.3m, 90 → €13.4m
- **age**: 15–19 ×1.5 · 20–23 ×1.2 · 24–27 ×1.0 · 28–30 ×0.8 · 31+ ×0.5
- **tier**: Genius ×3 · Rare ×1.8 · Average ×1 · Poor ×0.6 (NPCs use the same tiers)
- **league**: England 1.6 · Spain 1.4 · Germany 1.3 · Italy 1.25 · France 1.1 · Brazil 0.7 · Japan 0.6 · Argentina 0.6
- **division**: Div 1 ×1 · Div 2 ×0.45 · Div 3 ×0.2

## 9. Decisions (2026-11-09)

1. **20 clubs per division**, 38-game seasons.
2. **Italy** is a starting country (Milan): +5 Defence, Tactical brain.
3. **Nigeria & Ghana** have no domestic leagues. Their trials happen at foreign clubs' African academies.
4. **Under 17 stays as is.** The age wheel remains 15–26, so the academy path is deliberately rare.
5. **No goalkeepers** for the player.

## 10. Build phases

1. **Creation flow** (built): country choice with benefits, position wish, talent tier, position ratings, scout report.
2. **World** (built): league, club and manager generation (seeded per save, `lib/game/world/`), player values, league and club screens, a world card on the hub. A naming pattern appears at most 3 times per division.
3. **Pathways** (built): offers and trials driven by tier, country, age and fit (pathway and signing screens, a club card on the hub); the manager decides the position; chapter conditions (`when`) and a trial `verdict` in the story format; a "First Days" chapter for players with offers.
4. **Season mode** (built): once the written story runs out, a signed player plays their club's league season. Fixtures are a 38-round double round robin among the 20 clubs in the division, shuffled per season. Each round is 2 scenes from pool chapters, then the line-ups and the match. Other games are simulated from the squads' average ratings (Poisson goals, about 2.5 a game, with home advantage). The table shows the promotion and relegation zones, but promotion and relegation aren't applied yet. Academy players play the same clubs' youth sides in a U18 league. When the season ends, the player starts the next one in the same division. The save keeps only the season number, the player's results and the scenes played this round.
5. **Stronger leagues** (built, 2026-11-10): club players get a division boost on top of the generated rating and value.

   | Division | Value | Rating |
   |---|---|---|
   | 1 | +€15m | +5 |
   | 2 | +€5m | +3 |
   | 3 | +€1m | +1 |

   The value part is multiplied by the league's money, so the top five leagues get more than the base (England ×1.6, Spain ×1.3, Germany and Italy ×1.2, France ×1.1) and Brazil, Argentina and Japan less (×0.6–0.7). Once signed, the player's own value gets the same bonus for their club's division (double with an Innate talent). Special players get double: anyone with an Innate talent, and each club's best outfield player. Their stats are generated from the boosted rating, so they play better as well as costing more. England's Division 1 now averages about rating 74 and €20m, up from 68 and €1.5m.
7. **More goals** (built, 2026-11-10; target 2.5–3 a match):
   - **Build-up pays off:** each successful Run, Dribble or Pass in an attack moves the ball one zone closer to goal for the next shot.
   - **Between your chances the rest of the team plays:** a pass or dribble that comes off becomes a shot from inside the box 50% of the time for evenly matched elevens (±4% per rating point of difference, between 15% and 80%).
   - **Sharper shooting:** the on-target factor went from 0.65 to 0.8, and keepers save at 0.65 × rating instead of 0.75.
   - **Result:** about 2.4–2.6 goals a match with sensible play (build up, then shoot), and 1.5–2.0 with random moves.
8. **Life off the pitch** (built, 2026-11-10; numbers provisional, in `lib/game/career/contracts.dart` and `life_actions.dart`):
   - **Calendar:** season 1 is 2026/27. Pre-season starts on 1 July, and league rounds are played on Saturdays from the first Saturday on or after 8 August. Wages are paid on the last day of every month, as each matchday passes and over the summer.
   - **Contracts** (shown on offers and at signing, saved with the club):
     - **Under-18s** at academies or after a trial get a scholarship until 18: (€120 + €60 per club star) a week, times the league's money factor.
     - **Everyone else** earns a share of their market value a year: 10% in Division 1, 8% in Division 2 and 6% in Division 3, with a minimum of €300 a week.
     - **Length:** 4 years in Division 1, 3 below, and 2 after a trial.
   - **Agent** (hire or dismiss on the player screen): +25% on every new contract, a monthly sponsor worth 0.2% of market value (between €200 and €50,000), and offers from abroad, for 15% of wages.
   - **Manager:** one talk a week (each league round, or each story event).
     - **Feedback:** +5 relationship 3 times in 4, otherwise −5.
     - **Requests** need a relationship of 70 or more:
       - **Play my position:** granted 3 times in 5, after which the manager plays you there; −5 if refused.
       - **Raise:** +10–20% on your wage; −10 if refused.
     - **Find a new club:** up to 3 clubs near your level make offers (only from your own country without an agent). Agreeing a move costs 10 relationship, and the move happens when the season ends.
   - **Results:** every round's scores are shown on the season screen.
   - **Matches in progress** are saved after every move: the seed plus your moves rebuild the same match.
6. **Player growth** (built, numbers provisional):
   - **In matches:** every successful move (a goal, keeping the ball or winning it) earns 10 XP for the stat it uses. Shoot trains Shot, Run trains Pace, Pass trains Pass, Dribble trains Dribble, defending moves train Defence, and headers and clearances train Physical.
   - **Levelling up:** a stat goes up by 1 when its XP reaches (stat − 20) × 10, so 350 at 55 and 550 at 75.
   - **Learning rate:** ×1.5 up to age 19, ×1.25 to 23, ×1 to 27, ×0.6 to 30, ×0.3 after that.
   - **Spain's Technical schooling:** ×1.5 for Pass and Dribble.
   - **Each summer the player ages a year:** up to 21, +2 to every skill. From 22 to 29, +1. From 30 to 32, 0 Pace and 0 Physical. From 33, −1 Pace, −1 Physical, −1 Shot and −1 Dribble.
   - **Rough pace:** a young player gains about 8–10 points a season from matches, plus 6 in the summer.

## 11. Match report, league stats and awards (built 2026-11-11, PROVISIONAL numbers)

- **Match report** (after every match): the score with scorers and assists, your goals / assists / moves won, and XP per stat: moves won of moves tried, XP earned (10 per move won × age rate × Spain's perk), and a bar towards the next +1.
- **Simulate**: "Simulate" on the line-ups plays the whole match; the ⏩ button in a match plays the rest (after a confirm). Your moves are picked for you, each as likely as the square of the stat it uses, and they earn XP like moves you choose.
- **Who scores:** in the engine, your Shoot/Nod goals are yours (a teammate gets the assist 65% of the time); goals between your chances go to the shooter, with the passer credited when a pass set it up. Simulated league games give each goal to one of the club's first-choice XI, weighted by role (ST 7, W 6, AM 5, CM 2.5, CB 1.2, FB/DM 1, GK 0) × (Shot/60)^1.5; 70% have an assist, by role (AM/W 6, CM 4, ST 3, FB 2.5, DM 1.5, CB 0.6) × (Pass/60)^1.5. Golden Boot winners come out around 24–36 goals.
- **Every senior division** is simulated to the round you've reached, so any league's stats can be viewed. The first-choice XI plays every game; the keeper gets a clean sheet when his side concedes nothing.
- **Awards** (shown when the season ends, before "Start season N+1"; also viewable mid-season as "the race so far"): Champions, Golden Boot (goals), Playmaker (assists), Golden Glove (keepers' clean sheets), Player of the Season and Young Player of the Season (21 or under). Ties go to fewer games, then the better-rated player.
- **Player of the Season score:** 3 × goals + 2.5 × assists + 2 × clean sheets (GK, CB, FB only) + rating + 0.75 × (clubs + 1 − finish).
- **Youth players:** youth sides are generated fresh each match, so U18 leagues have no individual awards; the awards screen shows your own U18 season numbers and the senior league's awards.

## 12. Real names and youth football (2026-11-12)

- **Real leagues and clubs** (a local game): every country's divisions use their real names (Premier League / Championship / League One, LaLiga / Segunda / Primera Federación, Bundesliga / 2. Bundesliga / 3. Liga, Ligue 1 / Ligue 2 / National, Serie A / B / C, Série A / B / C, Liga Profesional / Primera Nacional / Primera B, J1 / J2 / J3) and real clubs, strongest first (lib/game/world/real_clubs.dart). Divisions stay at 20 clubs, so the Bundesliga, Ligue 1 and their second tiers (18 in reality) take the next clubs in line. Players and managers stay fictional.
- **Who plays youth football:** academy and trial signings play in the U18 league only while 18 or younger; from 19 they play for the club's senior side in its division. Senior contracts always play senior football. (Before this, a trial signing stayed in the U18 league at any age.)

## 13. Logic talents by tier, and weighted XP (2026-11-12, PROVISIONAL numbers)

- **Starting logic talents** (by the tier at creation, Innate bonus included): Poor 0 · Average 1 (a 1-in-3 chance of 2) · Rare 2 · Genius 2. Italy's Tactical brain still guarantees at least 1.
- **Learning one:** the first time the talent score reaches **52** (Average level), **62** (Rare level) and **70**, there's a **50% chance** to learn a random logic talent you don't have. Each milestone is rolled once, ever, after a match or over the summer. Milestones already passed when the player is created don't count.
- **How many you can hold:** 2, or **3 once the talent score is 70+**.
- **XP per move that comes off** (before the age and country multipliers): goal 30 · assist 25 · tackle won (Tackle or Slide) 20 · clearance (Shoot or Nod at their corner) 20 · anything else 10.
- **Assists:** if your last move of a chance is a pass that keeps the ball and a teammate scores in the play straight after, the assist is yours.
- **Effect on growth:** about 55% more match XP than before (a young player's season goes from roughly 8–10 points to 12–15 from matches).
