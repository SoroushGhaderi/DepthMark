---
id: 001-pm-product-ideas-brainstorm
title: DepthMark product ideas — brainstorm
number: 1
domain: pm
topic: product-ideas
kind: idea
source: skill
status: proposed
version: 1
date: 2026-10-25
skills: [pm-product-discovery:brainstorm-ideas-existing, flow:docs]
related: []
lang: en
---

# DepthMark product ideas — brainstorm

## Summary

This doc lists about 60 product ideas that DepthMark can build and sell from the data it
already has. The ideas cover 11 customer groups, from odds analysts and scouts to media,
fans, AI builders, and sponsors. Most ideas sit on four shared engines, so the real choice
is which engine to build first. We recommend starting with the narrative engine (Story Feed
and the ideas around it), because it is low risk and almost ready. In parallel, we
recommend one SQL check that shows whether pre-match signal rates predict anything. That
check decides whether the betting ideas live or die. We need a decision on which path to
validate first.

## Context & problem

**Goal:** find products that can be built from DepthMark's current assets and sold.

### Existing assets (taken from the code)

| Asset | Details |
|---|---|
| Silver (FotMob) | `match`, `period_stat`, `player_match_stat`, `momentum`, `shot`, `card`, `match_personnel`, `team_form` |
| Gold Signals | **344 active signals** with a frontmatter catalog. By level: 93 match, 122 team, 129 player. By family: shooting 96, possession 79, goalkeeping 63, discipline 60, creativity 46 |
| Gold Scenarios | **48 scenarios**: 25 player scenarios (Metronome, Black Hole, Young Gun, …) and 23 team scenarios (Low Block Heist, Last Gasp, Underdog Heist, Tired Legs, …) |
| Oddspedia | `event`, `market` (`market_name` + `lines_json`), `match_payload`, plus `silver.oddspedia_match_resolution`, which links each odds event to one FotMob match with a `confidence` score |
| Infrastructure | ClickHouse + MongoDB catalog, automated bootstrap, daily schedule, Live snapshot |

> **Corrections to the first draft:** the first draft said 345 signals, 37 scenarios
> (12 team), and that `match_personnel` holds the referee. The code shows 344 signal
> catalogs (all `status: active`), 48 scenario tables (23 team), and the referee lives in
> `silver.match` (`referee_name`, `referee_country`). `match_personnel` holds the roles
> `starter`, `substitute`, and `coach`.

### Less obvious data that opens new product ideas

The first draft looked mostly at signals and scenarios. The Silver tables hold more than
that.

| Data | Where it lives | What it makes possible |
|---|---|---|
| Physical load: distance covered, walking / running / sprinting distance, number of sprints, top speed (per period, per team) | `silver.period_stat` | Fatigue, rotation risk, and "who runs more" products |
| Shot location (`x`, `y`) and goal-mouth placement (`goal_crossed_y`, `goal_crossed_z`, `on_goal_shot_x`, `on_goal_shot_y`), `situation`, `shot_type` | `silver.shot` | Shot maps, penalty placement, goalkeeper scouting |
| Minute-by-minute momentum (`minute`, `value`) | `silver.momentum` | Momentum charts, art prints, in-play alerts |
| Goal timing and score after each goal (`goal_time`, `home_score_after`, `away_score_after`) | `silver.shot` | Timing markets ("goal after 80'"), comeback stories |
| Card timing and the score when the card came (`card_minute`, `score_home_at_time`) | `silver.card` | "Cards when losing" patterns, referee timing profiles |
| Corners, offsides, fouls, woodwork, big chances (per period) | `silver.period_stat` | Corner markets, offside-trap analysis, "unlucky" tables |
| Stadium name, city, coordinates, capacity, surface, attendance | `silver.match` | Away-day guides, home-advantage analysis, travel products |
| Substitution time, type, and reason; captain flag; age; coach | `silver.match_personnel` | Bench impact, coach profiles, young talent tracking |
| `opta_id` next to the FotMob player ID | `silver.player_match_stat` | Cross-provider player ID mapping |
| Recent form with opponent and venue | `silver.team_form` | Form, head-to-head, and fixture congestion features |

### Two deciding points

1. **Most signals are descriptive and post-match, not predictive.** For example,
   `referee_strictness` says "the first yellow card came in minutes 1 to 5". For betting
   and prediction products, these signals must be turned into **pre-match occurrence
   rates**. For example: "how many times did this team or this referee have this signal in
   the last 10 matches". Content and scouting products can already use the signals as they
   are today.
2. **Data usage rights.** Raw data, and even source-owned metrics (such as
   `fotmob_rating`), cannot safely be sold. Outputs that are **DepthMark's own derived
   insight** (signals, narratives, scores, backtests) are easier to defend.

## Users / audience

The ideas serve 11 customer groups. The letter in the first column matches the idea IDs in
the idea catalog.

