# Gold Scenarios Catalog

This file is the shared documentation for scenario-style jobs in the gold layer.
Each scenario is documented with tactical rationale, threshold justification, and data integrity notes.

---

## Shared DDL For Scenario Tables

- Table DDL file: `clickhouse/gold/01_create_scenario_tables.sql`

---

## 🧨 Scenario: Demolition (`scenario_demolition`)

### 🎯 Purpose
Identifies finished matches decided by a dominant 3+ goal margin, capturing fixtures where one side was comprehensively outclassed across all phases of play.

### 🧠 Tactical & Statistical Logic

- **The Blowout Threshold (3+ Goal Difference):** A one-goal margin can be a product of variance — a single set piece, a red card, a deflection. A two-goal lead is comfortable but still recoverable. At three goals, the scoreline reflects a structural mismatch rather than an event outlier. The query enforces `abs(home_score - away_score) >= 3` to isolate genuinely one-sided contests.

- **The Absolute Margin (not Ratio):** Goal difference is used rather than a ratio (e.g., 3× goals) because a 3–0 win and a 6–2 win are both demolitions but a ratio filter would exclude the latter. Absolute difference better captures the sustained nature of the dominance over 90 minutes.

- **Final-State Integrity:** The filter `match_finished = 1` is mandatory. Mid-match scores can temporarily show large margins that are later partially reversed. Only completed scorelines are meaningful for demolition classification.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_demolition.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_demolition`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_demolition
```

---

## 🧱 Scenario: Defensive Shutdown Win (`scenario_defensive_shutdown_win`)

### 🎯 Purpose
Finds wins built on elite defensive suppression, where the winning side concedes an extremely low volume of expected goals — flagging matches where the victor essentially denied the opponent any meaningful chance creation pathway.

### 🧠 Tactical & Statistical Logic

- **The Suppression Bar (< 0.3 xG Conceded):** The global average xG conceded per match across top leagues sits between 1.2–1.5. Allowing less than 0.3 xG represents a near-total negation of the opponent's attacking output — roughly equivalent to a single speculative long-range attempt. This threshold isolates performances driven by organised defensive shape, high press, or outright tactical suffocation rather than fortune.

- **Why xG Rather Than Goals Conceded:** A 1–0 win where the opponent hit the post four times is not a defensive masterclass — it is a lucky escape. By anchoring to xG conceded, the scenario captures genuine defensive suppression rather than outcomes inflated by opponent profligacy or goalkeeping heroics.

- **Winner-Only Context:** Draws are excluded (`home_score != away_score`) because a team that concedes 0.2 xG but fails to score has not converted their defensive control into a result. Only finished matches where the low-concession side actually wins qualify, ensuring the suppression produced a tangible outcome.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_defensive_shutdown_win.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_defensive_shutdown_win`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_defensive_shutdown_win
```

---

## 🎭 Scenario: Underdog Heist (`scenario_underdog_heist`)

### 🎯 Purpose
Captures wins where the victor generated little attacking volume and still took all three points — the archetypal smash-and-grab result where a side absorbed pressure, defended deep, and converted minimal opportunities into a decisive scoreline.

### 🧠 Tactical & Statistical Logic

- **Low-Creation Winner (< 1.0 xG):** Generating less than 1.0 xG as a match winner means the winning side produced shots averaging below one expected goal for the entire contest. This is a strong signal of a low-block, counter-attacking, or resolute defensive structure. It rules out cases where a dominant side happened to score early and then sat back.

- **Against-xG Narrative:** The winner must also have lower xG than the opponent. This dual condition — low absolute xG and lower xG than the loser — is the defining fingerprint of a heist. It eliminates results where both teams created little, focusing exclusively on cases where the inferior attacking side upset the side that deserved to win on chances.

