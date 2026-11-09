import 'dart:math';

import 'package:baller/game/match/match_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every state has outcomes for every move on its pad', () {
    for (final state in PlayState.values) {
      final table = moveOutcomes[state]!;
      for (final action in matchPads[state.phase]!.values) {
        expect(table[action], isNotEmpty, reason: '$state $action');
      }
      expect(matchPrompts[state], isNotEmpty);
    }
  });

  test('the phase follows the play', () {
    expect(PlayState.attack.phase, MatchPhase.attack);
    expect(PlayState.defend.phase, MatchPhase.defend);
    expect(PlayState.cornerFor.phase, MatchPhase.box);
    expect(PlayState.cornerAgainst.phase, MatchPhase.box);
  });

  test('starts in attack, move 1, nil-nil', () {
    final sim = MatchSim(shirtName: 'BAKARE', random: Random(1));
    expect(sim.state, PlayState.attack);
    expect(sim.move, 0);
    expect(sim.homeGoals + sim.awayGoals, 0);
    expect(sim.minute, inInclusiveRange(6, 13));
  });

  test('a move off the current pad is refused', () {
    final sim = MatchSim(shirtName: 'BAKARE', random: Random(1));
    expect(() => sim.play(MatchAction.tackle), throwsArgumentError);
  });

  test('two moves per chance, then the clock moves on', () {
    for (var seed = 0; seed < 50; seed++) {
      final sim = MatchSim(shirtName: 'BAKARE', random: Random(seed));
      final start = sim.minute;
      final first = sim.play(sim.pad.values.first);
      if (first.goal != null) continue; // a goal ends the chance early
      expect(sim.move, 1);
      expect(sim.minute, start);
      expect(sim.state, first.next);
      sim.play(sim.pad.values.first);
      expect(sim.move, 0);
      expect(sim.minute, greaterThan(start));
    }
  });

  test('plays to full time with commentary naming the player', () {
    final rng = Random(3);
    final sim = MatchSim(shirtName: 'BAKARE', random: rng);
    var moves = 0;
    while (!sim.isOver) {
      final options = sim.pad.values.toList();
      sim.play(options[rng.nextInt(options.length)]);
      moves++;
      expect(moves, lessThan(100));
    }
    expect(sim.minute, MatchSim.fullTime);
    expect(sim.feed.last.text, 'Full time.');
    expect(sim.feed.where((l) => l.yourMove).length, moves);
    expect(sim.feed.any((l) => l.text.contains('{shirt}')), isFalse);
    expect(() => sim.play(sim.pad.values.first), throwsStateError);
  });

  test('scoring hands the ball to the side that conceded', () {
    for (final entry in moveOutcomes.entries) {
      for (final options in entry.value.values) {
        for (final o in options) {
          if (o.goal == Side.home) expect(o.next, PlayState.defend);
          if (o.goal == Side.away) expect(o.next, PlayState.attack);
        }
      }
    }
  });
}
