import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/response_curves.dart';

/// A single factor in evaluating an action's score.
///
/// Returns a normalized score (0.0 to 1.0), passes it through a [CurveType],
/// and multiplies by [weight].
class Consideration {
  const Consideration({
    required this.evaluate,
    this.weight = 1.0,
    this.curve = CurveType.linear,
    this.label,
  });

  /// The evaluation function returning a raw value between 0.0 and 1.0.
  final double Function(MatchDecisionContext context) evaluate;

  /// Importance weight of this consideration relative to others.
  final double weight;

  /// Non-linear response curve applied to the raw evaluated score.
  final CurveType curve;

  /// Optional label for debugging and inspection.
  final String? label;

  /// Calculates the weighted score for this consideration in the given [context].
  double score(MatchDecisionContext context) {
    final raw = evaluate(context);
    final curved = applyCurve(raw, curve);
    return curved * weight;
  }

  @override
  String toString() => label != null
      ? 'Consideration($label, w: $weight, c: $curve)'
      : 'Consideration(w: $weight, c: $curve)';
}
