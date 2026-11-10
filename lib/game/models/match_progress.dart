/// A match the player has started but not finished, saved after every move
/// so leaving and coming back carries on where they left off.
///
/// The match engine only uses one seeded random number generator, so the
/// seed plus the moves played rebuild the exact same match.
class MatchProgress {
  const MatchProgress({
    required this.key,
    required this.seed,
    this.moves = const [],
    this.secondHalf = false,
  });

  /// Which match this is, e.g. "story:5" or "season:1:12".
  final String key;
  final int seed;

  /// The player's moves so far, by name ("shoot", "pass"…).
  final List<String> moves;

  /// The second half has been started.
  final bool secondHalf;

  MatchProgress withMove(String move) => MatchProgress(
    key: key,
    seed: seed,
    moves: List.unmodifiable([...moves, move]),
    secondHalf: secondHalf,
  );

  MatchProgress startSecondHalf() =>
      MatchProgress(key: key, seed: seed, moves: moves, secondHalf: true);

  Map<String, Object?> toJson() => {
    'key': key,
    'seed': seed,
    'moves': moves,
    'secondHalf': secondHalf,
  };

  /// Null when [json] is malformed.
  static MatchProgress? fromJson(Object? json) {
    if (json
        case {
          'key': final String key,
          'seed': final int seed,
          'moves': final List<Object?> moves,
          'secondHalf': final bool secondHalf,
        }
        when moves.every((m) => m is String)) {
      return MatchProgress(
        key: key,
        seed: seed,
        moves: List.unmodifiable(moves.cast<String>()),
        secondHalf: secondHalf,
      );
    }
    return null;
  }
}