- **Outcome Scope:** Only finished non-draw matches qualify. A draw where a side generates 0.6 xG and outperforms their opponent's 1.2 xG is a resilient performance but not a heist — there must be a definitive three-point winner to meet the scenario definition.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_underdog_heist.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_underdog_heist`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_underdog_heist
```

---

## 🎯 Scenario: Dead Ball Dominance (`scenario_dead_ball_dominance`)

### 🎯 Purpose
Identifies winning teams whose victories were powered by set-piece execution — corner routines, free kicks, and rehearsed dead-ball plays — rather than open-play creativity, capturing a tactically distinct pathway to winning matches.

### 🧠 Tactical & Statistical Logic

- **Set-Piece Conversion Floor (2+ Goals):** A single set-piece goal can be a fortunate header from a corner. Two or more set-piece goals in a single match signals intentional tactical exploitation of the dead-ball phase — rehearsed routines, targeted aerial threats, or specialist delivery. The threshold is set at goals, not attempts, because conversion is what matters for match outcome.

- **Situation Scope (`SetPiece`, `FromCorner`, `FreeKick`):** These three situational tags collectively cover the full dead-ball landscape. `SetPiece` captures generic set-play finishes, `FromCorner` isolates corner-derived goals (including second-ball situations), and `FreeKick` covers direct and indirect free-kick finishes. Together they form a complete dead-ball taxonomy.

- **Result Integrity:** Only finished, non-draw matches are included to preserve winner attribution. A team scoring two corners goals in a draw cannot be credited with "dead ball dominance" as an outcome driver — only wins confirm that the dead-ball approach was the decisive tactical lever.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_dead_ball_dominance.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_dead_ball_dominance`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_dead_ball_dominance
```

---

## 🪫 Scenario: Low Block Heist (`scenario_low_block_heist`)

### 🎯 Purpose
Finds wins achieved with very low possession share — capturing results where a side deliberately ceded territorial control, sat deep in a compact defensive structure, and exploited transitions or set pieces to claim all three points against a possession-dominant opponent.

### 🧠 Tactical & Statistical Logic

- **Low-Possession Winner (< 35%):** At sub-35% possession, a team is spending roughly two thirds of their attacking phases in transition or out of possession entirely. This is not incidental — it reflects an intentional tactical posture. Typical low-block setups (classic 4-4-2 or 5-3-2 defensive shapes) routinely post numbers in this range. Below 35% is a meaningful structural signal rather than mere variance.

- **Why Not 40%?:** The 40% threshold captures sides who are simply less dominant in possession — common in roughly half of all matches. Dropping to 35% isolates the genuinely extreme low-possession cases that represent a deliberate tactical choice, not a slight imbalance in territorial control.

- **Clean Outcome Scope:** Only finished non-draw matches are kept. A low-possession draw demonstrates resilience but does not confirm that the low-block strategy was outcome-decisive. Only a win fully validates the approach.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_low_block_heist.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_low_block_heist`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_low_block_heist
```

---

## ♟️ Scenario: Tactical Stalemate (`scenario_tactical_stalemate`)

### 🎯 Purpose
Highlights matches with minimal chance creation from both sides — contests defined by extreme mutual defensive organisation, physical compactness, or outright tactical conservatism, where neither team establishes meaningful threat at any point.

### 🧠 Tactical & Statistical Logic

- **Combined xG Ceiling (< 1.0):** The global average combined xG per match sits around 2.5–3.0. A match total below 1.0 represents a profound failure of both teams to generate quality chances — fewer expected goals across the entire 90 minutes than a single penalty (0.76 xG). This threshold captures only the most extreme cases of mutual chance denial.

- **Combined Rather Than Individual Caps:** Requiring both teams to be below a threshold risks losing matches where one team generates 0.8 xG and the other 0.3 xG — still a very low-chance contest. Summing the xG ensures the filter measures total match opportunity volume rather than one team's output in isolation.

- **Full-Match Validity:** The filter uses `period = 'All'` and finished matches only. Half-time data would skew results for tight matches that open up late, and unfinished matches may have curtailed the tactical picture before the stalemate fully resolved.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_tactical_stalemate.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_tactical_stalemate`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_tactical_stalemate
```

---

## 🔁 Scenario: Great Escape (`scenario_great_escape`)

### 🎯 Purpose
Identifies full comebacks where the eventual match winner was actively losing at the 60-minute mark — capturing the rarest and most psychologically significant form of result reversal in football.

### 🧠 Tactical & Statistical Logic

- **Minute-60 Deficit Rule:** The 60-minute mark is chosen deliberately. A team trailing at 60 minutes has 30 or more minutes to recover — a meaningful but not impossible window. Earlier cut-offs (45') risk capturing teams who were simply losing at half-time and equalised quickly. Later cut-offs (75'+) approach last-gasp territory, which is a separate scenario. Minute 60 represents a genuine structural deficit requiring sustained comeback effort.

- **Score State Reconstruction:** A goals-at-60 CTE reconstructs the exact scoreline at minute 60 by summing goals scored up to that timestamp. This avoids relying on half-time scores or period-level data, which lack the temporal precision needed for this scenario.

- **True Comeback Constraint:** The query requires that the team trailing at minute 60 ultimately wins the match (not merely draws). A draw after trailing is a positive but different narrative. The "great escape" framing requires a complete result reversal — from losing to winning — making it the most demanding comeback definition in the scenario library.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_great_escape.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_great_escape`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_great_escape
```

---

## 🎬 Scenario: One Man Army (`scenario_one_man_army`)

### 🎯 Purpose
Finds individual carrying performances where a single player delivered extreme direct attacking output — providing a disproportionate share of their team's goal production or chance creation within a single match.

### 🧠 Tactical & Statistical Logic

- **Direct Contribution Trigger (Goals ≥ 2 or Assists ≥ 2):** A brace signals that one player is the primary attacking outlet rather than a cog in a collective system. Two assists means the player has directly created two goals — again, a disproportionate individual contribution relative to typical match contribution distributions. The OR condition captures different player archetypes: pure finishers versus creative playmakers.

- **Why OR, Not AND?:** Requiring both two goals and two assists would be extraordinarily rare and would miss the majority of one-player dominant performances. The OR logic acknowledges that carrying can manifest either as clinical finishing or as elite chance creation — both are valid forms of individual match dominance.

- **Finished-Match Scope:** Only completed matches are included. A player with two goals at minute 60 before injury or abandonment represents a partial performance — the scenario is designed to capture full-match carrying performances where the individual output ultimately contributed to a final result.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_one_man_army.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_one_man_army`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_one_man_army
```

---

## ⏱️ Scenario: Last Gasp (`scenario_last_gasp`)

### 🎯 Purpose
Detects wins decided by a late goal that fundamentally altered the match state — capturing the highest-pressure, highest-stakes moments in football where a goal changes not just the score but the entire narrative of the contest.

### 🧠 Tactical & Statistical Logic

- **Late-Decider Window (≥ 85 Minutes):** The 85th minute represents the conventional threshold for "late drama" in football broadcasting and analysis. A team conceding at minute 85 or later has mathematically insufficient time to recover in normal play. Goals in this window carry the maximum psychological weight for both teams and produce the most decisive narrative outcomes.

- **State-Change Requirement:** The qualifying goal must occur when the scoring side is drawing or losing (`score_before <= opponent_score_before`). This is the critical differentiating condition. A 3–0 winner scoring in the 88th minute to make it 4–0 is not a last gasp — it is a routine late goal. The state-change filter ensures only goals that actively win or equalise a match in the final window are captured.

- **Why Score State Reconstruction?:** Relying solely on final scoreline would not reveal whether the winning goal was decisive or merely cosmetic. The CTE reconstructing score state before each goal is essential to validating that the late goal changed the match outcome rather than simply adding to an existing lead.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_last_gasp.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_last_gasp`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_last_gasp
```

---

## 🧤 Scenario: Shot Stopper (`scenario_shot_stopper`)

### 🎯 Purpose
Surfaces goalkeepers who produced major shot-stopping value in finished matches — identifying keepers who faced a sustained volume of on-target threat and actively prevented multiple expected goals from being realised.

### 🧠 Tactical & Statistical Logic

- **High xGOT Prevention (≥ 1.5 xGOT Saved):** xGOT (expected goals on target) measures the probability of shots that actually reached the keeper resulting in goals, accounting for placement and power. A keeper saving 1.5 xGOT has denied roughly 1.5 goals that, given their shot quality, would statistically have beaten an average keeper. This threshold filters out comfortable clean sheets against low-quality attempts.

- **Save Event Integrity:** Only on-target, non-goal, non-own-goal shots with non-null xGOT values contribute to the keeper's total. This ensures the xGOT accumulation reflects genuine shot-stopping decisions by the goalkeeper rather than blocked shots, own goals, or data gaps that would distort the metric.

- **Keeper Attribution by Match:** Goalkeepers are grouped by match and team to attribute the xGOT correctly. In most matches only one keeper plays the full game, but the grouping is necessary to handle substitution edge cases where two keepers share minutes in the same match.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_shot_stopper.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_shot_stopper`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_shot_stopper
```

---

## ⚔️ Scenario: War Zone (`scenario_war_zone`)

### 🎯 Purpose
Flags finished matches with extreme physical or disciplinary intensity — contests characterised by an unusually high foul count, excessive bookings, or multiple dismissals, representing a breakdown of match control by either players or officials.

### 🧠 Tactical & Statistical Logic

- **Any Intensity Trigger (OR logic):** The scenario uses a permissive OR rather than a compound AND because extreme intensity can manifest through different channels. Some matches are foul-heavy but card-light due to referee leniency. Others have fewer fouls but multiple flash-point dismissals. Capturing all three thresholds independently (`combined_fouls > 35` or `combined_yellows >= 5` or `combined_reds >= 2`) ensures no form of match volatility is excluded.

- **Foul Threshold (> 35 Combined):** The average combined foul count in top leagues is typically 22–27. Exceeding 35 fouls places a match roughly two standard deviations above the mean — a level that signals genuine physical aggression, deliberate tactical fouling, or poor discipline from one or both sides. Combined fouls captures bilateral intensity rather than penalising only the more physical team.

- **Yellow Card Threshold (≥ 5 Combined):** Five or more yellows in a match is the threshold at which the disciplinary environment dominates the tactical picture. Referees typically issue two to three yellows per game on average. Five or more indicates escalating confrontation, persistent fouling, or significant dissent.

- **Red Card Threshold (≥ 2 Combined):** A single red card is notable but still a relatively contained event. Two red cards — regardless of whether they fall on the same team or one each — indicate a fundamentally destabilised contest.

- **Full-Match Aggregate Integrity:** All filters use `period = 'All'` team aggregates with null-safe aggregation to ensure consistency against incomplete period-level data.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_war_zone.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_war_zone`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_war_zone
```

---

## 🎯 Scenario: Clinical Finisher (`scenario_clinical_finisher`)

### 🎯 Purpose
Finds elite finishing spikes where a player scored multiple goals from minimal shots and low expected goal volume — capturing the purest expression of individual finishing efficiency, where shot placement and composure dramatically exceeded what the chances themselves warranted.

### 🧠 Tactical & Statistical Logic

- **Multi-Goal Gate (Goals ≥ 2):** Two goals from very few shots is the defining signal. A brace from three shots is a vastly different profile from a hat-trick from eight shots. Anchoring the event at two goals ensures the scenario captures genuine efficiency rather than volume-based scoring.

- **Shot Volume Ceiling (Total Shots ≤ 3):** Three shots or fewer means the player had almost no margin for error. At this volume, a player cannot rely on accumulating chances and forcing a conversion — each shot carries maximum individual weight. This threshold eliminates prolific but wasteful finishing spells and isolates cases where every trigger pull counted.

- **xG Volume Ceiling (Combined xG < 1.0):** Even within the three-shot cap, some shots could be high-probability chances (e.g., two penalty-level opportunities). The xG cap below 1.0 ensures the player was genuinely working against the numbers — scoring two goals from opportunities that collectively warranted less than one. This is the signature of clinical finishing over expected variance.

- **Shot Data Hygiene:** Own goals and shots with null xG are excluded. Own goals are not finishing events. Null xG shots cannot be evaluated for clinical efficiency and would distort the combined xG calculation.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_clinical_finisher.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_clinical_finisher`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_clinical_finisher
```

---

## 🎲 Scenario: Russian Roulette (`scenario_russian_roulette`)

### 🎯 Purpose
Tracks penalty-heavy matches with multiple high-variance pressure moments — contests shaped by the randomness of the penalty spot, where the psychological and probabilistic dynamics of spot kicks become central to the match narrative.

### 🧠 Tactical & Statistical Logic

- **Penalty Volume Floor (≥ 2 Total):** A single penalty is a significant event but not a defining structural feature of a match. Two or more penalties indicate that the referee awarded spot kicks multiple times — either to both teams, or twice to the same team. This volume signals that the match was genuinely shaped by penalty dynamics, not merely touched by a single incident.

- **Situation Filtering Precision:** Only shots with `situation = 'Penalty'` are counted, and own goals are explicitly excluded. Own goals cannot be penalties by definition, but including them in situation filters could cause miscounts depending on data tagging.

- **Finished-Match Filter:** Only completed matches are included. A match abandoned after a penalty is awarded but before full time does not represent a complete penalty-shaped contest. The `match_finished = 1` constraint ensures the full narrative arc — including the eventual outcome — is intact.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_russian_roulette.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_russian_roulette`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_russian_roulette
```

---

## ⚙️ Scenario: Efficiency Machine (`scenario_efficiency_machine`)

### 🎯 Purpose
Identifies winning teams who paired a very low shot volume with an exceptionally high quality per shot — capturing results where tactical discipline in shot selection, rather than volume pressing, was the primary attacking mechanism.

### 🧠 Tactical & Statistical Logic

- **Shot Volume Ceiling (≤ 5 Total Shots for the Winner):** Five shots for a winning team is near the statistical floor for any match winner. Most winning teams take 10–15 shots. Restricting to five or fewer forces the scenario to identify sides whose entire attacking output was concentrated into a tiny number of very deliberate attempts.

- **Average xG Per Shot Floor (> 0.25):** An average xG of 0.25 per shot is roughly equivalent to every shot being a moderately good penalty-area chance. The global average xG per shot is closer to 0.10–0.12. Exceeding 0.25 on average means the winning team exclusively manufactured high-quality chances — no speculative long shots, no blocked attempts from distance — only shots from dangerous positions.

- **Quality-Controlled Shot Set:** Own goals and null xG shots are excluded from the per-shot quality calculation. Own goals are not the result of shooting decisions and would artificially distort average xG. Null xG shots cannot be evaluated and are excluded to prevent denominator inflation.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_efficiency_machine.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_efficiency_machine`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_efficiency_machine
```

---

## 🚫 Scenario: Big Chance Killer (`scenario_big_chance_killer`)

### 🎯 Purpose
Highlights goalkeepers who repeatedly denied high-quality on-target chances within a single match — identifying keepers who intervened decisively against the most dangerous shots rather than simply facing and saving a high volume of routine attempts.

### 🧠 Tactical & Statistical Logic

- **Big-Chance xGOT Threshold (xGOT > 0.4 per Save):** An xGOT of 0.4 represents a shot that, based on placement and power, had a 40% chance of being a goal against an average keeper. This is a high-quality on-target attempt by any measure. A one-on-one shot well-placed to the corner might sit at 0.5–0.7 xGOT. By filtering to shots above 0.4, the scenario isolates genuinely dangerous moments rather than comfortable central saves.

- **Denial Threshold (≥ 2 Big-Chance Saves):** A single big save can be a fortunate positioning moment. Two or more big-chance denials in the same match confirms the goalkeeper was repeatedly tested by high-quality efforts and repeatedly produced saves that beat expectation. This separates luck from sustained elite shot-stopping.

- **Event Purity Filters:** Only on-target, non-goal, non-own-goal shots with valid xGOT values are counted. On-goal shots that resulted in goals cannot be credited as saves. Own goals involve no keeper intervention. Null xGOT shots cannot be validated against the threshold. Together these filters ensure only genuine goalkeeper saves against measurably dangerous attempts are counted.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_big_chance_killer.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_big_chance_killer`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_big_chance_killer
```

---

## 🟥 Scenario: Ten Men Stand (`scenario_ten_men_stand`)

### 🎯 Purpose
Finds teams that avoided defeat despite receiving a red card during the match — capturing the rare tactical and psychological achievement of sustaining a competitive result after being reduced to ten men for a meaningful portion of the game.

### 🧠 Tactical & Statistical Logic

- **Red-Card Resilience Rule:** The red-carded side must finish the match with at least a draw. A team that receives a red card and loses is the modal outcome — statistically, red-carded teams win only around 10–15% of matches and draw a further 20%. Both wins and draws after a red card qualify, because avoiding defeat with ten men represents a meaningful achievement regardless of whether it results in a point or three.

- **First-Red Reconstruction via CTE:** Not all red cards in the data occur early enough to genuinely affect match dynamics. A red card at minute 89 has a fundamentally different impact than one at minute 30. The CTE identifying the first red-card event per team per match preserves the original timing context, which is available to downstream analysis even though the current scenario qualifies purely on outcome. This architecture allows future enrichment with timing-based filters.

- **Home/Away Attribution Integrity:** The `is_home` flag on each red card event is used to correctly map the dismissed team to their final score (`home_score` or `away_score`), ensuring the result check is applied to the correct team rather than the match as a whole.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_ten_men_stand.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_ten_men_stand`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_ten_men_stand
```

---

## 🚀 Scenario: Progressive Powerhouse (`scenario_progressive_powerhouse`)

### 🎯 Purpose
Identifies outfield players who combined safe ball circulation with meaningful forward progression and carrying threat — the profile of a complete progressive midfielder or wide player who advances the team both through passing and through driving runs.

### 🧠 Tactical & Statistical Logic

- **Pass Accuracy Gate (≥ 85%):** At 85% accuracy, a player is maintaining possession effectively enough to serve as a reliable link in the build-up chain. Dropping below this threshold means the player is losing the ball at a rate that undermines their progressive value. The 85% floor avoids rewarding aggressive forward passers who generate as many turnovers as progressive actions.

- **Final-Third Pass Volume (≥ 8 Passes into the Final Third):** Eight progressive passes into the attacking third in a single match is a high-activity threshold. It ensures the player is not merely a safe circulator in their own half but is actively responsible for penetrating the opponent's defensive block through passing. This is the "progression" component of the scenario.

- **Successful Dribbles (≥ 3):** Dribbling success adds the carrying dimension. Three completed dribbles separates a player who occasionally drives forward from one who is an active ball-carrier threatening defensive lines. Combined with the passing thresholds, this requirement captures the "two-dimensional" progressive profile — both passing and running past opponents.

- **Role Integrity:** Goalkeepers are excluded. A goalkeeper can post high pass accuracy and even high pass counts, but their progressive value through dribbling and final-third passing is not the outfield role this scenario targets.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_progressive_powerhouse.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_progressive_powerhouse`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_progressive_powerhouse
```

---

## 🧪 Scenario: Sterile Control (`scenario_sterile_control`)

### 🎯 Purpose
Finds matches where one side dominated control metrics — possession and passing volume — but failed to convert that dominance into meaningful attacking threat, capturing the tactical failure of "having the ball without doing anything with it."

### 🧠 Tactical & Statistical Logic

- **Control Dominance Bar (> 65% Possession and > 600 Passes):** Both conditions must be met simultaneously. 65% possession is a strong dominance signal — the controlling side had the ball for nearly two-thirds of the match. The 600-pass threshold ensures this was active, repetitive circulation rather than long-ball or direct possession. Together, these filters identify teams that genuinely dominated the territorial and touch-count dimensions of the game.

- **Sterility Condition (xG < 0.75 or Shots on Target < 2):** The OR logic captures two different forms of creative failure. A team can have low xG because they never create quality chances. Alternatively, they can generate some low-quality shots but never force the goalkeeper into serious action (< 2 shots on target). Either condition represents a failure to convert possession into genuine goalscoring threat.

- **Why Combine Passes with Possession?:** Possession percentage alone can be inflated by a single team's deliberate slowing of the game late in a half. The 600-pass floor ensures the control was active and sustained throughout the match, not a product of time-wasting.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_sterile_control.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_sterile_control`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_sterile_control
```

---

## 🛡️ Scenario: Defensive Masterclass (`scenario_defensive_masterclass`)

### 🎯 Purpose
Captures dominant individual defensive displays characterised by elite aerial dominance, high clearance volumes, and immaculate discipline — the profile of a centre-back or defensive midfielder who won every aerial contest, cleared every danger, and never conceded a foul.

### 🧠 Tactical & Statistical Logic

- **Aerial Dominance (100% Success on ≥ 5 Attempts):** Five aerial duels in a match is a meaningful sample for a defensive player — it reflects active involvement in the physical contest. Winning all five at 100% success demonstrates aerial superiority rather than lucky single interventions. The minimum attempt floor prevents a player winning one header from qualifying on a technicality.

- **Clearance Volume (≥ 5 Clearances):** Clearances measure how often a defender had to physically remove the ball from danger, typically inside their own penalty area. Five clearances in a match is an active defensive involvement threshold. Combined with aerial dominance, this paints a picture of a physically commanding presence who dealt with everything in the air and on the ground.

- **No-Foul Constraint (`fouls_committed = 0`):** Winning aerial duels and clearing danger without conceding a single foul is the distinction between a commanding defender and a physical but reckless one. Zero fouls means the player dominated their physical battles within the rules — control without recklessness is the hallmark of genuine defensive masterclass performances.

- **Outfield Player Restriction:** Goalkeepers are excluded because their aerial involvement (claiming crosses) and clearances are governed by different positional logic. The scenario targets the elite defensive outfield profile.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_defensive_masterclass.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_defensive_masterclass`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_defensive_masterclass
```

---

## 🎼 Scenario: Metronome (`scenario_metronome`)

### 🎯 Purpose
Identifies tempo controllers who combined elite touch volume with passing precision and complete ball security — the archetypal deep-lying playmaker or holding midfielder who orchestrates the team's rhythm without ever surrendering possession under pressure.

### 🧠 Tactical & Statistical Logic

- **Touch Volume (≥ 100 Touches):** One hundred touches places a player among the most ball-involved in any match. For context, 100 touches in a 90-minute game represents receiving or carrying the ball on average every 54 seconds. This threshold captures true central orchestrators — players the team consistently routes the ball through — rather than peripheral performers who occasionally appear in the passing chain.

- **Passing Precision (≥ 92% Accuracy):** 92% accuracy is significantly above the 80–85% range typical of high-volume central midfielders. At this level, the player is operating as an almost-error-free circulation node — their passes reach their target nearly ten times for every miss. This precision, combined with high touch volume, defines the metronome role.

- **Ball Security (Not Dribbled Past, 100% Dribble Success or No Dribble Attempts):** The metronome cannot be a liability when pressed. The ball security layer requires the player was never successfully dribbled past in the match. Additionally, if they attempted any dribbles, they must have completed all of them. A player receiving 100 touches who is regularly dispossessed is not a metronome — they are a ball-magnet who loses it. Zero losses under pressure is the defining security requirement.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_metronome.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_metronome`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_metronome
```

---

## 🔋 Scenario: High Intensity Engine (`scenario_high_intensity_engine`)

### 🎯 Purpose
Finds non-goalkeeper, non-center-back outfield players sustaining elite two-way work-rate across meaningful minutes by combining defensive volume with per-90 event density.

### 🧠 Tactical & Statistical Logic

- **Defensive Volume Floor (≥ 12):** The scenario computes `defensive_volume = tackles_won + interceptions + recoveries` (with null-safe coalescing). This captures both duel-winning activity and anticipation-based regains, preventing single-metric bias.

- **Engine Proxy via Event Density per 90:** `event_density_per90 = (touches + defensive_actions) / minutes_played * 90` provides an intensity proxy that rewards players who stay constantly involved on and off the ball, normalized for minutes.

- **Meaningful Sample (≥ 60 Minutes):** The minutes floor limits short-burst outliers and focuses on sustained match-level intensity.

- **Positional Integrity:** Goalkeepers are excluded via `p.is_goalkeeper = 0`, and starter-position filtering excludes `position_id IN (1, 2, 3, 4)` to remove GK/SW/CB profiles and keep the scenario focused on high-engine non-central-defender roles.

- **Context-Rich Output Fields:** The scenario includes match context (`league_name`, teams, scoreline, match time), player identity (`player_id`, `team_id`, starter position fields), and supporting duel/passing/xG metrics for downstream interpretation.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_high_intensity_engine.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_high_intensity_engine`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_high_intensity_engine
```

---

## 🧭 Scenario: Box To Box General (`scenario_box_to_box_general`)

### 🎯 Purpose
Surfaces balanced outfield performances where a single player contributed meaningfully in both the attacking and defensive phases within the same match — the complete midfield profile that impacts both penalty areas rather than excelling in only one phase.

### 🧠 Tactical & Statistical Logic

- **Attacking Threat (≥ 1 Shot on Target and ≥ 3 Touches in Opponent Box):** One shot on target confirms the player was a credible attacking threat who forced the goalkeeper to act. Three touches in the opponent's box adds a volume component — the player was consistently penetrating the defensive block, not just arriving for one late shot. Together these two conditions confirm genuine attacking area involvement.

- **Defensive Contribution (≥ 2 Tackles Won):** Two successful tackles per match is an active defensive involvement floor. It ensures the player was repeatedly engaging in defensive duels and winning them, rather than simply being present in defensive positions. Tackles won specifically (not attempted) ensures quality of defensive output, not just willingness to engage.

- **Possession Quality Baseline (Pass Accuracy ≥ 80%):** The 80% accuracy floor ensures the box-to-box output is delivered within a foundation of possession quality. A player sprinting end-to-end but losing the ball regularly is not a general — they are a headless runner. Pass accuracy at 80% is the minimum threshold for a player to be considered a reliable possession link between their defensive and attacking contributions.

- **Why These Three Together?:** Each condition in isolation is insufficient. A player can score and tackle but be a poor passer. A high-pass-accuracy player who tackles but never enters the box is a deep midfielder. Only the conjunction of all three captures the true two-way, full-pitch contribution the scenario intends to identify.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_box_to_box_general.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_box_to_box_general`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_box_to_box_general
```

---

## ✈️ Scenario: Away Day Masterclass (`scenario_away_day_masterclass`)

### 🎯 Purpose
Finds away wins defined by territorial and chance-quality superiority — capturing the rarest and most complete form of away performance, where the visiting team not only won but comprehensively outplayed the hosts across both possession and attacking metrics.

### 🧠 Tactical & Statistical Logic

- **Away Control Bar (> 65% Possession):** Home teams win possession battles in the majority of matches due to crowd-driven pressure and territorial comfort. An away team posting above 65% possession has entirely reversed the expected dynamic — dominating time-on-ball in a hostile environment. This threshold is deliberately high to capture only the most comprehensive forms of away dominance.

- **Chance Quality Confirmation (Away xG > Home xG):** High away possession alone does not confirm dominance — a side can have the ball frequently while producing sterile, horizontal circulation. By requiring the away team's xG to also exceed the home team's xG, the scenario confirms that the possession dominance translated into genuine, superior chance creation. This dual filter eliminates sterile away possession wins and confirms quality-of-control rather than just time-of-ball.

- **Result Confirmation:** Only away wins are included. A dominant away display that ends in a draw — however impressive statistically — does not constitute an "away day masterclass" in the result sense. The win is the final validation that the territorial and chance quality superiority was ultimately decisive.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_away_day_masterclass.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_away_day_masterclass`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_away_day_masterclass
```

---

## 🪄 Scenario: Key Pass King (`scenario_key_pass_king`)

### 🎯 Purpose
Identifies elite individual creators who combined high chance-creation volume with the shot quality of the opportunities they generated — capturing playmakers whose key passes do not simply register as "touches before a shot" but genuinely produce dangerous, goal-threatening moments.

### 🧠 Tactical & Statistical Logic

- **Creation Volume (≥ 3 Chances Created):** Three chances created in a single match is a high-activity threshold for an individual. The average top-flight player creates roughly 0.5–1.0 chances per 90 minutes. Reaching three in a single match places the player well above the distribution, confirming they are actively and repeatedly finding teammates in shooting positions.

- **Quality Threshold (Expected Assists > 0.8):** Expected assists (xA) measure the combined probability that each key pass directly leads to a goal. An xA above 0.8 means the player's passes created chances worth collectively almost one expected goal — not empty square-ball pre-shots but genuinely dangerous delivery into threatening positions. This is the critical differentiator between a high-volume creator of low-quality chances and a true Key Pass King.

- **Why Volume AND Quality?:** xA alone could be met by a single exceptional through-ball (e.g., one chance at 0.85 xA). Combining volume with quality ensures the scenario captures sustained creative dominance — multiple dangerous opportunities generated, not one fortunate delivery. The joint condition defines elite-level playmaking rather than single-moment brilliance.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_key_pass_king.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_key_pass_king`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_key_pass_king
```

---

## 🃏 Scenario: Wildcard (`scenario_wildcard`)

### 🎯 Purpose
Finds substitutes who made immediate direct attacking impact after coming off the bench — capturing the impact-substitute archetype: players sent on mid-match who change the game through direct goal involvement rather than anonymous accumulation of minutes.

### 🧠 Tactical & Statistical Logic

- **Impact Trigger (Goal or Assist After Substitution):** The threshold requires at least one goal or assist registered after the player's substitution time. This ties the contribution directly to their time on the pitch rather than any early-match involvement as a starter. A goal or assist — rather than shots, key passes, or xG — ensures the player delivered a concrete, direct attacking outcome.

- **Substitution Integrity (`substitution_time` Must Be Present):** The `substitution_time` field is required to be non-null. Without it, the scenario cannot confirm the player entered as a substitute rather than starting the match. This filter preserves the true bench-to-impact narrative — the player was not on the pitch from the start, was introduced at a specific moment, and immediately affected the match.

- **Why Not Shots or xG?:** Substitutes who arrive, take two shots, and miss both contribute positively to xG but have not changed the game's outcome. Restricting to goals and assists ensures only decisive direct contributions qualify, separating the genuine super-sub from the well-intentioned but ultimately ineffective late cameo.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_wildcard.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_wildcard`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_wildcard
```

---

## 🧢 Scenario: Lead By Example (`scenario_lead_by_example`)

### 🎯 Purpose
Highlights captains on winning teams who delivered above-average individual impact alongside direct attacking output — the player who wore the armband and validated their leadership with a match-winning contribution, not merely collective effort.

### 🧠 Tactical & Statistical Logic

- **Leadership Output Filter (Captain + Winning Team + Goal or Assist):** The conjunction of all three conditions is deliberate. A captain on a winning team who played well but scored or assisted nothing is a competent leader. A substitute who scores with no leadership responsibility is a different scenario entirely. Only captains who simultaneously led their team to victory and delivered a direct goal involvement qualify — output leadership, not just positional authority.

- **Quality Relative to Baseline (Rating Above Global Average):** The player's FotMob rating must exceed the average rating across the entire `bronze.player` table. This ensures the captain's performance was objectively above baseline across all other metrics, not just the counting stats of goals and assists. A captain who scored an own goal and then added a lucky deflection but rated poorly does not meet the spirit of the scenario — quality must be confirmed globally.

- **Why Win Required?:** Captains who deliver goals or assists in losing matches demonstrate individual quality but not the leadership dimension of carrying their team. The win condition links the captain's output to a team outcome, framing their contribution as consequential leadership rather than consolation impact.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_lead_by_example.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_lead_by_example`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_lead_by_example
```

---

## 🌟 Scenario: Young Gun (`scenario_young_gun`)

### 🎯 Purpose
Finds high-impact young starters who delivered outright attacking contributions while rating above the overall player baseline — capturing development breakthroughs where a teenager or young adult outperformed experience to become a decisive match factor.

### 🧠 Tactical & Statistical Logic

- **Youth Gate (Age ≤ 21):** Twenty-one is the conventional upper boundary for "young player" tracking in professional football, aligning with under-21 international age cutoffs and academy graduation thresholds. Players at this age who are starting and impacting top-flight matches are demonstrating precocious development — the scenario targets this demographic specifically.

- **Direct Output (Goal or Assist):** Requiring a goal or assist rather than shots, touches, or rating alone ensures the young player delivered a match-altering contribution, not merely a competent performance. Youth breakthroughs are most meaningful when they move the scoreboard.

- **Positive Minutes (Minutes Played > 0):** A guard against edge cases where a player is listed in the lineup data but suffered an immediate injury or did not take the pitch. Only players who genuinely participated qualify.

- **Above-Average Quality (Rating Above Overall Average):** The rating condition mirrors the Lead By Example scenario — the player must rate above the global average from `bronze.player`. This distinguishes a quality breakthrough from a young player who happened to score with their only meaningful touch while otherwise performing below par.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_young_gun.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_young_gun`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_young_gun
```

---

## 🥊 Scenario: Second Half Warriors (`scenario_second_half_warriors`)

### 🎯 Purpose
Detects teams that were trailing at half-time but recovered to avoid defeat — capturing second-half psychological and tactical turnarounds where a team halted the momentum of an opponent who had controlled the first 45 minutes.

### 🧠 Tactical & Statistical Logic

- **Halftime Deficit Reconstruction:** The scenario reconstructs first-half scorelines by summing all goals scored within the `FirstHalf` period from the `bronze.goal` table. This produces an accurate halftime score state without relying on any pre-computed or stored half-time data that may be incomplete in edge cases (e.g., halftime goals scored in added time).

- **Recovery Constraint (Trailing at HT, Level or Ahead at FT):** The trailing team at half-time must finish the match without losing — either drawing or winning. A team that concedes at half-time and then loses 3–1 having been 1–0 down at HT is not a second-half warrior. The scenario specifically requires that the deficit situation at 45 minutes was reversed or neutralised by full-time.

- **Draw and Win Both Qualify:** Unlike scenarios that require a win for full classification, a draw after trailing at half-time counts here. Drawing after being behind at the break requires sustained second-half pressure and demonstrates genuine recovery capacity, even without taking all three points.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_second_half_warriors.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_second_half_warriors`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_second_half_warriors
```

---

## 🌪️ Scenario: Against The Grain (`scenario_against_the_grain`)

### 🎯 Purpose
Find elite passing-control performances delivered under adverse possession context, where a player drives progression and quality despite their team being out-possessed.

### 🧠 Tactical & Statistical Logic

- **Volume + Precision Gate (accurate passes ≥ 50, pass accuracy ≥ 95, minutes ≥ 60):** Filters for sustained high-quality ball circulation rather than small-sample pass completion.
- **Adverse Context Gate (team possession < 45%):** Requires the player’s team to be out-possessed, so control output is produced against match flow.
- **Possession-Gap Modeling:** Captures team possession, opponent possession, and possession gap to quantify adversity level.
- **Against-The-Grain Score:** Combines passing volume/accuracy, final-third progression, long-ball quality, and chance creation, then boosts score by possession adversity.
- **Contextual Productivity Layer:** Adds passes-per-possession unit, touches, dribbling, goals/assists, and xG/xA to profile broader contribution.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_against_the_grain.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_against_the_grain`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_against_the_grain
```

---

## 🟨 Scenario: Unpunished Aggression (`scenario_unpunished_aggression`)

### 🎯 Purpose
Flags matches with heavy combined foul counts but unusually light disciplinary punishment — capturing games where physical aggression was consistently rewarded by referee leniency, revealing a mismatch between the intensity of the contest and its formal disciplinary record.

### 🧠 Tactical & Statistical Logic

- **Aggression Signal (Total Fouls ≥ 35):** Thirty-five combined fouls is significantly above the typical match average of 22–27 across top leagues. At this level, the match is characterised by persistent physical interruptions — tactical fouling, aggressive pressing that leads to fouls, or a physically confrontational atmosphere. This threshold is high enough to filter out moderately physical matches and isolate genuine outlier intensity.

- **Discipline Paradox (Total Yellows ≤ 2):** In an average match, referees issue two to three yellow cards. In a match with 35+ fouls, the expected yellow count would be meaningfully higher — perhaps four to six. Two or fewer yellows in a high-foul match signals a referee who is either deliberately lenient, applying a "let them play" approach, or losing control of the disciplinary narrative. The gap between aggression and cards is the defining characteristic of this scenario.

- **Full-Match Aggregate Integrity:** All filters use `period = 'All'` team aggregates with null-safe coalescing. Using period-level sub-aggregates risks missing fouls or cards that may be attributed to individual half records rather than the full match total, particularly in leagues with inconsistent period-level data coverage.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_unpunished_aggression.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_unpunished_aggression`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_unpunished_aggression
```

---

## 🔥 Scenario: Pressing Masterclass (`scenario_pressing_masterclass`)

### 🎯 Purpose
Finds wins built on elite team-level ball-winning intensity — matches where the winning side's pressing volume was exceptional and directly correlated with the match outcome, confirming that high defensive intensity was the primary tactical driver of victory.

### 🧠 Tactical & Statistical Logic

- **Recovery Threshold (≥ 65 Recoveries):** Sixty-five team recoveries in a single match places the pressing side in the top percentile of defensive pressing output. Top pressing teams in data like PPDA analysis typically show sustained ball-winning events across the pitch. Sixty-five recoveries means the winning team was winning the ball back at an average of roughly one recovery every 83 seconds — a relentless tempo that denies the opponent settled possession phases.

- **Interception Threshold (≥ 15 Interceptions):** Fifteen team interceptions per match is well above the typical 8–12 range for high-intensity sides. Interceptions require both anticipation and positioning — the pressing team must read the pass before it is played. This volume confirms that the pressing was not merely high-effort running but tactically coherent pressing with coordinated pressure and coverage shadows.

- **Outcome Coupling — Pressing Side Must Win:** The thresholds only qualify if the same side that meets the pressing metrics is also the match winner. This is the critical coupling condition. High pressing that ends in a loss or draw demonstrates intensity but not effectiveness. Linking the metric to the winning team confirms that the pressing translated into the result — a direct causal link between the intensity of the pressing and the match outcome.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_pressing_masterclass.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_pressing_masterclass`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_pressing_masterclass
```

---

## 🛡️ Scenario: Elite Shot Stopper (`scenario_elite_shot_stopper`)

### 🎯 Purpose
Identifies primary goalkeepers who have delivered match-defining performances characterised by maintaining a clean sheet despite facing a high volume of shots and a high Expected Goals (xG) against — the clearest data signal of a goalkeeper actively outperforming the quality of opportunities they faced.

### 🧠 Tactical & Statistical Logic

- **The "Against the Odds" Bar (≥ 2.0 xG Faced):** Conceding 2.0+ xG implies the opponent generated enough quality chances to score at least twice. Securing a clean sheet under these conditions indicates the keeper significantly outperformed shot quality expectations — not merely that the opponents missed open goals, but that the keeper actively denied chances above replacement-level probability. This threshold filters out comfortable clean sheets against low-threat opponents.

- **The High-Action Floor (≥ 7 Saves):** Many clean sheets are low-action outcomes where the keeper makes two or three routine interventions. A 7-save game means the goalkeeper was repeatedly tested — roughly one demanding action every 13 minutes. This floor isolates fixtures where the goalkeeper was actively and repeatedly decisive, not simply a passenger behind a solid defensive structure.

- **Primary Goalkeeper Integrity:** The query restricts to keeper rows with `minutes_played >= 80` in `bronze.player` to identify the primary custodian. Save totals are pulled from `bronze.period` team-level fields (`keeper_saves_home` / `keeper_saves_away`) for the `period = 'All'` aggregate, ensuring full-match accuracy. This combination prevents partial-game keepers or backup appearances from distorting the match-level attribution.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_elite_shot_stopper.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_elite_shot_stopper`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_elite_shot_stopper
```

---

## 🕳️ Scenario: Hollow Dominance (`scenario_hollow_dominance`)

### 🎯 Purpose
Find matches where one side lays siege with elite shot and xG volume, but still fails to score more than once or win.

### 🧠 Tactical & Statistical Logic

- **Siege Volume Gate (shots ≥ 20, xG ≥ 2.5):** Requires both extreme shot count and high chance quality for the siege side.
- **Failure Conversion Constraint (score ≤ 1 and did not win):** Ensures the dominant attacking side still fails to convert control into a win.
- **Dual-Side Siege Detection:** Handles both home and away siege cases with explicit side/team labels (`siege_team`, `siege_side`).
- **Underperformance Lens:** Adds siege-specific xG, missed big chances, and xG underperformance (`siege_xg - goals`) to quantify finishing failure.
- **Chance-Profile Context:** Includes on-target shots, inside-box shots, blocked shots, open-play xG, and non-penalty xG splits.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_hollow_dominance.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_hollow_dominance`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance
```

---

## ⚡ Scenario: Touchline Terror (`scenario_touchline_terror`)

### 🎯 Purpose
Find outfield isolation specialists who combine high dribble volume, efficient take-ons, and repeated box entries.

### 🧠 Tactical & Statistical Logic

- **Dribble Volume (≥ 5 successful):** Ensures this is a genuine one-v-one dominant display, not a one-off action.
- **Dribble Efficiency (≥ 60%):** Filters to players who convert take-ons at a strong rate instead of high-risk inefficiency.
- **Danger-Zone Presence (≥ 4 touches in opp box):** Confirms that wide progression translated into real final-third penetration.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_touchline_terror.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_touchline_terror`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_touchline_terror
```

---

## 🎯 Scenario: Line Breaker (`scenario_line_breaker`)

### 🎯 Purpose
Find deep distributors who repeatedly break lines through accurate long progression while maintaining elite passing security.

### 🧠 Tactical & Statistical Logic

- **Long Progression Volume (≥ 8 accurate long balls):** Isolates players repeatedly progressing play over defensive lines.
- **Technical Security (≥ 85% pass accuracy with ≥ 50 accurate passes):** Keeps only primary distributors with sustained, reliable ball use.
- **Deep-Role Confirmation (≤ 1 touch in opp box):** Filters out advanced attackers and keeps the profile anchored to deep build-up zones.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_line_breaker.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_line_breaker`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_line_breaker
```

---

## 🏀 Scenario: Basketball Match (`scenario_basketball_match`)

### 🎯 Purpose
Find end-to-end shootouts where both teams produce elite attacking volume, then rank matches by a composite chaos score.

### 🧠 Tactical & Statistical Logic

- **Mutual Chance Quality (combined xG > 4.5, each side xG > 1.5):** Ensures both teams materially contribute to the shootout profile.
- **Extreme Shot Volume (combined shots > 35):** Filters for sustained transition-heavy attacking tempo.
- **Composite Chaos Score:** Weights combined xG, combined shots, combined big chances, and total goals to rank peak high-event matches.
- **Chaos Type Labeling:** Classifies matches as `balanced_shootout` or `lopsided_chaos` using xG parity between sides.
- **Context Enrichment:** Adds on-target volume, inside-box shots, possession split, and open-play xG split for tactical interpretation.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_basketball_match.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_basketball_match`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_basketball_match
```

---

## ⚡ Scenario: Lightning Rod (`scenario_lightning_rod`)

### 🎯 Purpose
Find attackers who repeatedly draw fouls while actively carrying the ball or receiving in dangerous areas.

### 🧠 Tactical & Statistical Logic

- **Fouls Drawn (≥ 6):** Captures players who consistently attract defensive contact and pressure.
- **Isolation/Threat Confirmation:** Requires either sustained take-on activity (`dribble_attempts >= 4`) or repeated dangerous-zone presence (`touches_opp_box >= 5`).
- **Minutes Floor (≥ 45):** Ensures the profile represents stable match influence rather than brief substitute volatility.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_lightning_rod.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_lightning_rod`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_lightning_rod
```

---

## 🛡️ Scenario: Human Shield (`scenario_human_shield`)

### 🎯 Purpose
Find outfield defenders who protect their box under heavy shot pressure, combining blocking, clearances, and defensive interventions into a composite shield profile.

### 🧠 Tactical & Statistical Logic

- **Block + Clearance Gate (blocked shots ≥ 4, clearances ≥ 5):** Keeps only defenders with sustained emergency-box defensive output.
- **Heavy Fire Context (shots faced ≥ 15):** Requires genuine defensive stress from opponent shot volume.
- **Composite Shield Score:** Weights blocks, clearances, interceptions, and tackles to rank overall defensive shielding impact.
- **Block Share Percentage:** Measures how much of incoming shot volume the player personally blocked.
- **Opposition xG Faced:** Adds opponent expected-goals context from full-match period data (`period = 'All'`).

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_human_shield.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_human_shield`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_human_shield
```

---

## ✨ Scenario: Golden Touch (`scenario_golden_touch`)

### 🎯 Purpose
Find late substitutes who deliver direct scoreline impact on very low touch volume, then rank them by contribution efficiency.

### 🧠 Tactical & Statistical Logic

- **Late Introduction Gate (substitution time ≥ 70):** Focuses on end-phase substitute interventions where time is limited.
- **Direct Impact Filter (goal or assist, touches > 0):** Requires explicit scoreline contribution while excluding ghost appearances.
- **Low-Touch Constraint (touches ≤ 12):** Keeps the profile centered on high efficiency rather than sustained usage.
- **Contribution Efficiency Ranking:** Uses contribution-per-touch as the primary sort signal, then touch count and substitution timing.
- **Chance Quality Context:** Adds xG, xA, xG+xA, and xG-per-shot for quality-adjusted impact profiling.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_golden_touch.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_golden_touch`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_golden_touch
```

---

## ⚙️ Scenario: Chaos Engine (`scenario_chaos_engine`)

### 🎯 Purpose
Find high-intensity disruptors who blend defensive action volume, tactical aggression, and attacking-third presence, then contextualize them with their team's shot output.

### 🧠 Tactical & Statistical Logic

- **Core Disruptor Gate (minutes ≥ 45, tackles + interceptions ≥ 5):** Limits rows to meaningful-minute players with sustained ball-winning volume.
- **Aggression + Final-Third Presence (fouls committed ≥ 3, touches in opp box ≥ 1):** Targets disruptive profiles that are both combative and positionally active high up the pitch.
- **Composite Disruption Score:** Ranks players using defensive actions, attacking-box touches, fouls, and recoveries for a broader chaos signal.
- **Shot Context Join (team shots ≥ 1):** Adds team-level shot volume, shots on target, and xG to proxy whether disruption translated into shot-generating phases.
- **Finished Match Integrity:** Includes only completed matches for stable outcome labeling (`home_win`, `away_win`, `draw`).

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_chaos_engine.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_chaos_engine`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_chaos_engine
```

---

## 🥵 Scenario: Tired Legs (`scenario_tired_legs`)

### 🎯 Purpose
Find late-match collapses driven by goal surges, shot escalation, and aggressive substitution patterns.

### 🧠 Tactical & Statistical Logic

- **Late Chaos Signals:** Tracks late goals (75+), late shot share, and attacking subs between 60 and 75 minutes.
- **Two-Signal Requirement:** Requires at least two chaos signals to prevent weak one-dimensional triggers.
- **Composite Chaos Score:** Ranks matches by weighted late goals, shot escalation, substitution pressure, and late xG.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_tired_legs.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_tired_legs`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_tired_legs
```

---

## 🕳️ Scenario: Black Hole (`scenario_black_hole`)

### 🎯 Purpose
Find high-volume shooters who absorb a very large share of their team's attempts while consistently selecting low-quality shots and producing zero goals.

### 🧠 Tactical & Statistical Logic

- **Shot Volume Gate (total shots ≥ 6):** Requires sustained individual shooting activity, filtering out one-off low-quality efforts.
- **Shot Quality Floor (avg xG per shot < 0.08):** Isolates poor shot selection by targeting consistently low-probability attempts.
- **Zero End Product (goals = 0):** Ensures the profile captures truly unproductive finishing output.
- **Team Shot Monopoly (shot share ≥ 40%):** Keeps only players who heavily concentrated team attacking volume through themselves.
- **Outfield + Finished Match Integrity:** Excludes goalkeepers and limits to completed fixtures to maintain stable match context.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_black_hole.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_black_hole`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_black_hole
```

---

## 🪤 Scenario: High Line Trap (`scenario_high_line_trap`)

### 🎯 Purpose
Find teams whose defensive line repeatedly catches opponents offside while still suppressing chance quality and restricting final-third access.

### 🧠 Tactical & Statistical Logic

- **Offside Trap Volume (opponent offsides caught ≥ 6):** Requires sustained trap execution, not isolated offside events.
- **Threat Suppression (opponent xG < 0.8):** Ensures the offside pressure translated into low overall chance danger.
- **Final-Third Access Constraint (opponent final-third passes < 75):** Captures matches where territorial entry was structurally limited.
- **Dual-Side Modeling:** Evaluates both home and away teams as potential trapping units using a unioned team-performance view.
- **Shot Quality Context:** Adds opponent xG-per-shot and shot profile fields to separate low-volume threat from truly low-quality attacking output.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_high_line_trap.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_high_line_trap`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_high_line_trap
```

---

## 👻 Scenario: Ghost Poacher (`scenario_ghost_poacher`)

### 🎯 Purpose
Find starting attackers with very low overall involvement but extreme penalty-box touch concentration and high-end finishing threat.

### 🧠 Tactical & Statistical Logic

- **Low Involvement Gate (touches ≤ 25):** Isolates players largely absent from buildup phases.
- **Box Concentration Rule (≥ 20% touches in opp box):** Ensures limited touches are concentrated in dangerous scoring zones.
- **Lethal Output Trigger (xG > 0.8 or goals ≥ 1):** Keeps only ghost profiles that still generate meaningful end-product.
- **Starter + Minutes Integrity (starting XI and minutes ≥ 60):** Removes cameo substitute noise and enforces sustained match presence.
- **Finishing Context:** Adds xG per shot, non-penalty xG, and supporting creation fields (xA, assists, chances created, xg_plus_xa).

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_ghost_poacher.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_ghost_poacher`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_ghost_poacher
```

---

## 🎯 Scenario: Route One Masterclass (`scenario_route_one_masterclass`)

### 🎯 Purpose
Find low-possession teams that leaned heavily on direct long-ball progression, still generated meaningful threat, and avoided defeat.

### 🧠 Tactical & Statistical Logic

- **Directness Ratio (> 20% long-ball share of total passes):** Uses parsed long-ball accuracy strings to reconstruct attempted long balls and measure true route-one reliance.
- **Adverse Possession Context (< 45%):** Ensures the profile reflects territorial disadvantage rather than possession-dominant circulation.
- **Threat Conversion Gate (xG > 1.2 or goals ≥ 2):** Keeps only direct-game plans that produced substantial attacking outcome.
- **Result Integrity (did not lose):** Filters to matches where direct style was at least result-neutral.
- **All-Period Match Frame:** Uses full-match period aggregates (`period = 'All'`) in finished matches only.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_route_one_masterclass.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_route_one_masterclass`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_route_one_masterclass
```

---

## 🧱 Scenario: Total Suffocation (`scenario_total_suffocation`)

### 🎯 Purpose
Find matches where one side imposed extreme territorial control and almost completely removed the opponent's ability to create meaningful attacking threat.

### 🧠 Tactical & Statistical Logic

- **Territorial Monopoly (> 60% possession):** Requires sustained control of match flow and territory.
- **Absolute Shot Suppression (opponent shots on target = 0):** Enforces complete denial of on-frame threat.
- **Chance-Quality Denial (opponent xG < 0.3):** Filters to near-zero expected threat environments.
- **Box Exclusion (opponent touches in opp box ≤ 5):** Captures structural prevention of dangerous area access.
- **All-Period Finished-Match Scope:** Uses full-match period aggregates (`period = 'All'`) and only completed fixtures.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_total_suffocation.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_total_suffocation`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_total_suffocation
```

---

## 🗺️ Scenario: Territorial Suffocation (`scenario_territorial_suffocation`)

### 🎯 Purpose
Find matches where one side weaponized possession to keep the opponent out of dangerous zones and heavily limit on-target threat.

### 🧠 Tactical & Statistical Logic

- **Deep-Block Forcing (opponent touches in opp box ≤ 5):** Captures structural territorial denial in high-value areas.
- **Possession Control (> 65%):** Ensures suffocation is driven by dominant ball control and field position.
- **Shot Suppression (opponent shots on target ≤ 1):** Confirms that territorial control translated into near-total shooting suppression.
- **Dual-Side Detection:** Evaluates both home and away suffocation cases symmetrically.
- **Full-Match Integrity:** Uses `period = 'All'` and finished matches only for stable full-game context.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/team/scenario_territorial_suffocation.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_territorial_suffocation`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_territorial_suffocation
```

---

## 🎛️ Scenario: Clinical Pivot (`scenario_clinical_pivot`)

### 🎯 Purpose
Find deep-lying distribution hubs who combine elite passing volume and accuracy with consistent final-third progression while staying mostly outside advanced box zones.

### 🧠 Tactical & Statistical Logic

- **Volume Distributor Gate (total passes ≥ 70):** Captures genuine tempo-setters with sustained on-ball responsibility.
- **Precision Filter (pass accuracy ≥ 90%):** Keeps only highly secure distributors who control game flow efficiently.
- **Progression Requirement (passes into final third ≥ 10):** Ensures volume is directional and advances team attacking phases.
- **Non-Invasive Role Constraint (touches in opp box ≤ 1):** Filters out advanced attackers to retain deep pivot profiles.
- **Context Enrichment:** Includes xG/xA, chance creation, recoveries, interceptions, and defensive actions for two-way interpretation.

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/player/scenario_clinical_pivot.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_clinical_pivot`

### 🚀 Execution
```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_clinical_pivot
```

---

## Template For Future Scenarios

```markdown
## <emoji> Scenario: <Title> (`scenario_<name>`)

### 🎯 Purpose
[1–2 sentences: what this scenario captures and why it is tactically or analytically meaningful.]

### 🧠 Tactical & Statistical Logic

- **[Threshold Name (value)]:** [Explain why this specific number, what it represents relative to league averages or distributions, and why lower/higher would produce the wrong set of results.]

- **[Second Condition (value)]:** [Explain the tactical rationale and how it combines with the first condition to narrow to the correct population.]

- **[Integrity/Scope Rule]:** [Explain any data integrity filter — finished matches, period filters, position exclusions — and why it is necessary for correct attribution.]

### 📂 Technical Assets
- **SQL Transformation:** `clickhouse/gold/scenario/{team,player}/scenario_<name>.sql`
- **Runner:** `scripts/gold/run_sql_job.py`
- **Target Table:** `gold_scenarios.scenario_<name>`

### 🚀 Execution
\`\`\`bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_<name>
\`\`\`
```
