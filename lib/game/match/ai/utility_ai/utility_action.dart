import 'package:baller/game/match/ai/utility_ai/consideration.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/world/world_models.dart';

/// The kind of tactical action an NPC or user player can perform.
enum CandidateActionType {
  shoot,
  shortPass,
  throughBall,
  longBall,
  dribble,
  clear,
}

/// A candidate action that a player can execute, scored via its [considerations].
class UtilityAction {
  const UtilityAction({
    required this.type,
    required this.name,
    required this.considerations,
    this.target,
  });

  final CandidateActionType type;
  final String name;
  final List<Consideration> considerations;

  /// The teammate receiver for pass actions, or target defender for dribbles.
  final SquadPlayer? target;

  /// Evaluates and sums all considerations for this action.
  double score(MatchDecisionContext context) {
    var total = 0.0;
    for (final c in considerations) {
      total += c.score(context);
    }
    return total;
  }

  /// Detailed breakdown of each consideration's score for debugging.
  Map<String, double> scoreBreakdown(MatchDecisionContext context) => {
    for (final (i, c) in considerations.indexed)
      c.label ?? 'c_$i': c.score(context),
  };

  @override
  String toString() => target != null
      ? 'UtilityAction($name -> ${target!.name})'
      : 'UtilityAction($name)';
}
