import 'dart:math';

import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/season_progress.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

export 'package:baller/game/models/season_progress.dart';

/// Season mode: once the written story runs out, a signed player plays
/// their club's league season, round by round. Everything except the
/// player's own results is worked out from the world's seed, so a save
/// only keeps [SeasonProgress].

/// Scenes before each league match.
const int scenesPerRound = 2;

/// One league game.
class Fixture {
  const Fixture({required this.round, required this.home, required this.away});

  /// 0-based.
  final int round;
  final Club home;
  final Club away;

  bool involves(Club club) => home.id == club.id || away.id == club.id;
}

/// A double round robin: every club plays every other home and away,
/// 38 rounds for 20 clubs. The order is shuffled per season.
List<List<Fixture>> buildFixtures(List<Club> clubs, Random rng) {
  final teams = List.of(clubs)..shuffle(rng);
  final n = teams.length;
  final half = <List<(Club, Club)>>[];
  // Circle method: the first team stays put, the rest rotate.
  var rotating = teams.sublist(1);
  for (var r = 0; r < n - 1; r++) {
    final line = [teams.first, ...rotating];
    final pairs = <(Club, Club)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = line[i];
      final b = line[n - 1 - i];
      // Alternate who is at home so nobody plays only home or away.
      pairs.add((r + i).isEven ? (a, b) : (b, a));
    }
    half.add(pairs);
    rotating = [rotating.last, ...rotating.sublist(0, rotating.length - 1)];
  }
  return [
    for (final (r, pairs) in half.indexed)
      [for (final (h, a) in pairs) Fixture(round: r, home: h, away: a)],
    for (final (r, pairs) in half.indexed)
      [for (final (h, a) in pairs) Fixture(round: r + n - 1, home: a, away: h)],
  ];
}

/// A simulated score for a game the player isn't in, from the two squads'
/// average ratings, with a little home advantage.
(int, int) simulateScore(Fixture f, Random rng) {
  final gap = f.home.averageRating - f.away.averageRating;
  final homeRate = 1.45 * pow(1.05, gap);
  final awayRate = 1.15 * pow(1.05, -gap);
  return (
    _poisson(homeRate.toDouble(), rng),
    _poisson(awayRate.toDouble(), rng),
  );
}

int _poisson(double rate, Random rng) {
  final limit = exp(-rate);
  var k = 0;
  var p = rng.nextDouble();
  while (p > limit && k < 9) {
    k++;
    p *= rng.nextDouble();
  }
  return k;
}

/// One line of the league table.
class LeagueRow {
  LeagueRow(this.club);

  final Club club;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => won * 3 + drawn;
  int get goalDifference => goalsFor - goalsAgainst;

  void add(int scored, int conceded) {
    played++;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      won++;
    } else if (scored == conceded) {
      drawn++;
    } else {
      lost++;
    }
  }
}

/// The player's season as it stands: fixtures, results and table.
class Season {
  Season._({
    required this.progress,
    required this.club,
    required this.youth,
    required this.rounds,
    required this.table,
    required this.scores,
  });

  final SeasonProgress progress;

  /// The player's club.
  final Club club;

  /// Academy players play the clubs' youth sides.
  final bool youth;
  final List<List<Fixture>> rounds;

  /// Best first: points, then goal difference, then goals scored.
  final List<LeagueRow> table;

  /// Per round, per fixture: the score, or null if not played yet.
  final List<List<(int, int)?>> scores;

  /// The score of fixture [index] in [round] (home goals first), or null
  /// if it hasn't been played.
  (int, int)? scoreOf(int round, int index) => scores[round][index];

  String get leagueName => youth
      ? '${club.country.label} U18 League'
      : League.nameOf(club.country, club.division);

  bool get isOver => progress.round >= rounds.length;

  /// The player's next match, or null when the season is over.
  Fixture? get nextFixture => isOver
      ? null
      : rounds[progress.round].firstWhere((f) => f.involves(club));

  /// The player's club's place, 1-based.
  int get position => table.indexWhere((r) => r.club.id == club.id) + 1;

  /// How a side is named in this league ("Ashbury Rovers U18" for youth).
  String sideName(Club c) => youth ? '${c.name} U18' : c.name;
}

/// The seed a career's season [season] is played from.
int seasonSeed(Player player, int season) =>
    player.worldSeed ^ (season * 104729);

/// The seed of a division's season. The player's own senior division uses
/// [base] itself; every other division (and the senior side of a youth
/// player's league) gets its own.
int divisionSeed(
  int base,
  LeagueCountry country,
  int division, {
  bool players = false,
}) => players
    ? base
    : base ^ ((country.index + 1) * 7368787 + division * 2750159);

/// The seed of one simulated game.
int fixtureSeed(int divisionSeed, int round, int index) =>
    divisionSeed ^ (round * 1009 + index * 31 + 7);

/// A division's season after [roundsPlayed] rounds: fixtures, scores and
/// table. Games involving [club] take their scores from [results]
/// (club's goals first); the rest are simulated from [seed].
class DivisionSeason {
  DivisionSeason._(this.rounds, this.scores, this.table);

  final List<List<Fixture>> rounds;

  /// Per round, per fixture: the score (home goals first), or null if not
  /// played yet.
  final List<List<(int, int)?>> scores;

  /// Best first: points, then goal difference, then goals scored.
  final List<LeagueRow> table;
}

DivisionSeason simulateDivision(
  List<Club> clubs,
  int seed,
  int roundsPlayed, {
  Club? club,
  List<(int, int)> results = const [],
}) {
  final rounds = buildFixtures(clubs, Random(seed));
  final rows = {for (final c in clubs) c.id: LeagueRow(c)};
  final scores = [
    for (final round in rounds) List<(int, int)?>.filled(round.length, null),
  ];
  for (var r = 0; r < roundsPlayed && r < rounds.length; r++) {
    for (final (i, f) in rounds[r].indexed) {
      final mine = club != null && f.involves(club) && r < results.length;
      final (h, a) = mine
          ? (f.home.id == club.id ? results[r] : (results[r].$2, results[r].$1))
          : simulateScore(f, Random(fixtureSeed(seed, r, i)));
      scores[r][i] = (h, a);
      rows[f.home.id]!.add(h, a);
      rows[f.away.id]!.add(a, h);
    }
  }
  final table = rows.values.toList()
    ..sort((x, y) {
      final byPoints = y.points.compareTo(x.points);
      if (byPoints != 0) return byPoints;
      final byGd = y.goalDifference.compareTo(x.goalDifference);
      if (byGd != 0) return byGd;
      return y.goalsFor.compareTo(x.goalsFor);
    });
  return DivisionSeason._(rounds, scores, table);
}

/// The season for a signed player, or null before they've signed.
Season? seasonFor(Player player, World world, SeasonProgress progress) {
  final career = careerClubOf(player, world);
  if (career == null || !career.placement.signed) return null;
  final club = career.club;
  final youth = playsYouthFootball(player, career.placement);
  final clubs = world.leagues
      .firstWhere((l) => l.country == club.country)
      .divisions[club.division - 1];
  final played = simulateDivision(
    clubs,
    seasonSeed(player, progress.season),
    progress.round,
    club: club,
    results: progress.results,
  );
  return Season._(
    progress: progress,
    club: club,
    youth: youth,
    rounds: played.rounds,
    table: played.table,
    scores: played.scores,
  );
}