| Group | Who they are | What they need from DepthMark | Ideas |
|---|---|---|---|
| A. Odds analysts and bettors | Adults in legal betting markets, tipsters, prop and niche-market analysts | Pre-match rates, niche market profiles, honest track records | A1–A8, backtest lab, card and referee intelligence |
| B. Quants and B2B data buyers | Model builders, odds comparison developers, research teams, integrity firms | Clean features, ID mapping, licensed history | B1–B5, feature store |
| C. Media and broadcasters | News sites, local outlets, commentators, podcasts | Story angles, reports, prep sheets, records | C1–C5, Story Feed |
| D. Fans and social apps | Football fans, page admins, travelling fans | Shareable visuals, derby pages, away-day info | D1–D5, match story cards, Telegram bot |
| E. Games and fantasy players | Fantasy managers, quiz and prediction-game players | Fun, free games and rotation warnings | E1-g–E5-g, fantasy assistant |
| F. Clubs, scouts, agents, coaches | Lower-league clubs, agents, semi-pro coaches, goalkeeper coaches | Similar-player search, opponent packs, player reports | F1–F7, Player DNA |
| G. Referees and governing bodies | Referee bodies, leagues, journalists | Referee report cards, home-bias evidence | G1–G2 |
| H. Sports science | Fitness staff, media, fantasy products | Fatigue, congestion, league intensity | H1–H3 |
| I. Education and research | Bootcamps, universities, researchers, trainers | Clean datasets, exercises, case studies | I1–I3, training datasets |
| J. AI and developers | AI app builders, developers | API and MCP access to structured football facts | J1–J3, Ask DepthMark |
| K. Brands and sponsors | Brand social teams, marketing agencies, small media sites | Sponsorable moments, ready content | K1–K3 |

**Language note:** the Persian-language football content market is large and poorly served.
Several ideas (Story Feed, Telegram bot, auto match reports) aim at it first.

## Options considered

The ideas are sorted into four buckets. Impact means revenue potential. Effort means the
work still needed with today's assets. Idea IDs refer to the idea catalog below.

| Bucket | Meaning | Ideas |
|---|---|---|
| **Quick wins** | Low effort, low legal risk, uses E1 or existing tables | Story Feed, match story cards, C1 auto match reports, C3 records engine, C4 Team of the Week, D1 momentum prints, D2 shot maps, E2-g daily quiz, G1 referee report card, H2 fixture congestion, B5 data quality benchmark |
| **Big bets** | High value, needs E2 or E4 and proof that the data predicts | Backtest lab, pre-match report, A1 corners, A2 goal timing, A3 player props, B1 fixture mapping API, J1 MCP server, J2 developer API, F1 similar-player finder |
| **Niche plays** | Small but loyal paying groups | F2 opponent packs, F6 agent reports, F7 goalkeeper scouting, C2 commentator sheets, A8 tipster verification, I1 learn SQL, D4 away-day guide |
| **Careful / later** | High legal, reputation, or technical risk | B4 integrity monitor, K2 real-time triggers, E3-g signal bingo, Live pattern detection (all need the Live path or careful legal review); E5-g badges (image rights) |

### Scoring: first-round top five

Criteria: alignment with the goal (revenue), impact, feasibility with current assets,
differentiation, and legal risk.

| # | Idea | Impact | Feasibility | Differentiation | Legal risk |
|---|---|---|---|---|---|
| 1 | Story Feed and match story cards | Medium | **High** | High | **Low** |
| 2 | Signal × odds backtest lab | **High** | Medium | **High** | Medium |
| 3 | Training datasets and kits | Low to medium | **Very high** | Medium | Medium to high |
| 4 | Card and referee market intelligence | Medium to high | Medium | High | Medium |
| 5 | Player DNA profile and scouting shortlist | Medium | High | Medium | Low to medium |

### Scoring: strongest new ideas from the expansion

| # | Idea | Impact | Feasibility | Differentiation | Legal risk |
|---|---|---|---|---|---|
| 6 | B1 Fixture ID mapping API | Medium | **High** | **High** | Low to medium |
| 7 | E1-g Predict the story (free game) | Medium | High | **High** | **Low** |
| 8 | J1 MCP server for football data | Medium to high | High | High | Medium |
| 9 | A2 Goal timing and A1 corner markets | High | Medium | High | Medium |
| 10 | H1 + H2 Fatigue and fixture congestion | Medium | **High** | Medium to high | **Low** |
| 11 | C1 Auto-written match reports | Medium | High | Medium | Low |
| 12 | F1 Similar-player finder | Medium to high | Medium | Medium to high | Low to medium |

## Recommendation

- **Fastest path to validation:** #1 (Story Feed). Low risk, almost ready, and testable
  within a few weeks with one test channel or page. #7 (Predict the Story) and #11 (auto
  match reports) reuse the same engine (E1), so they can follow quickly.
