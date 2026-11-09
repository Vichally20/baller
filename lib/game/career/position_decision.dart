import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/world_models.dart';

/// Where a manager plays the player. See docs/career-design.md §4.
class PositionDecision {
  const PositionDecision({
    required this.position,
    required this.wish,
    required this.best,
    required this.gap,
    required this.philosophy,
    this.second,
  });

  /// Where the manager plays the player.
  final Position position;

  /// New hybrid managers also use the player here.
  final Position? second;

  /// The position the player asked for.
  final Position wish;

  /// The player's best-rated position.
  final Position best;

  /// Rating points between [best] and [wish] (0 when they're the same).
  final int gap;
  final Philosophy philosophy;

  bool get honoured => position == wish;

  /// One or two sentences explaining the decision.
  String get reason {
    if (wish == best) {
      return '${wish.label} is what you asked for and where you fit best.';
    }
    final tolerance = philosophy.preferenceTolerance;
    if (tolerance == null) {
      return 'Traditional managers play you where you fit best, whatever '
          'you want. You rate $gap higher at ${best.label}.';
    }
    if (honoured) {
      return 'Your ${wish.label} rating is within $tolerance of your best, '
          'so the manager honours your wish.';
    }
    final rule =
        'Your ${wish.label} rating is $gap below your best, and '
        '${philosophy.label} managers only honour a wish within $tolerance.';
    return second == wish
        ? "$rule You'll still get games there when the team rotates."
        : rule;
  }
}

/// The manager's call: Traditional plays the best fit; Modern progressive
/// honours the wish within 5; New hybrid within 3, and also uses the player
/// in a second position.
PositionDecision decidePosition({
  required PlayerAttributes stats,
  required Position wish,
  required Philosophy philosophy,
}) {
  final ranked = Position.ranked(stats);
  final (best, bestRating) = ranked.first;
  final gap = bestRating - wish.rating(stats);
  final tolerance = philosophy.preferenceTolerance;
  final position = tolerance != null && gap <= tolerance ? wish : best;
  Position? second;
  if (philosophy == Philosophy.newHybrid) {
    // The other of wish and best; if they're the same, the next best fit.
    second = position != best
        ? best
        : position != wish
        ? wish
        : ranked[1].$1;
  }
  return PositionDecision(
    position: position,
    second: second,
    wish: wish,
    best: best,
    gap: gap,
    philosophy: philosophy,
  );
}
