import 'package:baller/game/match/ai/utility_ai/core_considerations.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/ai/utility_ai/utility_action.dart';
import 'package:baller/game/world/world_models.dart';

/// The micro decision-making engine for an individual footballer on the pitch.
class PlayerBrain {
  const PlayerBrain._();

  /// Evaluates all available candidate actions and selects the highest scoring one.
  static UtilityAction decide(MatchDecisionContext context) {
    final candidates = generateCandidates(context);
    if (candidates.isEmpty) {
      // Fallback: simple hold/recycle pass
      return UtilityAction(
        type: CandidateActionType.shortPass,
        name: 'Recycle Possession',
        considerations: const [],
      );
    }

    UtilityAction bestAction = candidates.first;
    var bestScore = -1.0;

    for (final candidate in candidates) {
      // If candidate targets a specific receiver, evaluate with that target's context
      final actionContext = candidate.target != null
          ? context.withTarget(candidate.target!)
          : context;
      final score = candidate.score(actionContext);
      if (score > bestScore) {
        bestScore = score;
        bestAction = candidate;
      }
    }

    return bestAction;
  }

  /// Generates the list of viable actions a player can take in the current context.
  static List<UtilityAction> generateCandidates(MatchDecisionContext context) {
    final candidates = <UtilityAction>[];

    // 1. CLEARANCE (viable in own half/box)
    if (context.ballZone.isClearanceZone) {
      candidates.add(
        UtilityAction(
          type: CandidateActionType.clear,
          name: 'Clear Ball Out of Danger',
          considerations: [
            CoreConsiderations.clearanceUrgency(weight: 4.5),
            CoreConsiderations.statConfidence(
              statSelector: (p) => p.attributes.defence,
              weight: 2.0,
              label: 'Defensive clearance rating',
            ),
          ],
        ),
      );
    }

    // 2. SHOOT (viable in attacking zones)
    if (context.ballZone.isInShootingRange) {
      candidates.add(
        UtilityAction(
          type: CandidateActionType.shoot,
          name: 'Take the Shot',
          considerations: [
            CoreConsiderations.shotViability(weight: 3.0),
            CoreConsiderations.statConfidence(
              statSelector: (p) => p.attributes.shot,
              weight: 2.2,
              label: 'Shooting skill',
            ),
            CoreConsiderations.ego(
              weight: 2.5,
              label: 'Ego desire to score',
            ),
            CoreConsiderations.tacticalCompliance(
              tacticFactor: (ctx) => (ctx.tactics.shootMultiplier / 2.0).clamp(0.0, 1.0),
              baseWeight: 1.8,
              label: 'Coach shoot instruction',
            ),
          ],
        ),
      );
    }

    // 3. DRIBBLE (take on defender / carry forward)
    candidates.add(
      UtilityAction(
        type: CandidateActionType.dribble,
        name: 'Take On Defender',
        considerations: [
          CoreConsiderations.dribbleViability(weight: 2.0),
          CoreConsiderations.statConfidence(
            statSelector: (p) => p.attributes.dribble,
            weight: 2.0,
            label: 'Dribbling skill',
          ),
          CoreConsiderations.ego(
            weight: 1.8,
            label: 'Ego 1-on-1 confidence',
          ),
          CoreConsiderations.tacticalCompliance(
            tacticFactor: (ctx) => (ctx.tactics.dribbleMultiplier / 2.0).clamp(0.0, 1.0),
            baseWeight: 1.4,
            label: 'Coach dribble instruction',
          ),
        ],
      ),
    );

    // 4. PASS ACTIONS (evaluate viable teammate targets)
    final passTargets = context.teammates
        .where((t) => t.id != context.actor.id && t.role != SquadRole.gk)
        .toList();

    for (final target in passTargets) {
      candidates.add(
        UtilityAction(
          type: CandidateActionType.shortPass,
          name: 'Pass to ${target.name}',
          target: target,
          considerations: [
            CoreConsiderations.openness(weight: 2.2),
            CoreConsiderations.chemistry(weight: 1.8),
            CoreConsiderations.passSafety(weight: 2.5),
            CoreConsiderations.statConfidence(
              statSelector: (p) => p.attributes.pass,
              weight: 1.6,
              label: 'Passing skill',
            ),
            CoreConsiderations.tacticalCompliance(
              tacticFactor: (ctx) => (ctx.tactics.passMultiplier / 2.0).clamp(0.0, 1.0),
              baseWeight: 2.0,
              label: 'Coach pass instruction',
            ),
          ],
        ),
      );
    }

    return candidates;
  }
}