- **Biggest bet:** #2 (Backtest Lab). Before building anything, run a simple SQL analysis
  on ClickHouse. It checks whether pre-match signal rates correlate with results or odds.
  If they do not, #2, #4, and #9 are dropped.
- **Small but immediate revenue:** #3, on the condition that the target is replaced with a
  non-proprietary metric. #6 (fixture mapping API) is a second candidate, because the work
  already runs every day.
- **Build engines, not products:** build E1 (narrative engine) first, because most quick
  wins sit on it. Build E2 (pre-match rate layer) only after the correlation check passes.

## Plan

1. Run `pm-product-discovery:identify-assumptions-existing` on ideas #1, #2, #6, and #7.
2. Run exploratory queries on ClickHouse:
   - `oddspedia_match_resolution` coverage and the share of confident matches.
   - The list of `market_name` values in `oddspedia_bronze.market` (cards, corners, timing,
     player props).
   - Whether `lines_json` has more than one snapshot per match (needed for A6).
   - The correlation of pre-match signal rates with results.
   - The activation rate of each match-level narrative label (needed for #7).
   - Null rates of physical fields in `silver.period_stat` and of `referee_name` in
     `silver.match`, by league.
3. Run `pm-product-discovery:brainstorm-experiments-existing` to design a cheap experiment
   for each assumption.
4. Get a short legal review of data terms for FotMob and Oddspedia before any paid launch.

## Risks & assumptions

These are the risks that cut across many ideas. Each priority write-up below also lists its
own assumptions.

| Risk / assumption | Impact | Likelihood | Cheapest test | Owner |
|---|---|---|---|---|
| Pre-match signal rates have no predictive power | High: drops #2, #4, #9, A1–A5 | Medium | One correlation query between rolling signal rates and results | Data |
| Oddspedia does not carry card, corner, timing, or player-prop markets | High: drops #4, #9, A1–A3 | Unknown | `SELECT DISTINCT market_name` on `oddspedia_bronze.market` | Data |
| Only one odds snapshot per match | Medium: drops A6 and closing-line work | Unknown | Count distinct scrape times per match | Data |
| FotMob or Oddspedia terms forbid commercial use | High: affects every paid product | Medium | Legal review of both sites' terms | Legal |
| `fotmob_rating` cannot be resold or shown as ours | Medium: #3, C4 | High | Replace it with a DepthMark-owned score | Product |
| Betting products are illegal in some target markets | High: #2, #4, #9, A-series | Depends on market | Limit sales to legal markets; legal review | Legal |
| Lower-league coverage is thin (`coverage_level`, physical nulls) | Medium: F-series, H-series, #5 | Medium | Null-rate query by `league_id` | Data |
| Fixture mapping confidence is too low to sell | Medium: #6 | Unknown | Share of events with a confident match | Data |
| Labels are too rare or too common for a fun game | Medium: #7 | Unknown | Activation rate of each match-level label | Data |
| Creators will not pay when FotMob stats are free | Medium: #1, C-series | Medium | Test channel for a few weeks; ask for pre-payment | Product |
| LLM match reports invent facts | Medium: #11 | Medium | Generate 50 reports and review each one | Product |
| Integrity alerts read as accusations of fixing | High: B4 | Low to medium | B2B only, neutral wording ("unusual"), legal review | Legal |
| Player image rights block badge products | Medium: E5-g | Medium | Text and icons only, no player photos | Product |

## Four shared engines

Most ideas in this doc are not separate builds. They sit on top of four reusable engines.
Building one engine unlocks many products, so it is better to choose an engine first and a
product second.

| Engine | What it is | Built from | Products it unlocks |
|---|---|---|---|
| **E1. Narrative engine** | After each match, the list of signal and scenario labels that fired, with the stats behind them | Gold signal activations, Gold scenarios | Story Feed, match cards, auto match reports, bots, quizzes, sponsor moments, prediction games |
| **E2. Pre-match rate layer** | For each team, player, and referee: how often each signal fired over the last N matches | Gold signals + `silver.team_form` + `silver.match` | Pre-match reports, backtest lab, card / corner / timing markets, feature store, fantasy assistant |
| **E3. Player and team fingerprint** | A vector of how often each signal and scenario fires for one player or team | Gold signals + Gold scenarios + `silver.player_match_stat` | Player DNA, similar-player search, scouting, opponent packs, team style maps |
| **E4. Cross-source link** | The FotMob ↔ Oddspedia match link with confidence | `silver.oddspedia_match_resolution` | Backtests, market intelligence, fixture mapping API, integrity monitoring |

## Idea catalog

### First round: three perspectives (Product Trio)

**Product Manager (business value)**

1. **Pre-match report for odds markets:** combine `team_form` and signal rates with odds to
   find markets that are probably mispriced. Delivered as a newsletter subscription or a
   channel.
2. **Selling training datasets:** for bootcamps, data science courses, and instructors. The
   package is a dataset + catalog + solved notebook.
3. **Story Feed for media outlets:** an API or feed that, after each match, delivers
   narrative labels such as "Save Fest", "Last Gasp", and "Blood and Thunder", together
   with the supporting stats.
4. **Scouting shortlist for lower-league clubs and agents:** based on player scenarios
   (`young_gun`, `line_breaker`, `progressive_powerhouse`).
5. **Card, foul, and referee market intelligence:** 60 discipline signals plus referee
   data, aimed at card and foul markets, which are less efficient.

**Product Designer (user experience)**

1. **Shareable "match story" cards:** ready-made images for Instagram and X, with the
   narrative label, momentum, and key stats.
2. **Signal Explorer:** a web app to browse the 344 signals, with filters for league, team,
   and date range. A "pattern search engine" for football.
3. **"Player DNA" profile:** scenario badges on each player's page (Metronome, Black Hole,
   …). Gamified and attractive to fantasy users.
