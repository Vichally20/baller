import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';

/// Read-only snapshot of the match state passed to the Coach Behavior Tree.
class CoachSnapshot {
  const CoachSnapshot({
    required this.minute,
    required this.goalDifference,
    required this.possessionPercentage,
    required this.tactics,
    this.concededRecently = false,
    this.teamStaminaAverage = 100.0,
  });

  /// Current match minute (1–90+).
  final int minute;

  /// Goal difference from this team's perspective (> 0 winning, < 0 losing).
  final int goalDifference;

  /// Possession share in percent (0.0–100.0).
  final double possessionPercentage;

  /// The active tactical state being evaluated and mutated.
  final TacticalState tactics;

  /// True if the team conceded in the last 10 minutes.
  final bool concededRecently;

  /// Average stamina of the active players on pitch (0–100).
  final double teamStaminaAverage;
}

