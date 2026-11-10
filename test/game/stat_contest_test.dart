import 'dart:math';

import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/resolution/contest_outcome.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/match/resolution/stat_contest.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  final rng = Random(42);

  group('StatContestResolver.rollContest', () {
    test('significant stat superiority wins majority of rolls', () {
      var wins = 0;
      const rolls = 200;
      for (var i = 0; i < rolls; i++) {
        if (StatContestResolver.rollContest(
          attackStat: 88,
          defendStat: 50,
          rng: rng,
        )) {
          wins++;
        }
      }
      expect(wins / rolls, greaterThan(0.65));
    });

    test('stat inferiority loses majority of rolls', () {
      var wins = 0;
      const rolls = 200;
      for (var i = 0; i < rolls; i++) {
        if (StatContestResolver.rollContest(
          attackStat: 45,
          defendStat: 85,
          rng: rng,
        )) {
          wins++;
        }
      }
      expect(wins / rolls, lessThan(0.35));
    });

    test('fatigue reduces win rate', () {
      var freshWins = 0;
      var exhaustedWins = 0;
      const rolls = 250;

      for (var i = 0; i < rolls; i++) {
        if (StatContestResolver.rollContest(
          attackStat: 75,
          defendStat: 75,
          attackFatigue: 0.0,
          rng: Random(i),
        )) {
          freshWins++;
        }
        if (StatContestResolver.rollContest(
          attackStat: 75,
          defendStat: 75,
          attackFatigue: 0.9,
          rng: Random(i),
        )) {
          exhaustedWins++;
        }
      }
      expect(freshWins, greaterThan(exhaustedWins));
    });

    test('momentum provides a tangible multiplier', () {
      final highMomentum = MatchMomentum(home: 0.85);
      final lowMomentum = MatchMomentum(home: 0.15);

      expect(highMomentum.multiplierFor(Side.home), greaterThan(1.05));
      expect(lowMomentum.multiplierFor(Side.home), lessThan(0.95));
    });
  });

  group('StatContestResolver.resolveShot', () {
    const eliteShooter = SquadPlayer(
      id: 'elite-st',
      name: 'Rin Itoshi',
      age: 18,
      nationality: Nationality.japanese,
      role: SquadRole.st,
      rating: 88,
      value: 30000000,
      attributes: PlayerAttributes(
        age: 18,
        pace: 85,
        shot: 92,
        pass: 84,
        dribble: 88,
        defence: 40,
        physical: 76,
        ego: 90,
        composure: 88,
      ),
    );

    const averageGk = SquadPlayer(
      id: 'gk',
      name: 'Keeper',
      age: 26,
      nationality: Nationality.english,
      role: SquadRole.gk,
      rating: 65,
      value: 1000000,
      attributes: PlayerAttributes(
        age: 26,
        pace: 45,
        shot: 20,
        pass: 50,
        dribble: 30,
        defence: 65,
        physical: 72,
      ),
    );

    test(
      'elite shooter in opponent box produces goals and saves, not wide misses',
      () {
        var goals = 0;
        var saves = 0;
        var misses = 0;
        const trials = 100;

        for (var i = 0; i < trials; i++) {
          final outcome = StatContestResolver.resolveShot(
            shooter: eliteShooter,
            goalkeeper: averageGk,
            zone: PitchZone.opponentBox,
            attackingSide: Side.home,
            momentum: MatchMomentum(),
            rng: Random(i),
          );
          if (outcome.isGoal) goals++;
          if (outcome.result == ContestResult.saved) saves++;
          if (outcome.result == ContestResult.miss) misses++;
        }

        expect(goals, greaterThan(25));
        expect(goals + saves, greaterThan(misses));
      },
    );
  });

  group('MatchSim with real User Player and Club integration', () {
    test('instantiating MatchSim with user Player uses user attributes', () {
      final user = testPlayer(7);
      final sim = MatchSim(
        shirtName: user.identity.shirtName,
        user: user,
        random: Random(99),
      );

      expect(sim.homeSquad, isNotEmpty);
      expect(sim.awaySquad, isNotEmpty);
      expect(sim.homeCoach, isNotNull);
      expect(sim.awayCoach, isNotNull);

      // Play a full game
      while (!sim.isOver) {
        if (sim.isHalfTime) {
          sim.startSecondHalf();
          continue;
        }
        final action = sim.pad.values.first;
        sim.play(action);
      }

      expect(sim.isOver, isTrue);
      expect(sim.minute, MatchSim.fullTime);
      expect(sim.feed.last.text, 'Full time.');
    });
  });
}