4. **Telegram bot to follow a team:** narrative and stats after each match, trends before
   each match. The Persian-language football content market is large.
5. **Fantasy assistant:** player suggestions based on scenario consistency and form.

**Software Engineer (data and technical leverage)**

1. **Signal × odds backtest lab:** for each signal or combination of signals, it calculates
   the historical ROI on Oddspedia markets. The `oddspedia_match_resolution` link already
   exists, and this is a rare advantage.
2. **"Ask DepthMark":** natural-language questions over Silver/Gold using an LLM and
   text-to-SQL, with the signal catalog as context.
3. **Feature Store for modelers:** versioned pre-match features (rolling signal rates,
   form, xG) for quants and researchers.
4. **Live (in-play) pattern detection:** run signals on the Live snapshot and `momentum`,
   and send alerts during the match.
5. **Embed widgets for websites and blogs:** signal badges and match cards as white-label
   widgets.

### Expansion by customer group

Each row names the data it uses, so each idea can be checked against the warehouse. The
"Engine" column points to the four shared engines.

#### A. Odds analysts and bettors (adult, legal markets only)

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| A1 | **Corner market model** | Pre-match corner expectations for each team, from set-piece and crossing habits | `corners_home` / `corners_away` in `silver.period_stat`; signals `set_piece_dominance`, `dead_ball_specialists`, `crossing_clinic`, `cross_spam`, `wide_play_monopoly` | E2, E4 | Monthly subscription for corner-market analysts |
| A2 | **Goal timing markets** | Profiles of when each team scores and concedes: early, late, first or second half | `goal_time` and `minute` in `silver.shot`; signals `early_blitz`, `late_surge_goals`, `late_game_salvage`, `game_of_two_halves`; scenarios `last_gasp`, `second_half_warriors` | E2 | Subscription; add-on to the pre-match report |
| A3 | **Player shot props** | Expected shots and shots on target per player before the match | `total_shots`, `shots_on_target`, `minutes_played` in `silver.player_match_stat`; signals `shot_volume_monster`, `persistent_threat`, `shot_magnet` | E2, E3 | Subscription for prop-market analysts |
| A4 | **xG "luck table" and regression alerts** | Teams and players whose results run far above or below their xG, flagged as likely to fall back to normal | `expected_goals` in `silver.shot` and `silver.period_stat`; signals `xg_overperformance_team`, `conversion_collapse`, `high_xg_low_score`, `unlucky_game` | E2 | Free weekly table to build an audience, paid alerts |
| A5 | **Draw and stalemate finder** | Matches where both teams often produce low-event, locked games | Signals `boring_stalemate`, `possession_stalemate`, `early_tactical_lock`, `goalless_siege`; scenario `tactical_stalemate` | E2, E4 | Subscription; content for draw-market tipsters |
| A6 | **Odds movement tracker** | Shows how odds for a match changed between scrapes, next to team news and form | `lines_json` in `oddspedia_bronze.market` across several scrape times (if they exist) | E4 | Subscription; alerts |
| A7 | **Bet post-mortem tool** | The user enters a past bet; DepthMark explains with signals why it won or lost ("high xG, low score", "red card in minute 30") | Gold signal activations, `silver.card`, `silver.shot` | E1 | Freemium tool for tipsters; builds trust and an audience |
| A8 | **Tipster verification service** | Checks a tipster's public picks against real results and closing odds, and publishes a fair track record | `silver.match`, `oddspedia_bronze.market`, `silver.oddspedia_match_resolution` | E4 | Tipsters pay for a "verified" badge; followers use it for free |

