import 'dart:math';

import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/world_generator.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('Position-Aware Prompts & Defense', () {
    test('Striker receives high-press prompts in defense, never defender prompts', () {
      final world = generateWorld(1);
      final homeClub = world.clubs.first;
      final awayClub = world.clubs.elementAt(1);

      final striker = testPlayer(10).copyWith(preferredPosition: Position.st);

      final sim = MatchSim(
        shirtName: striker.identity.shirtName,
        user: striker,
        homeClub: homeClub,
        awayClub: awayClub,
        random: Random(42),
      );

      expect(positionGroupOf(SquadRole.st), PositionGroup.forward);

      // Force state to defend
      sim.forceStateForTest(PlayState.defend);

      final prompt = sim.prompt;
      expect(
        prompt,
        anyOf([
          contains('centre-back hesitates'),
          contains('play out from the back'),
          contains('bouncing backpass'),
          contains('block the line of the pass'),
        ]),
      );

      // Must NEVER show defender-specific prompts
      expect(
        prompt.contains(
          'Their winger collects on the halfway line and runs straight at you',
        ),
        isFalse,
      );
      expect(prompt.contains('Their striker is on your shoulder'), isFalse);
    });

    test('Defender receives last-line defending prompts in defense', () {
      final world = generateWorld(2);
      final homeClub = world.clubs.first;
      final awayClub = world.clubs.elementAt(1);

      final defender = testPlayer(20).copyWith(preferredPosition: Position.cb);

      final sim = MatchSim(
        shirtName: defender.identity.shirtName,
        user: defender,
        homeClub: homeClub,
        awayClub: awayClub,
        random: Random(99),
      );

      expect(positionGroupOf(SquadRole.cb), PositionGroup.defence);

      sim.forceStateForTest(PlayState.defend);

      final prompt = sim.prompt;
      expect(
        prompt,
        anyOf([
          contains('runs straight at you'),
          contains('striker is on your shoulder'),
          contains('forward sprint in a pure footrace'),
          contains('block the shot'),
        ]),
      );
    });

    test('Midfielder receives midfield duel and pocket prompts in defense', () {
      final world = generateWorld(3);
      final homeClub = world.clubs.first;
      final awayClub = world.clubs.elementAt(1);

      final midfielder = testPlayer(30)
          .copyWith(preferredPosition: Position.cm);

      final sim = MatchSim(
        shirtName: midfielder.identity.shirtName,
        user: midfielder,
        homeClub: homeClub,
        awayClub: awayClub,
        random: Random(77),
      );

      expect(positionGroupOf(SquadRole.cm), PositionGroup.midfield);

      sim.forceStateForTest(PlayState.defend);

      final prompt = sim.prompt;
      expect(
        prompt,
        anyOf([
          contains('midfielder receives on the turn'),
          contains('midfield pocket'),
          contains('centre circle'),
        ]),
      );
    });

    test('Striker pressing in defense does not concede instant goals on failed press', () {
      final world = generateWorld(4);
      final homeClub = world.clubs.first;
      final awayClub = world.clubs.elementAt(1);

      final striker = testPlayer(40).copyWith(preferredPosition: Position.st);

      // Run multiple failed tackles in defense to ensure no instant goals conceded
      for (var seed = 0; seed < 30; seed++) {
        final sim = MatchSim(
          shirtName: striker.identity.shirtName,
          user: striker,
          homeClub: homeClub,
          awayClub: awayClub,
          random: Random(seed * 11 + 3),
        );

        sim.forceStateForTest(PlayState.defend);

        final initialAwayGoals = sim.awayGoals;
        final outcome = sim.play(MatchAction.tackle);

        // A high press tackle by a striker either wins the ball (30 yards out) or is bypassed,
        // but does NOT instantly concede a goal.
        if (outcome.next == PlayState.defend) {
          expect(sim.awayGoals, equals(initialAwayGoals));
        }
      }
    });
  });
}
