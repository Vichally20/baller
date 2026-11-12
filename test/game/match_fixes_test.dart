import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/matchup.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/position.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Plays [matches] matches with a seeded random choice of moves, calling
/// [onMove] with the state before each move and the sim after it.
void _playMany(
  int matches,
  void Function(
    PlayState before,
    MatchAction action,
    MatchSim sim,
    int awayBefore,
  )
  onMove, {
  MatchSim Function(int seed)? build,
}) {
  final user = testPlayer(
    7,
  ).copyWith(innateTalent: allTalents.firstWhere((t) => t.id == 'apex_bully'));
  for (var m = 0; m < matches; m++) {
    final sim =
        build?.call(m) ??
        MatchSim(shirtName: 'ME', user: user, random: Random(m));
    final pick = Random(m + 5000);
    while (!sim.isOver) {
      if (sim.isHalfTime) {
        sim.startSecondHalf();
        continue;
      }
      final before = sim.state;
      final options = sim.pad.values.toList();
      final action = options[pick.nextInt(options.length)];
      final away = sim.awayGoals;
      sim.play(action);
      onMove(before, action, sim, away);
    }
  }
}

void main() {
  test('clearing their corner is a clearance, never a shot at their goal', () {
    var clearances = 0;
    _playMany(600, (before, action, sim, _) {
      if (before != PlayState.cornerAgainst || action != MatchAction.shoot) {
        return;
      }
      clearances++;
      final line = sim.feed.lastWhere((l) => l.yourMove).text;
      expect(line, isNot(contains('GOAL!')));
      expect(line, isNot(contains('Goal kick')));
      expect(
        line.contains('smashes it clear') ||
            line.contains('clearance skews off'),
        isTrue,
        reason: line,
      );
    });
    expect(clearances, greaterThan(20));
  });

  test('every written outcome can happen, picked by weight', () {
    final seen = <String>{};
    _playMany(300, (before, action, sim, _) {
      if (action == MatchAction.shadow ||
          (before == PlayState.cornerAgainst && action == MatchAction.mark)) {
        seen.add(sim.feed.lastWhere((l) => l.yourMove).text);
      }
    });
    // Shadow's corner-to-them outcome used to be unreachable, and so was
    // a second bad outcome when marking at their corner.
    expect(seen.any((t) => t.contains('Corner to them')), isTrue);
    expect(seen.any((t) => t.contains('Another corner')), isTrue);
    expect(seen.any((t) => t.contains('goal for them')), isTrue);
  });

  test('different teammates and opponents get involved', () {
    final world = WorldRepository.forSeed(2026);
    final user = testPlayer(3);
    final receivers = <String>{};
    _playMany(
      20,
      (before, action, sim, _) {
        final line = sim.feed.lastWhere((l) => l.yourMove).text;
        final match = RegExp(r'finds (.+) cleanly').firstMatch(line);
        if (match != null) receivers.add(match[1]!);
      },
      build: (seed) => MatchSim(
        shirtName: 'ME',
        user: user,
        homeClub: world.clubs.first,
        awayClub: world.clubs.elementAt(1),
        random: Random(seed),
      ),
    );
    expect(receivers.length, greaterThan(3));
  });

  test('goals: about 2.5 a match with sensible play, from both sides', () {
    final trialist = youthTrialist();
    final player = trialist.withPlacement(trialist.placement!.sign());
    final world = WorldRepository.forSeed(player.worldSeed);
    var goals = 0;
    var theirs = 0;
    var betweenMoves = 0;
    const matches = 150;
    for (var m = 0; m < matches; m++) {
      final sides = matchupFor(
        player,
        world,
        opponentName: 'Them',
        eventIndex: m,
      )!;
      final sim = MatchSim(
        shirtName: 'ME',
        user: player,
        homeClub: sides.home,
        awayClub: sides.away,
        userPosition: sides.userPosition,
        random: Random(m),
      );
      final pick = Random(m + 99);
      while (!sim.isOver) {
        if (sim.isHalfTime) {
          sim.startSecondHalf();
          continue;
        }
        final pad = sim.pad.values.toList();
        // Build up first, then shoot: what a sensible player does.
        final action = sim.move == 1 && pad.contains(MatchAction.shoot)
            ? MatchAction.shoot
            : pad[pick.nextInt(pad.length)];
        final before = sim.homeGoals + sim.awayGoals;
        final outcome = sim.play(action);
        if (outcome.goal == null) {
          betweenMoves += sim.homeGoals + sim.awayGoals - before;
        }
      }
      goals += sim.homeGoals + sim.awayGoals;
      theirs += sim.awayGoals;
    }
    expect(goals / matches, inInclusiveRange(2.0, 3.5));
    expect(theirs, greaterThan(0));
    // The rest of the team scores between your chances too.
    expect(betweenMoves / matches, greaterThan(0.25));
  });

  group('matchups', () {
    test('trialists play trial football around their own level', () {
      final player = youthTrialist();
      final world = WorldRepository.forSeed(player.worldSeed);
      final matchup = matchupFor(
        player,
        world,
        opponentName: 'The other trialists',
        eventIndex: 2,
      )!;
      final level = Position.ranked(player.attributes).first.$2;
      expect(matchup.away.name, 'The other trialists');
      expect(matchup.home.name, careerClubOf(player, world)!.name);
      for (final p in [...matchup.home.squad, ...matchup.away.squad]) {
        expect(p.rating, inInclusiveRange(level - 3, level + 3));
      }
      // The same every time.
      final again = matchupFor(
        player,
        world,
        opponentName: 'The other trialists',
        eventIndex: 2,
      )!;
      expect(
        [for (final p in again.away.squad) p.name],
        [for (final p in matchup.away.squad) p.name],
      );
    });

    test('signed senior players play with the real squad', () {
      final base = pathwayPlayer(offers: true);
      final world = WorldRepository.forSeed(base.worldSeed);
      final club = world.clubs.firstWhere((c) => c.division == 1);
      final player = base.withPlacement(
        Placement(kind: PathwayKind.seniorHome, clubId: club.id, signed: true),
      );
      final matchup = matchupFor(
        player,
        world,
        opponentName: 'A friendly XI',
        eventIndex: 2,
      )!;
      expect(matchup.home, same(club));
      expect(matchup.away.country, club.country);
      expect(matchup.away.division, club.division);
      expect(matchup.away.id, isNot(club.id));
    });

    test('no pathway yet: no matchup (the engine uses stand-in sides)', () {
      final player = testPlayer(1);
      expect(
        matchupFor(
          player,
          WorldRepository.forSeed(player.worldSeed),
          opponentName: 'x',
          eventIndex: 0,
        ),
        isNull,
      );
    });
  });
}
