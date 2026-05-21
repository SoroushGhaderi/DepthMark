# Gold Signal Catalogs

Each active Gold signal has a catalog file in this directory. The index is structured from per-signal metadata so engineers and analysts can quickly scan signal ownership, grain, and status.

## Metadata Contract

Catalogs use a YAML frontmatter block that is parsed by `scripts/mongodb/sync_signal_catalogs.py`.
The sync script currently requires these top-level fields:

- `signal_id`
- `status`
- `entity`
- `family`
- `subfamily`
- `grain`
- `row_identity`
- `asset_paths`

Common optional fields include `headline` and `trigger`.
Asset paths are explicit in each catalog:

- Target table: `gold.{signal_id}`
- SQL path: `clickhouse/gold/signal/{signal_id}.sql`
- Runner path: `scripts/gold/signal/runners/{signal_id}.py`

Keep this index aligned with active catalog files when adding, renaming, or deleting a signal.

| Signal ID | Entity | Family | Subfamily | Grain | Status | Catalog |
|---|---|---|---|---|---|---|
| `sig_match_discipline_cards_battle_of_attrition` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_battle_of_attrition.md](sig_match_discipline_cards_battle_of_attrition.md) |
| `sig_match_discipline_cards_blood_and_thunder` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_blood_and_thunder.md](sig_match_discipline_cards_blood_and_thunder.md) |
| `sig_match_discipline_cards_boiling_over` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_boiling_over.md](sig_match_discipline_cards_boiling_over.md) |
| `sig_match_discipline_cards_chaos_90_plus` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_chaos_90_plus.md](sig_match_discipline_cards_chaos_90_plus.md) |
| `sig_match_discipline_cards_clean_fair_play` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_clean_fair_play.md](sig_match_discipline_cards_clean_fair_play.md) |
| `sig_match_discipline_cards_card_frenzy` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_card_frenzy.md](sig_match_discipline_cards_card_frenzy.md) |
| `sig_match_discipline_cards_card_heavy_substitutions` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_card_heavy_substitutions.md](sig_match_discipline_cards_card_heavy_substitutions.md) |
| `sig_match_discipline_cards_double_red_drama` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_double_red_drama.md](sig_match_discipline_cards_double_red_drama.md) |
| `sig_match_discipline_cards_heated_derby_stats` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_heated_derby_stats.md](sig_match_discipline_cards_heated_derby_stats.md) |
| `sig_match_discipline_cards_physical_showdown` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_physical_showdown.md](sig_match_discipline_cards_physical_showdown.md) |
| `sig_match_discipline_cards_unpunished_aggression` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_unpunished_aggression.md](sig_match_discipline_cards_unpunished_aggression.md) |
| `sig_match_discipline_cards_referee_strictness` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_referee_strictness.md](sig_match_discipline_cards_referee_strictness.md) |
| `sig_match_discipline_cards_referee_showdown` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_referee_showdown.md](sig_match_discipline_cards_referee_showdown.md) |
| `sig_match_discipline_cards_one_sided_discipline` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_one_sided_discipline.md](sig_match_discipline_cards_one_sided_discipline.md) |
| `sig_match_discipline_cards_asymmetric_fouls` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_asymmetric_fouls.md](sig_match_discipline_cards_asymmetric_fouls.md) |
| `sig_match_discipline_cards_asymmetric_aggression` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_asymmetric_aggression.md](sig_match_discipline_cards_asymmetric_aggression.md) |
| `sig_match_discipline_cards_discipline_dominance` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_discipline_dominance.md](sig_match_discipline_cards_discipline_dominance.md) |
| `sig_match_discipline_cards_the_disciplined_siege` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_the_disciplined_siege.md](sig_match_discipline_cards_the_disciplined_siege.md) |
| `sig_match_discipline_cards_foul_parity` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_foul_parity.md](sig_match_discipline_cards_foul_parity.md) |
| `sig_match_discipline_cards_foul_heavy_stalemate` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_foul_heavy_stalemate.md](sig_match_discipline_cards_foul_heavy_stalemate.md) |
| `sig_match_discipline_cards_stop_start_hell` | team | discipline | cards | `match_team` | active | [sig_match_discipline_cards_stop_start_hell.md](sig_match_discipline_cards_stop_start_hell.md) |
| `sig_match_possession_passing_dead_zone_game` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_dead_zone_game.md](sig_match_possession_passing_dead_zone_game.md) |
| `sig_match_possession_passing_dribble_fest` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_dribble_fest.md](sig_match_possession_passing_dribble_fest.md) |
| `sig_match_possession_passing_heavy_rotation` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_heavy_rotation.md](sig_match_possession_passing_heavy_rotation.md) |
| `sig_match_possession_passing_momentum_swing` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_momentum_swing.md](sig_match_possession_passing_momentum_swing.md) |
| `sig_match_possession_passing_keeper_playmaking_battle` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_keeper_playmaking_battle.md](sig_match_possession_passing_keeper_playmaking_battle.md) |
| `sig_match_possession_passing_clean_game` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_clean_game.md](sig_match_possession_passing_clean_game.md) |
| `sig_match_possession_passing_high_turnover_affair` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_high_turnover_affair.md](sig_match_possession_passing_high_turnover_affair.md) |
| `sig_match_possession_passing_early_tactical_lock` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_early_tactical_lock.md](sig_match_possession_passing_early_tactical_lock.md) |
| `sig_match_possession_passing_counter_vs_bus` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_counter_vs_bus.md](sig_match_possession_passing_counter_vs_bus.md) |
| `sig_match_possession_passing_clinical_match` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_clinical_match.md](sig_match_possession_passing_clinical_match.md) |
| `sig_match_possession_passing_passing_clinic` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_passing_clinic.md](sig_match_possession_passing_passing_clinic.md) |
| `sig_match_possession_passing_possession_stalemate` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_possession_stalemate.md](sig_match_possession_passing_possession_stalemate.md) |
| `sig_match_possession_passing_set_piece_dominance` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_set_piece_dominance.md](sig_match_possession_passing_set_piece_dominance.md) |
| `sig_match_possession_passing_unproductive_game` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_unproductive_game.md](sig_match_possession_passing_unproductive_game.md) |
| `sig_match_possession_passing_wing_play_extravaganza` | team | possession | passing | `match_team` | active | [sig_match_possession_passing_wing_play_extravaganza.md](sig_match_possession_passing_wing_play_extravaganza.md) |
| `sig_match_shooting_goals_basketball_match` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_basketball_match.md](sig_match_shooting_goals_basketball_match.md) |
| `sig_match_shooting_goals_box_siege_match` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_box_siege_match.md](sig_match_shooting_goals_box_siege_match.md) |
| `sig_match_shooting_goals_boring_stalemate` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_boring_stalemate.md](sig_match_shooting_goals_boring_stalemate.md) |
| `sig_match_shooting_goals_clean_sheet_broken_late` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_clean_sheet_broken_late.md](sig_match_shooting_goals_clean_sheet_broken_late.md) |
| `sig_match_shooting_goals_clinical_showdown` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_clinical_showdown.md](sig_match_shooting_goals_clinical_showdown.md) |
| `sig_match_shooting_goals_clinical_sub_impact` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_clinical_sub_impact.md](sig_match_shooting_goals_clinical_sub_impact.md) |
| `sig_match_shooting_goals_complete_dominance` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_complete_dominance.md](sig_match_shooting_goals_complete_dominance.md) |
| `sig_match_shooting_goals_end_to_end_drama` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_end_to_end_drama.md](sig_match_shooting_goals_end_to_end_drama.md) |
| `sig_match_shooting_goals_early_goal_late_goal` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_early_goal_late_goal.md](sig_match_shooting_goals_early_goal_late_goal.md) |
| `sig_match_shooting_goals_distance_shooting_duel` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_distance_shooting_duel.md](sig_match_shooting_goals_distance_shooting_duel.md) |
| `sig_match_shooting_goals_game_of_two_halves` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_game_of_two_halves.md](sig_match_shooting_goals_game_of_two_halves.md) |
| `sig_match_shooting_goals_goal_fest` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_goal_fest.md](sig_match_shooting_goals_goal_fest.md) |
| `sig_match_shooting_goals_goalless_siege` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_goalless_siege.md](sig_match_shooting_goals_goalless_siege.md) |
| `sig_match_shooting_goals_high_xg_low_score` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_high_xg_low_score.md](sig_match_shooting_goals_high_xg_low_score.md) |
| `sig_match_shooting_goals_high_pressure_finish` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_high_pressure_finish.md](sig_match_shooting_goals_high_pressure_finish.md) |
| `sig_match_shooting_goals_high_volume_low_target` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_high_volume_low_target.md](sig_match_shooting_goals_high_volume_low_target.md) |
| `sig_match_shooting_goals_own_goal_drama` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_own_goal_drama.md](sig_match_shooting_goals_own_goal_drama.md) |
| `sig_match_shooting_goals_one_sided_shooting` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_one_sided_shooting.md](sig_match_shooting_goals_one_sided_shooting.md) |
| `sig_match_shooting_goals_penalty_decided_match` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_penalty_decided_match.md](sig_match_shooting_goals_penalty_decided_match.md) |
| `sig_match_shooting_goals_rapid_fire_exchange` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_rapid_fire_exchange.md](sig_match_shooting_goals_rapid_fire_exchange.md) |
| `sig_match_shooting_goals_shot_efficiency_parity` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_shot_efficiency_parity.md](sig_match_shooting_goals_shot_efficiency_parity.md) |
| `sig_match_shooting_goals_substituted_scoring_fest` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_substituted_scoring_fest.md](sig_match_shooting_goals_substituted_scoring_fest.md) |
| `sig_match_shooting_goals_the_brace_battle` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_the_brace_battle.md](sig_match_shooting_goals_the_brace_battle.md) |
| `sig_match_shooting_goals_unproductive_dominance` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_unproductive_dominance.md](sig_match_shooting_goals_unproductive_dominance.md) |
| `sig_match_shooting_goals_unlucky_game` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_unlucky_game.md](sig_match_shooting_goals_unlucky_game.md) |
| `sig_match_shooting_goals_woodwork_record_match` | team | shooting | goals | `match_team` | active | [sig_match_shooting_goals_woodwork_record_match.md](sig_match_shooting_goals_woodwork_record_match.md) |
| `sig_team_possession_passing_accurate_unit` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_accurate_unit.md](sig_team_possession_passing_accurate_unit.md) |
| `sig_team_possession_passing_aerial_reliance` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_aerial_reliance.md](sig_team_possession_passing_aerial_reliance.md) |
| `sig_team_possession_passing_cross_accuracy_peak` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_cross_accuracy_peak.md](sig_team_possession_passing_cross_accuracy_peak.md) |
| `sig_team_possession_passing_cross_spam` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_cross_spam.md](sig_team_possession_passing_cross_spam.md) |
| `sig_team_possession_passing_death_by_passes` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_death_by_passes.md](sig_team_possession_passing_death_by_passes.md) |
| `sig_team_possession_passing_dribble_heavy_attack` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_dribble_heavy_attack.md](sig_team_possession_passing_dribble_heavy_attack.md) |
| `sig_team_possession_passing_efficient_directness` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_efficient_directness.md](sig_team_possession_passing_efficient_directness.md) |
| `sig_team_possession_passing_passing_fatigue_index` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_passing_fatigue_index.md](sig_team_possession_passing_passing_fatigue_index.md) |
| `sig_team_possession_passing_failed_penetration` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_failed_penetration.md](sig_team_possession_passing_failed_penetration.md) |
| `sig_team_possession_passing_final_third_efficiency` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_final_third_efficiency.md](sig_team_possession_passing_final_third_efficiency.md) |
| `sig_team_possession_passing_high_press_victim` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_high_press_victim.md](sig_team_possession_passing_high_press_victim.md) |
| `sig_team_possession_passing_high_tempo_passing` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_high_tempo_passing.md](sig_team_possession_passing_high_tempo_passing.md) |
| `sig_team_possession_passing_keeper_involved` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_keeper_involved.md](sig_team_possession_passing_keeper_involved.md) |
| `sig_team_possession_passing_long_ball_desperation` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_long_ball_desperation.md](sig_team_possession_passing_long_ball_desperation.md) |
| `sig_team_possession_passing_low_block_frustration` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_low_block_frustration.md](sig_team_possession_passing_low_block_frustration.md) |
| `sig_team_possession_passing_one_sided_passing` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_one_sided_passing.md](sig_team_possession_passing_one_sided_passing.md) |
| `sig_team_possession_passing_pass_marathon` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_pass_marathon.md](sig_team_possession_passing_pass_marathon.md) |
| `sig_team_possession_passing_possession_without_purpose` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_possession_without_purpose.md](sig_team_possession_passing_possession_without_purpose.md) |
| `sig_team_possession_passing_possession_efficiency` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_possession_efficiency.md](sig_team_possession_passing_possession_efficiency.md) |
| `sig_team_possession_passing_press_resistance` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_press_resistance.md](sig_team_possession_passing_press_resistance.md) |
| `sig_team_possession_passing_second_half_possession_collapse` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_second_half_possession_collapse.md](sig_team_possession_passing_second_half_possession_collapse.md) |
| `sig_team_possession_passing_set_piece_focus` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_set_piece_focus.md](sig_team_possession_passing_set_piece_focus.md) |
| `sig_team_possession_passing_siege_mode` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_siege_mode.md](sig_team_possession_passing_siege_mode.md) |
| `sig_team_possession_passing_short_pass_philosophy` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_short_pass_philosophy.md](sig_team_possession_passing_short_pass_philosophy.md) |
| `sig_team_possession_passing_shot_per_possession` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_shot_per_possession.md](sig_team_possession_passing_shot_per_possession.md) |
| `sig_team_possession_passing_sterile_dominance` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_sterile_dominance.md](sig_team_possession_passing_sterile_dominance.md) |
| `sig_team_possession_passing_territorial_dominance` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_territorial_dominance.md](sig_team_possession_passing_territorial_dominance.md) |
| `sig_team_possession_passing_vertical_imbalance` | team | possession | passing | `match_team` | active | [sig_team_possession_passing_vertical_imbalance.md](sig_team_possession_passing_vertical_imbalance.md) |
| `sig_team_shooting_goals_blank_range` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_blank_range.md](sig_team_shooting_goals_blank_range.md) |
| `sig_team_shooting_goals_box_siege` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_box_siege.md](sig_team_shooting_goals_box_siege.md) |
| `sig_team_shooting_goals_conversion_collapse` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_conversion_collapse.md](sig_team_shooting_goals_conversion_collapse.md) |
| `sig_team_shooting_goals_dead_ball_specialists` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_dead_ball_specialists.md](sig_team_shooting_goals_dead_ball_specialists.md) |
| `sig_team_shooting_goals_set_piece_masterclass` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_set_piece_masterclass.md](sig_team_shooting_goals_set_piece_masterclass.md) |
| `sig_team_shooting_goals_early_blitz` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_early_blitz.md](sig_team_shooting_goals_early_blitz.md) |
| `sig_team_shooting_goals_half_time_talk_impact` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_half_time_talk_impact.md](sig_team_shooting_goals_half_time_talk_impact.md) |
| `sig_team_shooting_goals_long_range_barrage` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_long_range_barrage.md](sig_team_shooting_goals_long_range_barrage.md) |
| `sig_team_shooting_goals_no_shots_allowed` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_no_shots_allowed.md](sig_team_shooting_goals_no_shots_allowed.md) |
| `sig_team_shooting_goals_shot_on_target_monopoly` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_shot_on_target_monopoly.md](sig_team_shooting_goals_shot_on_target_monopoly.md) |
| `sig_team_shooting_goals_shot_shy` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_shot_shy.md](sig_team_shooting_goals_shot_shy.md) |
| `sig_team_shooting_goals_shot_accuracy_collapse` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_shot_accuracy_collapse.md](sig_team_shooting_goals_shot_accuracy_collapse.md) |
| `sig_team_shooting_goals_zero_shot_half` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_zero_shot_half.md](sig_team_shooting_goals_zero_shot_half.md) |
| `sig_team_shooting_goals_shooting_gallery` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_shooting_gallery.md](sig_team_shooting_goals_shooting_gallery.md) |
| `sig_team_shooting_goals_sustained_barrage` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_sustained_barrage.md](sig_team_shooting_goals_sustained_barrage.md) |
| `sig_team_shooting_goals_sustained_second_half_siege` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_sustained_second_half_siege.md](sig_team_shooting_goals_sustained_second_half_siege.md) |
| `sig_team_shooting_goals_late_game_salvage` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_late_game_salvage.md](sig_team_shooting_goals_late_game_salvage.md) |
| `sig_team_shooting_goals_late_surge_goals` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_late_surge_goals.md](sig_team_shooting_goals_late_surge_goals.md) |
| `sig_team_shooting_goals_rapid_double_salvo` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_rapid_double_salvo.md](sig_team_shooting_goals_rapid_double_salvo.md) |
| `sig_team_shooting_goals_rapid_response_goal` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_rapid_response_goal.md](sig_team_shooting_goals_rapid_response_goal.md) |
| `sig_team_discipline_cards_collective_aggression` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_collective_aggression.md](sig_team_discipline_cards_collective_aggression.md) |
| `sig_team_discipline_cards_aggression_spike` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_aggression_spike.md](sig_team_discipline_cards_aggression_spike.md) |
| `sig_team_discipline_cards_aggression_drop_off` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_aggression_drop_off.md](sig_team_discipline_cards_aggression_drop_off.md) |
| `sig_team_discipline_cards_early_warning` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_early_warning.md](sig_team_discipline_cards_early_warning.md) |
| `sig_team_discipline_cards_first_half_frenzy` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_first_half_frenzy.md](sig_team_discipline_cards_first_half_frenzy.md) |
| `sig_team_discipline_cards_the_triple_booking` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_the_triple_booking.md](sig_team_discipline_cards_the_triple_booking.md) |
| `sig_team_discipline_cards_half_time_talk_fail` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_half_time_talk_fail.md](sig_team_discipline_cards_half_time_talk_fail.md) |
| `sig_team_discipline_cards_frustration_peak` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_frustration_peak.md](sig_team_discipline_cards_frustration_peak.md) |
| `sig_team_discipline_cards_foul_efficiency` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_foul_efficiency.md](sig_team_discipline_cards_foul_efficiency.md) |
| `sig_team_discipline_cards_physical_superiority` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_physical_superiority.md](sig_team_discipline_cards_physical_superiority.md) |
| `sig_team_discipline_cards_zero_card_miracle` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_zero_card_miracle.md](sig_team_discipline_cards_zero_card_miracle.md) |
| `sig_team_discipline_cards_clean_discipline` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_clean_discipline.md](sig_team_discipline_cards_clean_discipline.md) |
| `sig_team_discipline_cards_clean_sheet_aggression` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_clean_sheet_aggression.md](sig_team_discipline_cards_clean_sheet_aggression.md) |
| `sig_team_discipline_cards_discipline_meltdown` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_discipline_meltdown.md](sig_team_discipline_cards_discipline_meltdown.md) |
| `sig_team_discipline_cards_total_implosion` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_total_implosion.md](sig_team_discipline_cards_total_implosion.md) |
| `sig_team_discipline_cards_man_down_resilience` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_man_down_resilience.md](sig_team_discipline_cards_man_down_resilience.md) |
| `sig_team_discipline_cards_red_card_neutralizer` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_red_card_neutralizer.md](sig_team_discipline_cards_red_card_neutralizer.md) |
| `sig_team_discipline_cards_systematic_fouling` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_systematic_fouling.md](sig_team_discipline_cards_systematic_fouling.md) |
| `sig_team_discipline_cards_midfield_enforcement` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_midfield_enforcement.md](sig_team_discipline_cards_midfield_enforcement.md) |
| `sig_team_discipline_cards_man_advantage_collapse` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_man_advantage_collapse.md](sig_team_discipline_cards_man_advantage_collapse.md) |
| `sig_team_discipline_cards_card_heavy_defeat` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_card_heavy_defeat.md](sig_team_discipline_cards_card_heavy_defeat.md) |
| `sig_team_discipline_cards_penalty_prone` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_penalty_prone.md](sig_team_discipline_cards_penalty_prone.md) |
| `sig_team_discipline_cards_away_hostility` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_away_hostility.md](sig_team_discipline_cards_away_hostility.md) |
| `sig_team_discipline_cards_hostile_territory` | team | discipline | cards | `match_team` | active | [sig_team_discipline_cards_hostile_territory.md](sig_team_discipline_cards_hostile_territory.md) |
| `sig_team_shooting_goals_ruthless_efficiency` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_ruthless_efficiency.md](sig_team_shooting_goals_ruthless_efficiency.md) |
| `sig_team_shooting_goals_efficiency_peak` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_efficiency_peak.md](sig_team_shooting_goals_efficiency_peak.md) |
| `sig_team_shooting_goals_clinical_finishing_streak` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_clinical_finishing_streak.md](sig_team_shooting_goals_clinical_finishing_streak.md) |
| `sig_team_shooting_goals_big_chance_efficiency` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_big_chance_efficiency.md](sig_team_shooting_goals_big_chance_efficiency.md) |
| `sig_team_shooting_goals_xg_overperformance_team` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_xg_overperformance_team.md](sig_team_shooting_goals_xg_overperformance_team.md) |
| `sig_team_shooting_goals_offensive_masterclass` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_offensive_masterclass.md](sig_team_shooting_goals_offensive_masterclass.md) |
| `sig_team_shooting_goals_high_quality_only` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_high_quality_only.md](sig_team_shooting_goals_high_quality_only.md) |
| `sig_team_shooting_goals_woodwork_frustration_team` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_woodwork_frustration_team.md](sig_team_shooting_goals_woodwork_frustration_team.md) |
| `sig_team_shooting_goals_expected_goal_dominance` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_expected_goal_dominance.md](sig_team_shooting_goals_expected_goal_dominance.md) |
| `sig_team_shooting_goals_wasteful_box_presence` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_wasteful_box_presence.md](sig_team_shooting_goals_wasteful_box_presence.md) |
| `sig_team_shooting_goals_shared_scoring` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_shared_scoring.md](sig_team_shooting_goals_shared_scoring.md) |
| `sig_team_shooting_goals_bench_goals_impact` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_bench_goals_impact.md](sig_team_shooting_goals_bench_goals_impact.md) |
| `sig_team_shooting_goals_clinical_bench_impact` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_clinical_bench_impact.md](sig_team_shooting_goals_clinical_bench_impact.md) |
| `sig_team_shooting_goals_defensive_scoring_unit` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_defensive_scoring_unit.md](sig_team_shooting_goals_defensive_scoring_unit.md) |
| `sig_team_shooting_goals_no_striker_needed` | team | shooting | goals | `match_team` | active | [sig_team_shooting_goals_no_striker_needed.md](sig_team_shooting_goals_no_striker_needed.md) |
| `sig_player_discipline_cards_early_bath` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_early_bath.md](sig_player_discipline_cards_early_bath.md) |
| `sig_player_discipline_cards_late_red_drama` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_late_red_drama.md](sig_player_discipline_cards_late_red_drama.md) |
| `sig_player_discipline_cards_captain_reprimand` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_captain_reprimand.md](sig_player_discipline_cards_captain_reprimand.md) |
| `sig_player_discipline_cards_double_yellow_dismissal` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_double_yellow_dismissal.md](sig_player_discipline_cards_double_yellow_dismissal.md) |
| `sig_player_discipline_cards_foul_magnet` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_foul_magnet.md](sig_player_discipline_cards_foul_magnet.md) |
| `sig_player_discipline_cards_heavy_hitter` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_heavy_hitter.md](sig_player_discipline_cards_heavy_hitter.md) |
| `sig_player_discipline_cards_dirty_half_dozen` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_dirty_half_dozen.md](sig_player_discipline_cards_dirty_half_dozen.md) |
| `sig_player_discipline_cards_penalty_conceder` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_penalty_conceder.md](sig_player_discipline_cards_penalty_conceder.md) |
| `sig_player_discipline_cards_iron_man_discipline` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_iron_man_discipline.md](sig_player_discipline_cards_iron_man_discipline.md) |
| `sig_player_discipline_cards_keeper_reckless` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_keeper_reckless.md](sig_player_discipline_cards_keeper_reckless.md) |
| `sig_player_discipline_cards_unnecessary_card` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_unnecessary_card.md](sig_player_discipline_cards_unnecessary_card.md) |
| `sig_player_discipline_cards_sub_card_speedrun` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_sub_card_speedrun.md](sig_player_discipline_cards_sub_card_speedrun.md) |
| `sig_player_discipline_cards_instant_impact_red` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_instant_impact_red.md](sig_player_discipline_cards_instant_impact_red.md) |
| `sig_player_discipline_cards_bench_discipline` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_bench_discipline.md](sig_player_discipline_cards_bench_discipline.md) |
| `sig_player_discipline_cards_walking_tightrope` | player | discipline | cards | `match_player` | active | [sig_player_discipline_cards_walking_tightrope.md](sig_player_discipline_cards_walking_tightrope.md) |
| `sig_player_goalkeeping_defense_brick_wall` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_brick_wall.md](sig_player_goalkeeping_defense_brick_wall.md) |
| `sig_player_goalkeeping_defense_clean_sheet_locked` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_clean_sheet_locked.md](sig_player_goalkeeping_defense_clean_sheet_locked.md) |
| `sig_player_goalkeeping_defense_interception_king` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_interception_king.md](sig_player_goalkeeping_defense_interception_king.md) |
| `sig_player_goalkeeping_defense_penalty_stopper` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_penalty_stopper.md](sig_player_goalkeeping_defense_penalty_stopper.md) |
| `sig_player_goalkeeping_defense_save_paralyzer` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_save_paralyzer.md](sig_player_goalkeeping_defense_save_paralyzer.md) |
| `sig_player_goalkeeping_defense_reflex_save_streak` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_reflex_save_streak.md](sig_player_goalkeeping_defense_reflex_save_streak.md) |
| `sig_player_goalkeeping_defense_aerial_stronghold` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_aerial_stronghold.md](sig_player_goalkeeping_defense_aerial_stronghold.md) |
| `sig_player_goalkeeping_defense_unbeaten_in_air` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_unbeaten_in_air.md](sig_player_goalkeeping_defense_unbeaten_in_air.md) |
| `sig_player_goalkeeping_defense_clearance_machine` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_clearance_machine.md](sig_player_goalkeeping_defense_clearance_machine.md) |
| `sig_player_goalkeeping_defense_tackle_master` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_tackle_master.md](sig_player_goalkeeping_defense_tackle_master.md) |
| `sig_player_goalkeeping_defense_shot_blocker_elite` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_shot_blocker_elite.md](sig_player_goalkeeping_defense_shot_blocker_elite.md) |
| `sig_player_goalkeeping_defense_recovery_engine` | player | goalkeeping | defense | `match_player` | active | [sig_player_goalkeeping_defense_recovery_engine.md](sig_player_goalkeeping_defense_recovery_engine.md) |
| `sig_player_shooting_goals_clinical_brace` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_clinical_brace.md](sig_player_shooting_goals_clinical_brace.md) |
| `sig_player_shooting_goals_the_tap_in_merchant` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_the_tap_in_merchant.md](sig_player_shooting_goals_the_tap_in_merchant.md) |
| `sig_player_shooting_goals_man_of_the_match_output` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_man_of_the_match_output.md](sig_player_shooting_goals_man_of_the_match_output.md) |
| `sig_player_shooting_goals_first_half_dominator` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_first_half_dominator.md](sig_player_shooting_goals_first_half_dominator.md) |
| `sig_player_shooting_goals_first_minute_goal` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_first_minute_goal.md](sig_player_shooting_goals_first_minute_goal.md) |
| `sig_player_shooting_goals_headers_only` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_headers_only.md](sig_player_shooting_goals_headers_only.md) |
| `sig_player_shooting_goals_hat_trick_hero` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_hat_trick_hero.md](sig_player_shooting_goals_hat_trick_hero.md) |
| `sig_player_shooting_goals_shot_volume_monster` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_shot_volume_monster.md](sig_player_shooting_goals_shot_volume_monster.md) |
| `sig_player_shooting_goals_high_volume_zero_test` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_high_volume_zero_test.md](sig_player_shooting_goals_high_volume_zero_test.md) |
| `sig_player_shooting_goals_box_dominator` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_box_dominator.md](sig_player_shooting_goals_box_dominator.md) |
| `sig_player_shooting_goals_volume_over_quality` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_volume_over_quality.md](sig_player_shooting_goals_volume_over_quality.md) |
| `sig_player_shooting_goals_shot_magnet` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_shot_magnet.md](sig_player_shooting_goals_shot_magnet.md) |
| `sig_player_shooting_goals_blocked_shot_frustration` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_blocked_shot_frustration.md](sig_player_shooting_goals_blocked_shot_frustration.md) |
| `sig_player_shooting_goals_shot_conversion_peak` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_shot_conversion_peak.md](sig_player_shooting_goals_shot_conversion_peak.md) |
| `sig_player_shooting_goals_high_xg_no_shot` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_high_xg_no_shot.md](sig_player_shooting_goals_high_xg_no_shot.md) |
| `sig_player_shooting_goals_high_velocity_finisher` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_high_velocity_finisher.md](sig_player_shooting_goals_high_velocity_finisher.md) |
| `sig_player_shooting_goals_xg_accumulator_midfielder` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_xg_accumulator_midfielder.md](sig_player_shooting_goals_xg_accumulator_midfielder.md) |
| `sig_player_shooting_goals_midfield_sniper` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_midfield_sniper.md](sig_player_shooting_goals_midfield_sniper.md) |
| `sig_player_shooting_goals_impact_accumulator` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_impact_accumulator.md](sig_player_shooting_goals_impact_accumulator.md) |
| `sig_player_shooting_goals_big_chance_bottler` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_big_chance_bottler.md](sig_player_shooting_goals_big_chance_bottler.md) |
| `sig_player_shooting_goals_sniper_accuracy` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_sniper_accuracy.md](sig_player_shooting_goals_sniper_accuracy.md) |
| `sig_player_shooting_goals_long_range_specialist` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_long_range_specialist.md](sig_player_shooting_goals_long_range_specialist.md) |
| `sig_player_shooting_goals_impossible_angle` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_impossible_angle.md](sig_player_shooting_goals_impossible_angle.md) |
| `sig_player_shooting_goals_distance_threat` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_distance_threat.md](sig_player_shooting_goals_distance_threat.md) |
| `sig_player_shooting_goals_freekick_master` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_freekick_master.md](sig_player_shooting_goals_freekick_master.md) |
| `sig_player_shooting_goals_one_man_army` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_one_man_army.md](sig_player_shooting_goals_one_man_army.md) |
| `sig_player_shooting_goals_persistent_threat` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_persistent_threat.md](sig_player_shooting_goals_persistent_threat.md) |
| `sig_player_shooting_goals_rapid_brace` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_rapid_brace.md](sig_player_shooting_goals_rapid_brace.md) |
| `sig_player_shooting_goals_clutch_brace_winning` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_clutch_brace_winning.md](sig_player_shooting_goals_clutch_brace_winning.md) |
| `sig_player_shooting_goals_clutch_equalizer` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_clutch_equalizer.md](sig_player_shooting_goals_clutch_equalizer.md) |
| `sig_player_shooting_goals_defensive_scorer` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_defensive_scorer.md](sig_player_shooting_goals_defensive_scorer.md) |
| `sig_player_shooting_goals_late_winner_clutch` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_late_winner_clutch.md](sig_player_shooting_goals_late_winner_clutch.md) |
| `sig_player_shooting_goals_super_sub_goal` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_super_sub_goal.md](sig_player_shooting_goals_super_sub_goal.md) |
| `sig_player_shooting_goals_winning_impact` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_winning_impact.md](sig_player_shooting_goals_winning_impact.md) |
| `sig_player_shooting_goals_wasteful_finisher` | player | shooting | goals | `match_player` | active | [sig_player_shooting_goals_wasteful_finisher.md](sig_player_shooting_goals_wasteful_finisher.md) |
| `sig_player_possession_passing_back_pass_heavy` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_back_pass_heavy.md](sig_player_possession_passing_back_pass_heavy.md) |
| `sig_player_possession_passing_box_penetrator` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_box_penetrator.md](sig_player_possession_passing_box_penetrator.md) |
| `sig_player_possession_passing_century_touches` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_century_touches.md](sig_player_possession_passing_century_touches.md) |
| `sig_player_possession_passing_creative_hub` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_creative_hub.md](sig_player_possession_passing_creative_hub.md) |
| `sig_player_possession_passing_final_third_engine` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_final_third_engine.md](sig_player_possession_passing_final_third_engine.md) |
| `sig_player_possession_passing_creative_monopoly` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_creative_monopoly.md](sig_player_possession_passing_creative_monopoly.md) |
| `sig_player_possession_passing_corner_specialist` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_corner_specialist.md](sig_player_possession_passing_corner_specialist.md) |
| `sig_player_possession_passing_deadball_creator` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_deadball_creator.md](sig_player_possession_passing_deadball_creator.md) |
| `sig_player_possession_passing_deep_playmaker` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_deep_playmaker.md](sig_player_possession_passing_deep_playmaker.md) |
| `sig_player_possession_passing_cross_heavy` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_cross_heavy.md](sig_player_possession_passing_cross_heavy.md) |
| `sig_player_possession_passing_dribble_threat` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_dribble_threat.md](sig_player_possession_passing_dribble_threat.md) |
| `sig_player_possession_passing_perfect_dribbler` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_perfect_dribbler.md](sig_player_possession_passing_perfect_dribbler.md) |
| `sig_player_possession_passing_flawless_distributor` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_flawless_distributor.md](sig_player_possession_passing_flawless_distributor.md) |
| `sig_player_possession_passing_high_risk_passer` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_high_risk_passer.md](sig_player_possession_passing_high_risk_passer.md) |
| `sig_player_possession_passing_high_turnover_risk` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_high_turnover_risk.md](sig_player_possession_passing_high_turnover_risk.md) |
| `sig_player_possession_passing_xa_overperformer` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_xa_overperformer.md](sig_player_possession_passing_xa_overperformer.md) |
| `sig_player_possession_passing_xa_underperformer` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_xa_underperformer.md](sig_player_possession_passing_xa_underperformer.md) |
| `sig_player_possession_passing_impact_sub_passing` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_impact_sub_passing.md](sig_player_possession_passing_impact_sub_passing.md) |
| `sig_player_possession_passing_isolated_target` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_isolated_target.md](sig_player_possession_passing_isolated_target.md) |
| `sig_player_possession_passing_accurate_long_range` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_accurate_long_range.md](sig_player_possession_passing_accurate_long_range.md) |
| `sig_player_possession_passing_keeper_distributor` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_keeper_distributor.md](sig_player_possession_passing_keeper_distributor.md) |
| `sig_player_possession_passing_keeper_launch_heavy` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_keeper_launch_heavy.md](sig_player_possession_passing_keeper_launch_heavy.md) |
| `sig_player_possession_passing_long_ball_specialist` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_long_ball_specialist.md](sig_player_possession_passing_long_ball_specialist.md) |
| `sig_player_possession_passing_target_man_aerials` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_target_man_aerials.md](sig_player_possession_passing_target_man_aerials.md) |
| `sig_player_possession_passing_midfield_general` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_midfield_general.md](sig_player_possession_passing_midfield_general.md) |
| `sig_player_possession_passing_midfield_workhorse` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_midfield_workhorse.md](sig_player_possession_passing_midfield_workhorse.md) |
| `sig_player_possession_passing_one_touch_specialist` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_one_touch_specialist.md](sig_player_possession_passing_one_touch_specialist.md) |
| `sig_player_possession_passing_overloaded_possession` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_overloaded_possession.md](sig_player_possession_passing_overloaded_possession.md) |
| `sig_player_possession_passing_recycling_specialist` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_recycling_specialist.md](sig_player_possession_passing_recycling_specialist.md) |
| `sig_player_possession_passing_redundant_possession` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_redundant_possession.md](sig_player_possession_passing_redundant_possession.md) |
| `sig_player_possession_passing_safe_outlet` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_safe_outlet.md](sig_player_possession_passing_safe_outlet.md) |
| `sig_player_possession_passing_switch_expert` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_switch_expert.md](sig_player_possession_passing_switch_expert.md) |
| `sig_player_possession_passing_under_pressure_expert` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_under_pressure_expert.md](sig_player_possession_passing_under_pressure_expert.md) |
| `sig_player_possession_passing_unsuccessful_crosser` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_unsuccessful_crosser.md](sig_player_possession_passing_unsuccessful_crosser.md) |
| `sig_player_possession_passing_volume_crosser` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_volume_crosser.md](sig_player_possession_passing_volume_crosser.md) |
| `sig_player_possession_passing_vertical_threat` | player | possession | passing | `match_player` | active | [sig_player_possession_passing_vertical_threat.md](sig_player_possession_passing_vertical_threat.md) |

Each per-signal catalog includes:

1. YAML metadata block
2. Purpose
3. Tactical and statistical logic
4. Technical assets (convention-based unless overridden)
5. Execution command
6. Output schema table with column description and reason
