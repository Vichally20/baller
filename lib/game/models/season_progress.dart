/// How far through the league the player is.
class SeasonProgress {
  const SeasonProgress({
    this.season = 1,
    this.results = const [],
    this.scenesPlayed = 0,
  });

  static const first = SeasonProgress();

  /// 1-based.
  final int season;

  /// The player's results so far, one per round: (your goals, theirs).
  final List<(int, int)> results;

  /// Scenes played since the last match (the next match comes after
  /// [scenesPerRound]).
  final int scenesPlayed;

  int get round => results.length;

  SeasonProgress sceneDone() => SeasonProgress(
    season: season,
    results: results,
    scenesPlayed: scenesPlayed + 1,
  );

  SeasonProgress record(int goalsFor, int goalsAgainst) => SeasonProgress(
    season: season,
    results: List.unmodifiable([...results, (goalsFor, goalsAgainst)]),
  );

  SeasonProgress nextSeason() => SeasonProgress(season: season + 1);

  Map<String, Object?> toJson() => {
    'season': season,
    'results': [
      for (final (f, a) in results) [f, a],
    ],
    'scenes': scenesPlayed,
  };

  /// Null when [json] is malformed.
  static SeasonProgress? fromJson(Object? json) {
    if (json
        case {
          'season': final int season,
          'results': final List<Object?> raw,
          'scenes': final int scenes,
        }
        when season >= 1 && scenes >= 0) {
      final results = <(int, int)>[];
      for (final r in raw) {
        if (r case [final int f, final int a] when f >= 0 && a >= 0) {
          results.add((f, a));
        } else {
          return null;
        }
      }
      return SeasonProgress(
        season: season,
        results: List.unmodifiable(results),
        scenesPlayed: scenes,
      );
    }
    return null;
  }
}