#### B. Quants, modelers, and B2B data buyers

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| B1 | **Fixture ID mapping API** | Given an Oddspedia event, returns the matching FotMob match with a confidence score (and the reverse) | `silver.oddspedia_match_resolution` (`confidence`, `match_score`, `time_difference_minutes`, rule version) | E4 | Per-call API pricing or monthly plan for developers who join odds and stats sources |
| B2 | **Player ID cross-reference** | Maps FotMob player IDs to Opta IDs | `player_id` and `opta_id` in `silver.player_match_stat` | — | Small API add-on for data engineers |
| B3 | **Signal activation dataset licence** | Historical "which signal fired in which match" tables, as files or a database share | Gold signal activation tables | E1 | Yearly licence for research teams and model builders |
| B4 | **Match integrity monitor** | Flags matches where in-game events look odd next to the odds, such as late penalties, sudden card spikes, or big odds moves | `silver.card`, `silver.shot` (penalties), signals `penalty_conceder`, `aggression_spike`, `chaos_90_plus`; odds from `oddspedia_bronze.market` | E1, E4 | B2B contracts with leagues, federations, or integrity firms. High value, high reputation risk; needs careful wording ("unusual", never "fixed") |
| B5 | **Data quality benchmark** | Publishes how complete each league's data is (physical stats, xG, referee) so buyers know what they can trust | `coverage_level` in `silver.match`, null rates across Silver tables | — | Free lead magnet for the paid data products |

#### C. Media, publishers, and broadcasters

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| C1 | **Auto-written match reports** | An LLM writes a short match report from the labels and stats, in several languages, including Persian | Narrative labels, `silver.match`, `silver.shot` (goal times, assists) | E1 | Per-article or monthly fee for news sites and local outlets that cannot cover every league |
| C2 | **Commentator prep sheet** | A one-page pre-match brief: referee profile, form, head-to-head, players to watch, and recent narrative labels | `silver.team_form`, `referee_name` in `silver.match`, player scenarios | E1, E2, E3 | Per-match or per-season fee for commentators, podcasts, and radio |
| C3 | **Records and milestones engine** | Finds "first time since …" facts and streaks automatically | Signals such as `woodwork_record_match`, `clinical_finishing_streak`, `hat_trick_hero`; history in all Silver tables | E1 | Feed for broadcasters and social teams |
| C4 | **Weekly "Team of the Week" by DepthMark score** | A weekly XI picked by a DepthMark-owned score, not `fotmob_rating` | Player scenarios, `silver.player_match_stat` | E3 | Free content to build the brand; sponsor slot |
| C5 | **Podcast and YouTube show notes** | Weekly story angles, charts, and talking points for football creators | Narrative labels, momentum, luck table (A4) | E1 | Monthly subscription for creators |

#### D. Fans and social apps

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| D1 | **Momentum art prints** | Turns the minute-by-minute momentum of a famous match into a poster | `silver.momentum` (`minute`, `value`, `momentum_team`), final score | — | Print-on-demand sales; club colours without club logos |
| D2 | **Shot map and goal-placement cards** | Shows where a player shoots from and where the ball crossed the goal line | `x`, `y`, `goal_crossed_y`, `goal_crossed_z` in `silver.shot` | — | Free shareable cards; premium for full-season maps |
| D3 | **Rivalry and derby hub** | Head-to-head history, cards, and narrative labels for derbies | `silver.team_form`, signal `heated_derby_stats`, scenario `war_zone` | E1 | Ad-supported pages; sponsor per derby |
| D4 | **Away-day guide** | For each stadium: how hard it is to win there, attendance, surface, and the trip for travelling fans | Stadium fields and `attendance` in `silver.match`; signals `away_hostility`, `hostile_territory`; scenario `away_day_masterclass` | E2 | Affiliate income from travel and ticket partners |
| D5 | **"What kind of fan are you" quiz** | Matches a fan to a team style from the team fingerprints | Team fingerprints | E3 | Viral free tool; email list for other products |

#### E. Games, fantasy, and prediction (free-to-play)

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| E1-g | **Predict the story** | Before each match, players guess which narrative label it will get ("Will this be a Blood and Thunder match?"). Points after the match | Narrative labels as the answer key | E1 | Free game, paid by sponsors and ads. No stake, so no gambling licence needed |
| E2-g | **Daily football quiz** | Auto-generated questions from last weekend's data ("Which keeper had a Save Fest?") | Signal activations, `silver.player_match_stat` | E1 | Ads, premium packs, white-label for media sites |
| E3-g | **Signal bingo** | A bingo card of signals for a live match; squares light up as signals fire | Live snapshot + signals | E1 | Second-screen engagement for broadcasters and bars |
| E4-g | **Rotation risk for fantasy** | Warns which players may be rested, from fixture congestion and past rotation | `match_date` gaps in `silver.team_form`; `minutes_played`; signal `heavy_rotation`; `substitution_time` | E2 | Premium tier inside the fantasy assistant |
| E5-g | **Text-only badge collection** | Users collect scenario badges that players earn in real matches | Player scenarios | E3 | Season pass. Use text and icons only, no player photos, to avoid image-rights problems |

