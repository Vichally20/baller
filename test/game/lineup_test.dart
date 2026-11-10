import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/match/lineup.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  final club = WorldRepository.forSeed(2026).clubs.first;

  group('line-ups', () {
    for (final formation in formations.keys) {
      test('$formation: 11 players, 1 keeper, the right shape', () {
        final lineup = pickLineup(club.squad, formation);
        expect(lineup.formation, formation);
        expect(lineup.spots, hasLength(11));
        expect(
          lineup.spots.where((s) => s.slot.role == SquadRole.gk),
          hasLength(1),
        );
        expect(lineup.players.toSet(), hasLength(11)); // nobody twice
        // A full 22-man squad covers every role exactly.
        for (final spot in lineup.spots) {
          expect(spot.player!.role, spot.slot.role);
        }
      });
    }

    test('the best-rated player in each role starts', () {
      final lineup = pickLineup(club.squad, '4-4-2');
      final keeper = lineup.spots.firstWhere(
        (s) => s.slot.role == SquadRole.gk,
      );
      final bestKeeper = club.squad
          .where((p) => p.role == SquadRole.gk)
          .reduce((a, b) => a.rating >= b.rating ? a : b);
      expect(keeper.player, same(bestKeeper));
    });

    test('the user takes the slot for their position', () {
      final lineup = pickLineup(club.squad, '4-3-3', userPosition: Position.w);
      expect(lineup.spots, hasLength(11));
      expect(lineup.userSpot!.slot.role, SquadRole.w);
      expect(lineup.players, hasLength(10));
    });

    test('no slot for the position: the closest one', () {
      // 4-4-2 has no attacking midfielder; a CM slot covers it.
      final lineup = pickLineup(club.squad, '4-4-2', userPosition: Position.am);
      expect(lineup.userSpot!.slot.role, SquadRole.cm);
    });

    test('a small squad still fields eleven, with cover', () {
      final small = [
        for (final p in club.squad)
          if (p.role != SquadRole.dm) p,
      ];
      final lineup = pickLineup(small, '4-2-3-1');
      expect(lineup.spots, hasLength(11));
      final dmSlots = lineup.spots.where((s) => s.slot.role == SquadRole.dm);
      expect(dmSlots.every((s) => s.player!.role == SquadRole.cm), isTrue);
    });
  });

  group('the engine plays the line-ups', () {
    test('your side uses your manager\'s formation and your position', () {
      final away = WorldRepository.forSeed(2026).clubs.elementAt(1);
      final sim = MatchSim(
        shirtName: 'ME',
        user: testPlayer(3),
        homeClub: club,
        awayClub: away,
        userPosition: Position.st,
        random: Random(1),
      );
      expect(sim.homeEleven.formation, club.manager.formation);
      expect(sim.awayEleven.formation, away.manager.formation);
      expect(sim.homeEleven.userSpot!.slot.role, SquadRole.st);
      expect(sim.homeLineup, hasLength(10));
      expect(sim.awayLineup, hasLength(11));
    });
  });

  group('half-time', () {
    test('play stops at 45\', then the second half runs to 90\'', () {
      final sim = MatchSim(
        shirtName: 'ME',
        user: testPlayer(3),
        random: Random(4),
      );
      while (!sim.isHalfTime) {
        expect(sim.isOver, isFalse);
        sim.play(sim.pad.values.first);
      }
      expect(sim.minute, MatchSim.halfTime);
      expect(sim.feed.last.text, 'Half-time.');
      expect(() => sim.play(sim.pad.values.first), throwsStateError);

      sim.startSecondHalf();
      expect(sim.isHalfTime, isFalse);
      expect(sim.minute, greaterThan(MatchSim.halfTime));
      expect(sim.state, PlayState.defend); // they kick off
      expect(sim.notice, startsWith('Second half'));

      while (!sim.isOver) {
        expect(sim.isHalfTime, isFalse); // only one break
        sim.play(sim.pad.values.first);
      }
      expect(sim.minute, MatchSim.fullTime);
    });

    test('startSecondHalf only works at half-time', () {
      final sim = MatchSim(shirtName: 'ME', random: Random(1));
      expect(sim.startSecondHalf, throwsStateError);
    });
  });
}
