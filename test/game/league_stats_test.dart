import 'dart:convert';
import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/growth.dart';
import 'package:baller/game/career/league_stats.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/match/autopilot.dart';
import 'package:baller/game/match/goal_credit.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// A senior player signed to a Division 2 club, [rounds] into a season
/// in which they score once and set one up every game.
Player _senior({int rounds = 0}) {
  final player = placedPlayer(offers: false);
  final world = WorldRepository.forSeed(player.worldSeed);
  final club = world.clubs.firstWhere((c) => c.division == 2);
  final mate = club.squad.firstWhere((p) => p.role == SquadRole.st);
  var progress = SeasonProgress.first;
  for (var r = 0; r < rounds; r++) {
    progress = progress.record(
      2,
      0,
      scorers: [
        const RoundGoal(mine: true, scorerId: MatchSim.userId),
        RoundGoal(mine: true, scorerId: mate.id, assistId: MatchSim.userId),
      ],
    );
  }
  return player
      .withPlacement(
        Placement(kind: PathwayKind.seniorHome, clubId: club.id, signed: true),
      )
      .withSeason(progress);
}

void main() {
  group('a whole simulated season', () {
    final player = _senior(rounds: 38);
    final world = WorldRepository.forSeed(player.worldSeed);
    final other = world.leagues.first;
    final stats = leagueStats(player, world, other.country, 1);

    test('every goal is credited to someone', () {
      final scored = stats.season.table.fold(0, (s, r) => s + r.goalsFor);
      final credited = stats.lines.fold(0, (s, l) => s + l.goals);
      expect(credited, scored);
      final assists = stats.lines.fold(0, (s, l) => s + l.assists);
      expect(assists / scored, closeTo(assistRate, 0.08));
    });

    test('the leaders look like a real league', () {
      expect(stats.isOver, isTrue);
      final boot = stats.topScorers.first;
      expect(boot.goals, inInclusiveRange(12, 45));
      expect(
        stats.topScorers.take(5).every((l) => l.role != SquadRole.gk),
        isTrue,
      );
      expect(stats.topCleanSheets.every((l) => l.role == SquadRole.gk), isTrue);
      expect(stats.topCleanSheets.first.cleanSheets, inInclusiveRange(5, 25));
      for (final l in stats.lines) {
        expect(l.apps, lessThanOrEqualTo(38));
      }
    });

    test('the same save gives the same numbers', () {
      final again = leagueStats(player, world, other.country, 1);
      expect(
        [for (final l in again.topScorers.take(5)) (l.id, l.goals)],
        [for (final l in stats.topScorers.take(5)) (l.id, l.goals)],
      );
    });

    test('awards name a champion and young players are young', () {
      final awards = stats.awards;
      expect(awards.champions, same(stats.season.table.first));
      expect(awards.goldenBoot.first, same(stats.topScorers.first));
      expect(
        awards.youngPlayer.every((l) => l.age <= youngPlayerMaxAge),
        isTrue,
      );
    });
  });

  test("the player's own goals count in their league", () {
    final player = _senior(rounds: 10);
    final world = WorldRepository.forSeed(player.worldSeed);
    final club = world.clubById(player.placement!.clubId)!;
    final stats = leagueStats(player, world, club.country, club.division);
    final me = stats.lines.singleWhere((l) => l.isUser);
    expect((me.apps, me.goals, me.assists), (10, 10, 10));
    // The player's table is the one the season screen shows.
    final season = seasonFor(player, world, player.season)!;
    expect(
      [for (final r in stats.season.table) r.club.id],
      [for (final r in season.table) r.club.id],
    );
    expect(yourSeason(player.season), (apps: 10, goals: 10, assists: 10));
  });

  test('scorers survive saving; older saves load without them', () {
    final progress = _senior(rounds: 2).season;
    final back = SeasonProgress.fromJson(
      jsonDecode(jsonEncode(progress.toJson())),
    )!;
    expect(back.goalsIn(1).map((g) => (g.mine, g.scorerId, g.assistId)), [
      for (final g in progress.goalsIn(1)) (g.mine, g.scorerId, g.assistId),
    ]);
    final old = SeasonProgress.fromJson({
      'season': 1,
      'results': [
        [1, 0],
      ],
      'scenes': 0,
    })!;
    expect(old.goalsIn(0), isEmpty);
  });

  test('a simulated match runs to full time and names every scorer', () {
    final player = placedPlayer(offers: false);
    for (var seed = 0; seed < 20; seed++) {
      final sim = MatchSim(
        shirtName: 'TEST',
        user: player,
        random: Random(seed),
        creditSeed: seed,
      );
      final rng = Random(seed);
      final training = MatchTraining();
      while (!sim.isOver) {
        if (sim.isHalfTime) sim.startSecondHalf();
        final action = autoMove(sim, player.attributes, rng);
        final before = sim.state;
        training.record(action, before, sim.play(action));
      }
      expect(
        sim.goals.where((g) => g.side == Side.home),
        hasLength(sim.homeGoals),
      );
      expect(
        sim.goals.where((g) => g.side == Side.away),
        hasLength(sim.awayGoals),
      );
      for (final g in sim.goals) {
        expect(g.assist, isNot(same(g.scorer)));
      }

      final growth = trainFromMatch(
        player,
        training.successes,
        attempts: training.attempts,
      );
      for (final t in growth.breakdown) {
        expect(t.successes, lessThanOrEqualTo(t.attempts));
        expect(
          t.after,
          player.attributes[t.stat] + (growth.changes[t.stat] ?? 0),
        );
      }
      expect(
        growth.totalXp,
        growth.breakdown.fold(0, (s, t) => s + t.xpGained),
      );
    }
  });

  test('the breakdown shows XP, multiplier and levels', () {
    final player = placedPlayer(offers: false);
    final shot = player.attributes[Attribute.shot];
    final growth = trainFromMatch(
      player,
      {Attribute.shot: 50},
      attempts: {Attribute.shot: 60, Attribute.pace: 3},
    );
    final row = growth.breakdown.first;
    expect(row.stat, Attribute.shot);
    expect((row.attempts, row.successes), (60, 50));
    expect(row.multiplier, learningRate(player.attributes.age));
    expect(row.xpGained, (50 * xpPerSuccess * row.multiplier).round());
    expect(row.levelsGained, greaterThan(0));
    expect(row.after, shot + row.levelsGained);
    expect(row.xpAfter, lessThan(row.xpNeeded));
    // Moves that never came off still appear, with no XP.
    final pace = growth.breakdown.firstWhere((t) => t.stat == Attribute.pace);
    expect((pace.successes, pace.xpGained, pace.levelsGained), (0, 0, 0));
  });
}