#### F. Clubs, scouts, agents, and coaches

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| F1 | **Similar-player and replacement finder** | "Find players like X, younger and in cheaper leagues" | Player fingerprints, `age` in `silver.match_personnel`, league from `silver.match` | E3 | Monthly seat licence for scouts and agents |
| F2 | **Opponent analysis pack** | Before a match, a PDF on the next opponent: pressing, low block, set pieces, discipline, key players | Team fingerprints; signals `press_resistance`, `low_block_success`, `set_piece_masterclass` | E3 | Per-pack or season price for semi-pro and lower-league coaches |
| F3 | **Young talent tracker** | Tracks young players who keep earning strong scenarios | Scenario `young_gun`, `age`, `minutes_played` | E3 | Subscription for scouts and agents |
| F4 | **Bench impact ranking** | Which coaches get the most from substitutes, and when they make changes | `substitution_time`, `substitution_reason` in `silver.match_personnel`; signals `super_sub_goal`, `bench_goals_impact`, `clinical_sub_impact` | E3 | Content for media; analysis for clubs hiring a coach |
| F5 | **Coach style fingerprint** | The team style each coach produces, and how it changes when they move club | `role = 'coach'` in `silver.match_personnel`, team fingerprints | E3 | Report for clubs and agents in coach hiring |
| F6 | **Agent player report generator** | One click turns a player's data into a clean PDF for agents to send to clubs | Player fingerprints, scenarios, shot maps | E3 | Per-report or monthly fee for agents |
| F7 | **Goalkeeper and penalty scouting** | Where keepers concede, how they handle shots by placement, penalty history | `keeper_id`, `goal_crossed_y`, `goal_crossed_z`, `situation` in `silver.shot`; signals `penalty_stopper`, `keeper_save_efficiency` | E3 | Specialist report for goalkeeper coaches and penalty-takers' staff |

#### G. Referees and governing bodies

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| G1 | **Referee report card** | Per referee: card rate, card timing, home/away balance, and consistency over time | `referee_name` in `silver.match`, `silver.card`, signals `referee_strictness`, `referee_showdown`, `card_frenzy` | E2 | Media content (free); paid reports for referee bodies and analysts |
| G2 | **Home bias index** | Whether some referees or leagues give more cards or penalties to away teams | `team_side` in `silver.card`, penalties in `silver.shot`, `attendance` | E2 | Research report; media licensing |

#### H. Sports science and physical data

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| H1 | **Fatigue and late-collapse report** | Teams whose running and passing drop in the second half, and how often they concede late | `distance_covered_*`, `number_of_sprints_*` per period in `silver.period_stat`; scenario `tired_legs`; signals `passing_fatigue_index`, `second_half_possession_collapse` | E2 | Content for media; feature for pre-match and fantasy products |
| H2 | **Fixture congestion tracker** | Rest days before each match and how results change with short rest | `match_date` in `silver.team_form` and `silver.match` | E2 | Free table to build an audience; input for E4-g and A-series products |
| H3 | **League intensity comparison** | Which leagues run more, sprint more, and press harder | `silver.period_stat` physical fields, `league_id` | — | Report for scouts moving players between leagues |

#### I. Education and research

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| I1 | **Learn SQL with football** | An online playground with a small ClickHouse sandbox and guided exercises | Sample of Silver tables | — | Course fee; B2B licence for bootcamps |
| I2 | **Academic data access program** | Research access to signals and scenarios, with a citation requirement | Gold tables | E1, E3 | Low-cost licence; brand and credibility |
| I3 | **Case-study pack for analytics teams** | Ready business-style case studies ("Is this team lucky?", "Who to sign?") with answers | Silver + Gold | E2, E3 | Sold to universities and corporate trainers |

#### J. AI and developers

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| J1 | **MCP server for football data** | A tool server that lets AI assistants query DepthMark signals, scenarios, and pre-match rates | Gold tables, signal catalog in MongoDB | E1, E2, E3 | Usage-based pricing for AI app builders |
| J2 | **Public developer API with free tier** | REST API for labels, fingerprints, and pre-match rates | All four engines | E1–E4 | Free tier, then paid plans by volume |
| J3 | **Custom signal builder** | Users write their own signal in a simple form; DepthMark runs it over history | Silver tables, the signal SQL pattern | — | Pro tier for analysts |

#### K. Brands, sponsors, and marketing

| # | Idea | What it does | Data it uses | Engine | Who pays and how |
|---|---|---|---|---|---|
| K1 | **Sponsored moments** | Brands sponsor a narrative label ("Save Fest, presented by X") across content and bots | Narrative labels | E1 | Sponsorship packages through agencies |
| K2 | **Real-time marketing triggers** | When a "Last Gasp" winner happens, a brand's ready-made post goes live | Live snapshot + signals | E1 | Monthly fee for brand social teams. Depends on the Live path |
| K3 | **White-label content packs** | Weekly ready content (cards, facts, quizzes) for small media or tipster sites | E1 outputs, C3, E2-g | E1 | Monthly content subscription |

