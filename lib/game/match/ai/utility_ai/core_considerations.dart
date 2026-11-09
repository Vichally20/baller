import 'package:baller/game/match/ai/utility_ai/consideration.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/ai/utility_ai/response_curves.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/world_models.dart';

/// Predefined Considerations for the Football Utility AI engine.
class CoreConsiderations {
  const CoreConsiderations._();

  /// EGO: High ego players heavily bias toward shooting and taking on defenders alone.
  ///
  /// Uses an exponential curve: players with average ego (40-60) get negligible bonus,
  /// but extreme ego (85-99) produces a massive spike, replicating Blue Lock mechanics.
  static Consideration ego({double weight = 2.5, String label = 'Ego Impulse'}) =>
      Consideration(
        label: label,
        weight: weight,
        curve: CurveType.exponential,
        evaluate: (ctx) => ctx.actor.attributes.ego / 100.0,
      );

  /// TACTICAL COMPLIANCE: How strongly the player obeys the coach's active instructions.
  ///
  /// Multiplies the coach's tactic multiplier by the player's tactical discipline.
  static Consideration tacticalCompliance({
    required double Function(MatchDecisionContext) tacticFactor,
    double baseWeight = 2.0,
    String label = 'Tactical Compliance',
  }) => Consideration(
    label: label,
    weight: baseWeight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      final disciplineFactor = ctx.actor.attributes.tacticalDiscipline / 60.0;
      final rawFactor = tacticFactor(ctx);
      return (rawFactor * disciplineFactor).clamp(0.0, 1.0);
    },
  );

  /// CHEMISTRY: Evaluates link synergy between the passer and the intended receiver.
  static Consideration chemistry({
    double weight = 1.8,
    String label = 'Teammate Chemistry',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      final target = ctx.target;
      if (target == null) return 0.5;

      var chem = 0.55; // Base teammate chemistry
      // Adjacent position synergy (e.g. CM to AM, FB to W, AM to ST)
      if (_areAdjacent(ctx.actor.role, target.role)) {
        chem += 0.20;
      }
      // High teamwork enhances chemistry connection
      chem += (ctx.actor.attributes.teamwork / 100.0) * 0.25;

      return chem.clamp(0.0, 1.0);
    },
  );

  /// OPENNESS: Rewards passing to receivers who are unmarked.
  static Consideration openness({
    double weight = 2.0,
    String label = 'Target Openness',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.quadratic,
    evaluate: (ctx) => ctx.targetOpenness,
  );

  /// SHOT VIABILITY: Evaluates distance to goal and defenders blocking the lane.
  static Consideration shotViability({
    double weight = 2.5,
    String label = 'Shot Viability',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      final zoneMult = ctx.ballZone.shotViabilityMultiplier;
      final defenderPenalty = (ctx.defendersInWay * 0.15).clamp(0.0, 0.6);
      return (zoneMult - defenderPenalty).clamp(0.0, 1.0);
    },
  );

  /// STAT CONFIDENCE: Player's technical rating for executing this action.
  static Consideration statConfidence({
    required int Function(SquadPlayer) statSelector,
    double weight = 1.5,
    String label = 'Stat Confidence',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.quadratic,
    evaluate: (ctx) => (statSelector(ctx.actor) / 100.0).clamp(0.0, 1.0),
  );

  /// CLEARANCE NECESSITY: Urgency to boot the ball away when under siege in defense.
  static Consideration clearanceUrgency({
    double weight = 4.0,
    String label = 'Clearance Urgency',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      if (ctx.ballZone == PitchZone.ownBox) {
        return (0.7 + ctx.defendersInWay * 0.15).clamp(0.0, 1.0);
      }
      if (ctx.ballZone == PitchZone.ownHalf && ctx.defendersInWay >= 2) {
        return 0.5;
      }
      return 0.0;
    },
  );

  /// PASS SAFETY: Heavily penalizes dangerous passes when swarmed in own defensive box.
  static Consideration passSafety({
    double weight = 2.5,
    String label = 'Pass Safety Risk',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      if (ctx.ballZone == PitchZone.ownBox) {
        return (1.0 - (ctx.defendersInWay * 0.30)).clamp(0.0, 1.0);
      }
      if (ctx.ballZone == PitchZone.ownHalf && ctx.defendersInWay >= 2) {
        return 0.5;
      }
      return 1.0;
    },
  );

  /// DRIBBLE SPACE: Evaluates 1-on-1 chance when space opens ahead.
  static Consideration dribbleViability({
    double weight = 1.6,
    String label = 'Dribble Viability',
  }) => Consideration(
    label: label,
    weight: weight,
    curve: CurveType.linear,
    evaluate: (ctx) {
      // Dribbling is best in midfield and attacking third with 1 defender
      if (ctx.ballZone == PitchZone.ownBox) return 0.1; // Reckless in own box
      final space = ctx.defendersInWay <= 1 ? 0.8 : (1.0 / ctx.defendersInWay);
      return space.clamp(0.0, 1.0);
    },
  );

  /// Checks if two formation roles have natural passing link proximity.
  static bool _areAdjacent(SquadRole a, SquadRole b) {
    if (a == b) return false;
    return switch ((a, b)) {
      (SquadRole.cb, SquadRole.fb) || (SquadRole.fb, SquadRole.cb) => true,
      (SquadRole.cb, SquadRole.dm) || (SquadRole.dm, SquadRole.cb) => true,
      (SquadRole.dm, SquadRole.cm) || (SquadRole.cm, SquadRole.dm) => true,
      (SquadRole.cm, SquadRole.am) || (SquadRole.am, SquadRole.cm) => true,
      (SquadRole.cm, SquadRole.w) || (SquadRole.w, SquadRole.cm) => true,
      (SquadRole.am, SquadRole.st) || (SquadRole.st, SquadRole.am) => true,
      (SquadRole.w, SquadRole.st) || (SquadRole.st, SquadRole.w) => true,
      (SquadRole.fb, SquadRole.w) || (SquadRole.w, SquadRole.fb) => true,
      _ => false,
    };
  }
}
