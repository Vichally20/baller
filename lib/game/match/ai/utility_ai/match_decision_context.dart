import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/world/world_models.dart';

/// The game context provided to Utility AI considerations to score actions.
class MatchDecisionContext {
  const MatchDecisionContext({
    required this.actor,
    required this.ballZone,
    required this.tactics,
    this.target,
    this.minute = 45,
    this.goalDifference = 0,
    this.actorStamina = 1.0,
    this.defendersInWay = 1,
    this.targetOpenness = 0.7,
    this.teammates = const [],
    this.opponents = const [],
  });

  /// The footballer actively making the decision.
  final SquadPlayer actor;

  /// The potential target of the action (pass receiver or opposing defender).
  final SquadPlayer? target;

  /// The pitch area where the ball currently is.
  final PitchZone ballZone;

  /// Active tactical state set by the coach's Behavior Tree.
  final TacticalState tactics;

  /// Current match minute.
  final int minute;

  /// Goal difference from the actor's team perspective.
  final int goalDifference;

  /// Current player fatigue level (1.0 = fully fresh, 0.0 = exhausted).
  final double actorStamina;

  /// Number of defending players blocking direct path to goal or target.
  final int defendersInWay;

  /// How unmarked/open the [target] receiver is (0.0 = blanketed, 1.0 = wide open).
  final double targetOpenness;

  /// Teammates currently on the pitch.
  final List<SquadPlayer> teammates;

  /// Opponents currently on the pitch.
  final List<SquadPlayer> opponents;

  /// Copies this context with a specific [target] and [targetOpenness].
  MatchDecisionContext withTarget(SquadPlayer target, {double openness = 0.7}) =>
      MatchDecisionContext(
        actor: actor,
        ballZone: ballZone,
        tactics: tactics,
        target: target,
        minute: minute,
        goalDifference: goalDifference,
        actorStamina: actorStamina,
        defendersInWay: defendersInWay,
        targetOpenness: openness,
        teammates: teammates,
        opponents: opponents,
      );
}