## Priority idea write-ups

### 1. Story Feed and match story cards

**Description:** after each match, the narrative labels produced by the signals are
delivered together with the supporting stats. Delivery is as an API, a feed, or ready-made
images for football page admins, media outlets, and content creators.

**Why:** the signals already have narrative names and already run. The output is derived
insight, not raw data, so it is the lowest-risk legal path. The football content market
(especially the Persian-language market) is large, and creators are always looking for a
"story angle".

**Assumptions to test:**

- Content creators will pay for a story angle, and do not find the free FotMob stats enough
  on their own.
- The current delay (the pipeline runs on completed dates) is acceptable, or the Live path
  needs to be ready sooner.
- The audience finds the labels "right" and interesting, not just statistical.

### 2. Signal × odds backtest lab

**Description:** a tool that shows the historical ROI and hit rate you would have had if
you had acted on a market based on the pre-match rate of one signal (or a combination of
signals).

**Why:** connecting FotMob ↔ Oddspedia in one clean warehouse is a rare technical
advantage. The customers (odds analysts and quants) can pay a lot. This idea has the
highest potential value.

**Assumptions to test:**

- After they are turned into pre-match features, the signals have **predictive power**
  (the riskiest assumption).
- Historical odds coverage and the event match rate are high enough for a meaningful
  backtest.
- Commercial use of scraped odds is allowed. Selling this tool in markets where betting is
  illegal is also forbidden or high-risk, so the target market must be outside those
  jurisdictions.

### 3. Training datasets and kits

**Description:** a package of dataset + catalog + solved notebook + exercises for data
science courses, built from the Silver tables.

**Why:** Silver data (such as `silver.player_match_stat`) is already clean and conformed.
So this is the cheapest way to get a first revenue signal.

**Assumptions to test:**

- The current target (`fotmob_rating`) is a FotMob-owned metric. It probably needs to be
  replaced with a **DepthMark-owned score** or another target (for example match result or
  goals).
- Instructors and bootcamps will pay for a clean football dataset, even though free
  competitors exist (StatsBomb Open Data and Kaggle).

### 4. Card and referee market intelligence

**Description:** referee strictness profiles and team and competition discipline patterns,
for card and foul markets.

**Why:** niche markets are less efficient and have less data competition. DepthMark has 60
discipline signals and referee data.

**Assumptions to test:**

- `oddspedia_bronze.market` actually covers card and foul markets (not checked yet).
- The referee name in `silver.match` (`referee_name`) is filled in for the target leagues.
- Referee strictness is stable over time and can be predicted.

### 5. Player DNA profile and scouting shortlist

**Description:** each player's scenario badges and how consistent they are over the
season, plus a "similar players" filter. Aimed at small clubs, agents, and fantasy users.

**Why:** the player scenarios are ready, and the product layer is mostly UI. A free version
to attract an audience and a paid version for scouts are both possible.

**Assumptions to test:**

- Lower-league coverage is deep enough. Scouting value sits exactly where Wyscout is
  expensive.
- Scouts trust FotMob-derived stats compared with professional tools.
- Fantasy users will pay for badges, not just for form.

### 6. Fixture ID mapping API

**Description:** an API that answers "which FotMob match is this Oddspedia event?" and the
reverse, with a confidence score and the rule that matched it.

**Why:** joining an odds source to a stats source is a known pain for every developer who
builds betting models or odds comparison sites. DepthMark already does this every day in
`silver.oddspedia_match_resolution`. The output is a mapping between IDs, not raw stats, so
the legal risk is lower than selling data.

**Assumptions to test:**

- The match rate and confidence are high enough to sell (measure the share of events with
  a confident match).
- Developers will pay for mapping rather than build their own fuzzy matching.
- Publishing IDs from both sources is allowed under their terms.

### 7. Predict the Story (free game)

**Description:** before each match, players pick which narrative labels the match will
get, such as "Goal Fest", "Blood and Thunder", or "Save Fest". After the match, the real
labels decide the points. Leagues between friends and weekly leaderboards keep people
coming back.

**Why:** it is a new kind of prediction game that only DepthMark can score, because only
DepthMark has the labels. It is free to play, so no gambling licence is needed. It also
feeds the Story Feed audience and gives sponsors a clear slot.

**Assumptions to test:**

- Fans understand the labels without a long explanation.
- The labels are not so rare or so common that guessing becomes boring (check the
  activation rate of each label).
- Sponsors will pay for named labels or weekly prizes.

### 8. MCP server for football data

**Description:** a tool server that AI assistants and AI apps can call to ask for signals,
scenarios, player fingerprints, and pre-match rates.

**Why:** many people now build football assistants on top of LLMs. They need clean,
structured football facts with clear meaning. The signal catalog in MongoDB already gives
each signal a name, description, and grain, which is exactly what an AI tool needs.

