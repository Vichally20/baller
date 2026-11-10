import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/world/world_models.dart';

/// The result of an in-match action contest.
enum ContestResult {
  goal,
  saved,
  blocked,
  miss,
  passCompleted,
  turnover,
  dribbleSuccess,
  tackled,
  foul,
}

/// Rich outcome data returned from resolving an action.
class ContestOutcome {
  const ContestOutcome({
    required this.result,
    required this.text,
    required this.nextState,
    this.scoringSide,
    this.actor,
    this.target,
    this.isUserMove = false,
    this.talentName,
  });

  final ContestResult result;
  final String text;
  final PlayState nextState;
  final Side? scoringSide;
  final SquadPlayer? actor;
  final SquadPlayer? target;
  final bool isUserMove;

  /// The talent that triggered on this action, if any.
  final String? talentName;

  bool get isGoal => scoringSide != null;
}
