import 'dart:math';

import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/match/goal_credit.dart';
import 'package:baller/game/match/lineup.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

/// Player numbers for every senior division: goals, assists, clean sheets
/// and appearances, and the awards when a season ends. PROVISIONAL rules
/// (docs/career-design.md §11):
///
/// - Each club's first-choice eleven (its manager's formation) plays every
///   game. Goals in simulated games go to one of the eleven by role and
///   Shot; 70% have an assist, by role and Pass.
/// - In the player's own league matches, the engine says who scored.
/// - The keeper gets a clean sheet when his side concedes nothing.

/// One player's season so far.
class PlayerLine {
  PlayerLine({
    required this.id,
    required this.name,
    required this.club,
    required this.role,
    required this.age,
    required this.rating,
    this.isUser = false,
  });

  final String id;
  final String name;
  final Club club;
  final SquadRole role;
  final int age;
  final int rating;

  /// The career's own player.
  final bool isUser;

  int apps = 0;
  int goals = 0;
  int assists = 0;
  int cleanSheets = 0;

  /// For Player of the Season: goals, assists, clean sheets at the back,
  /// how good they are and where their club finished ([finish], 1-based).
  double score(int finish, int clubs) =>
      goals * 3 +
      assists * 2.5 +
      (_defensive.contains(role) ? cleanSheets * 2 : 0) +
      rating +
      max(0, clubs + 1 - finish) * 0.75;

  static const _defensive = {SquadRole.gk, SquadRole.cb, SquadRole.fb};
}

/// A division's season as it stands, with everyone's numbers.
class LeagueStats {
  LeagueStats._({
    required this.country,
    required this.division,
    required this.season,
    required this.played,
    required this.lines,
  });

  final LeagueCountry country;

  /// 1-based.
  final int division;
  final DivisionSeason season;

  /// Rounds played so far.
  final int played;
  final List<PlayerLine> lines;

  int get totalRounds => season.rounds.length;
  bool get isOver => played >= totalRounds;
  String get name => League.nameOf(country, division);

  /// The club's place, 1-based.
  int finishOf(Club club) =>
      season.table.indexWhere((r) => r.club.id == club.id) + 1;

  List<PlayerLine> _top(int Function(PlayerLine) by, {bool keepers = false}) {
    final pool = [
      for (final l in lines)
        if ((!keepers || l.role == SquadRole.gk) && by(l) > 0) l,
    ];
    return pool..sort((a, b) {
      final first = by(b).compareTo(by(a));
      if (first != 0) return first;
      // Fewer games for the same total ranks higher, then the better player.
      final apps = a.apps.compareTo(b.apps);
      return apps != 0 ? apps : b.rating.compareTo(a.rating);
    });
  }

  List<PlayerLine> get topScorers => _top((l) => l.goals);
  List<PlayerLine> get topAssists => _top((l) => l.assists);
  List<PlayerLine> get topCleanSheets =>
      _top((l) => l.cleanSheets, keepers: true);

  /// Best first by [PlayerLine.score]; [maxAge] for the young players' award.
  List<PlayerLine> bestPlayers({int? maxAge}) {
    final clubs = season.table.length;
    final pool = [
      for (final l in lines)
        if (l.apps > 0 && (maxAge == null || l.age <= maxAge)) l,
    ];
    return pool..sort(
      (a, b) => b
          .score(finishOf(b.club), clubs)
          .compareTo(a.score(finishOf(a.club), clubs)),
    );
  }

  /// The end-of-season awards (pick from here once [isOver]).
  SeasonAwards get awards => SeasonAwards._(this);
}

/// Who won what.
class SeasonAwards {
  SeasonAwards._(this.stats);

  final LeagueStats stats;

  LeagueRow get champions => stats.season.table.first;
  List<PlayerLine> get goldenBoot => stats.topScorers.take(3).toList();
  List<PlayerLine> get playmaker => stats.topAssists.take(3).toList();
  List<PlayerLine> get goldenGlove => stats.topCleanSheets.take(3).toList();
  List<PlayerLine> get playerOfTheSeason =>
      stats.bestPlayers().take(3).toList();
  List<PlayerLine> get youngPlayer =>
      stats.bestPlayers(maxAge: youngPlayerMaxAge).take(3).toList();

  /// The awards the career's own player won, by name.
  List<String> get wonByUser => [
    if (goldenBoot.firstOrNull?.isUser ?? false) 'Golden Boot',
    if (playmaker.firstOrNull?.isUser ?? false) 'Playmaker',
    if (playerOfTheSeason.firstOrNull?.isUser ?? false) 'Player of the Season',
    if (youngPlayer.firstOrNull?.isUser ?? false) 'Young Player of the Season',
  ];
}

/// Young Player of the Season is for players this age or younger.
const int youngPlayerMaxAge = 21;