**Assumptions to test:**

- AI app builders will pay per call rather than scrape free sites.
- The answers stay derived insight, not a pipe of raw source data.
- Usage can be limited and metered without heavy new infrastructure.

### 9. Goal timing and corner markets

**Description:** pre-match profiles of when each team scores and concedes, and how many
corners each team tends to win and give away.

**Why:** timing and corner markets get less attention than match result markets. DepthMark
has goal times in `silver.shot`, corners per period in `silver.period_stat`, and matching
signals and scenarios (`early_blitz`, `late_surge_goals`, `last_gasp`,
`set_piece_dominance`).

**Assumptions to test:**

- `oddspedia_bronze.market` has timing and corner markets (check `market_name` values).
- Past timing and corner patterns repeat enough to predict.
- Same legal limits as the backtest lab: legal betting markets only.

### 10. Fatigue and fixture congestion

**Description:** a weekly table of rest days, running load, and late-match collapses, and
a "tired legs" warning before each match.

**Why:** physical data (`distance_covered_*`, `number_of_sprints_*`, `top_speed_*`) is
rarely used in public football content. Rest days come straight from match dates. The
output feeds media content, fantasy rotation warnings (E4-g), and pre-match reports.

**Assumptions to test:**

- Physical fields are filled in for enough leagues (check null rates by `league_id`).
- Short rest really links to worse second-half numbers in this data.

### 11. Auto-written match reports

**Description:** a short written report for every match, built by an LLM from the narrative
labels and key stats, in several languages.

**Why:** small media sites cannot cover every league. Labels give the LLM a clear story to
tell, so reports are less generic. Persian-language coverage is a gap.

**Assumptions to test:**

- Reports are accurate (no made-up facts) when the LLM only sees structured inputs.
- Editors will publish them with light review.
- Search engines and readers accept automated reports in this niche.

### 12. Similar-player finder

**Description:** given a player, finds others with a close fingerprint of signals and
scenarios, with filters for age, league, and minutes played.

**Why:** it turns E3 into a direct scouting tool. It is cheaper than professional platforms
and focuses on lower leagues where they are expensive.

**Assumptions to test:**

- Fingerprints of players in the same role look alike, and different roles look different
  (a simple sanity check).
- Enough minutes per player exist in lower leagues to build a stable fingerprint.

## Open questions

- [ ] Which `market_name` values does `oddspedia_bronze.market` hold (cards, corners, timing, player props)? — Data (one ClickHouse query)
- [ ] Is there more than one odds snapshot per match in `lines_json`? — Data
- [ ] What share of Oddspedia events have a confident FotMob match? — Data
- [ ] Do rolling pre-match signal rates correlate with results or odds at all? — Data
- [ ] How complete are physical fields and `referee_name` in each target league? — Data
- [ ] Do FotMob's and Oddspedia's terms allow commercial use of derived outputs and IDs? — Legal
- [ ] Which countries are legal target markets for the betting-related products? — Legal
- [ ] Which first test channel should carry the Story Feed (Telegram, Instagram, X)? — Product

## Decision

- **Options:**
  - A: validate the narrative engine first (Story Feed, then Predict the Story and auto
    match reports).
  - B: validate the betting path first (correlation check, then the backtest lab).
  - C: chase quick revenue first (training datasets or the fixture mapping API).
- **Recommended:** A, with the B correlation query run in parallel — A is low risk and
  almost ready, and the query alone decides whether B is worth building.
- **Decision:** _pending_
- **Decided by / date:** _pending_
- **Notes:**

## Skills & sources

- Skills: `pm-product-discovery:brainstorm-ideas-existing` (Product Trio method for the
  first round), `flow:docs` (this doc format).
- Inputs:
  - `clickhouse/silver/ddl/*.sql` (Silver table columns)
  - `clickhouse/silver/dml/07_match_personnel.sql` (personnel roles)
  - `clickhouse/oddspedia_bronze/ddl/*.sql` (Oddspedia tables)
  - `clickhouse/gold/dml/scenarios/player/`, `clickhouse/gold/dml/scenarios/team/`,
    `clickhouse/gold/ddl/01_create_scenario_tables.sql` (scenario counts)
  - `scripts/gold/signal/catalogs/sig_*.md` (signal counts, names, and status)
  - The first Persian draft, `docs/product/2026-10-24-product-ideas-brainstorm.md`
    (replaced by this doc)

## Changelog

- 2026-10-24 — first draft in Persian at `docs/product/2026-10-24-product-ideas-brainstorm.md`
  (15 ideas, top five).
- 2026-10-25 — translated to English; expanded to about 60 ideas in 11 customer groups with
  four shared engines; fixed signal, scenario, and referee facts against the code.
- 2026-10-25 v1 — moved into the `flow:docs` format as `001-pm-product-ideas-brainstorm`.
