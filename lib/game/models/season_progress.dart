/// A goal in one of the player's own league matches.
class RoundGoal {
  const RoundGoal({required this.mine, required this.scorerId, this.assistId});

  /// Scored by the player's side.
  final bool mine;

  /// Squad player ids; the player themselves is `user-player`.
  final String scorerId;
  final String? assistId;

  List<Object?> toJson() => [if (mine) 1 else 0, scorerId, assistId];

  static RoundGoal? fromJson(Object? json) => switch (json) {
    [final int mine, final String scorer, final String? assist] => RoundGoal(
      mine: mine == 1,
      scorerId: scorer,
      assistId: assist,
    ),
    _ => null,
  };
}

/// How far through the league the player is.
class SeasonProgress {
  const SeasonProgress({
    this.season = 1,
    this.results = const [],
    this.goals = const [],
    this.scenesPlayed = 0,
  });

  static const first = SeasonProgress();

  /// 1-based.
  final int season;

  /// The player's results so far, one per round: (your goals, theirs).
  final List<(int, int)> results;

  /// Who scored in each of [results] (empty for rounds saved before
  /// scorers were kept).
  final List<List<RoundGoal>> goals;

  /// Scenes played since the last match (the next match comes after
  /// [scenesPerRound]).
  final int scenesPlayed;

  int get round => results.length;

  /// The goals of round [r] (0-based).
  List<RoundGoal> goalsIn(int r) => r < goals.length ? goals[r] : const [];

  SeasonProgress sceneDone() => SeasonProgress(
    season: season,
    results: results,
    goals: goals,
    scenesPlayed: scenesPlayed + 1,
  );

  SeasonProgress record(
    int goalsFor,
    int goalsAgainst, {
    List<RoundGoal> scorers = const [],
  }) => SeasonProgress(
    season: season,
    results: List.unmodifiable([...results, (goalsFor, goalsAgainst)]),
    goals: List.unmodifiable([
      for (var r = 0; r < results.length; r++) goalsIn(r),
      List<RoundGoal>.unmodifiable(scorers),
    ]),
  );

  SeasonProgress nextSeason() => SeasonProgress(season: season + 1);

  Map<String, Object?> toJson() => {
    'season': season,
    'results': [
      for (final (f, a) in results) [f, a],
    ],
    'goals': [
      for (var r = 0; r < results.length; r++)
        [for (final g in goalsIn(r)) g.toJson()],
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
      final goals = <List<RoundGoal>>[];
      if (json['goals'] case final List<Object?> rounds) {
        for (final round in rounds.take(results.length)) {
          if (round is! List<Object?>) return null;
          final list = <RoundGoal>[];
          for (final g in round) {
            final goal = RoundGoal.fromJson(g);
            if (goal == null) return null;
            list.add(goal);
          }
          goals.add(List.unmodifiable(list));
        }
      }
      return SeasonProgress(
        season: season,
        results: List.unmodifiable(results),
        goals: List.unmodifiable(goals),
        scenesPlayed: scenes,
      );
    }
    return null;
  }
}