/// The stats for one senior division in [player]'s current season, as far
/// as the player has got. Includes the player when it's their league.
LeagueStats leagueStats(
  Player player,
  World world,
  LeagueCountry country,
  int division,
) {
  final progress = player.season;
  final clubs = world.leagues
      .firstWhere((l) => l.country == country)
      .divisions[division - 1];
  final career = careerClubOf(player, world);
  final senior =
      career != null &&
      career.placement.signed &&
      !playsYouthFootball(player, career.placement);
  final userClub = senior && clubs.any((c) => c.id == career.club.id)
      ? career.club
      : null;
  final seed = divisionSeed(
    seasonSeed(player, progress.season),
    country,
    division,
    players: userClub != null,
  );
  final played = simulateDivision(
    clubs,
    seed,
    progress.round,
    club: userClub,
    results: progress.results,
  );

  final lines = <String, PlayerLine>{};
  PlayerLine lineOf(SquadPlayer p, Club club) => lines.putIfAbsent(
    p.id,
    () => PlayerLine(
      id: p.id,
      name: p.name,
      club: club,
      role: p.role,
      age: p.age,
      rating: p.rating,
    ),
  );

  final userPosition = userClub == null ? null : career!.decision.position;
  final user = userClub == null
      ? null
      : lines[MatchSim.userId] = PlayerLine(
          id: MatchSim.userId,
          name: player.identity.name,
          club: userClub,
          role:
              SquadRole.values
                  .where((r) => r.position == userPosition)
                  .firstOrNull ??
              SquadRole.st,
          age: player.attributes.age,
          rating: Position.ranked(player.attributes).first.$2,
          isUser: true,
        );

  final elevens = {
    for (final c in clubs)
      c.id: pickLineup(
        c.squad,
        c.manager.formation,
        userPosition: c.id == userClub?.id ? userPosition : null,
        userId: c.id == userClub?.id ? MatchSim.userId : null,
      ).players,
  };

  final rounds = min(progress.round, played.rounds.length);
  for (var r = 0; r < rounds; r++) {
    for (final (i, f) in played.rounds[r].indexed) {
      final (h, a) = played.scores[r][i]!;
      for (final (club, conceded) in [(f.home, a), (f.away, h)]) {
        for (final p in elevens[club.id]!) {
          final line = lineOf(p, club);
          line.apps++;
          // Defenders' clean sheets count towards Player of the Season;
          // only keepers' count for the Golden Glove.
          if (conceded == 0 && PlayerLine._defensive.contains(p.role)) {
            line.cleanSheets++;
          }
        }
      }

      if (userClub != null && f.involves(userClub)) {
        user!.apps++;
        final other = f.home.id == userClub.id ? f.away : f.home;
        if (progress.results[r].$2 == 0 &&
            PlayerLine._defensive.contains(user.role)) {
          user.cleanSheets++;
        }
        for (final g in progress.goalsIn(r)) {
          final club = g.mine ? userClub : other;
          void credit(String id, void Function(PlayerLine) add) {
            final line =
                lines[id] ??
                switch (club.squad.where((p) => p.id == id).firstOrNull) {
                  final p? => lineOf(p, club),
                  null => null,
                };
            if (line != null) add(line);
          }

          credit(g.scorerId, (l) => l.goals++);
          if (g.assistId case final id?) credit(id, (l) => l.assists++);
        }
        continue;
      }

      final rng = Random(fixtureSeed(seed, r, i) ^ 0x2545F491);
      for (final (club, goals) in [(f.home, h), (f.away, a)]) {
        final eleven = elevens[club.id]!;
        for (var n = 0; n < goals; n++) {
          final scorer = weightedPick(eleven, scorerWeight, rng);
          if (scorer == null) continue;
          lineOf(scorer, club).goals++;
          if (rng.nextDouble() < assistRate) {
            final assist = weightedPick(
              [
                for (final p in eleven)
                  if (p != scorer) p,
              ],
              assistWeight,
              rng,
            );
            if (assist != null) lineOf(assist, club).assists++;
          }
        }
      }
    }
  }

  return LeagueStats._(
    country: country,
    division: division,
    season: played,
    played: rounds,
    lines: lines.values.toList(),
  );
}

/// The player's own numbers this season, in any league (youth included).
({int apps, int goals, int assists}) yourSeason(SeasonProgress progress) {
  var goals = 0;
  var assists = 0;
  for (var r = 0; r < progress.round; r++) {
    for (final g in progress.goalsIn(r)) {
      if (!g.mine) continue;
      if (g.scorerId == MatchSim.userId) goals++;
      if (g.assistId == MatchSim.userId) assists++;
    }
  }
  return (apps: progress.round, goals: goals, assists: assists);
}
