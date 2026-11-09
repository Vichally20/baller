import 'package:baller/game/match/ai/behavior_tree/coach_brain.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_factory.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_snapshot.dart';
import 'package:baller/game/match/ai/behavior_tree/composite.dart';
import 'package:baller/game/match/ai/behavior_tree/leaf.dart';
import 'package:baller/game/match/ai/behavior_tree/node.dart';
import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Behavior Tree Core Nodes', () {
    test('Sequence succeeds only when all children succeed', () {
      var callCount = 0;
      final seq = Sequence<int>([
        Condition<int>((x) {
          callCount++;
          return x > 0;
        }),
        Condition<int>((x) {
          callCount++;
          return x > 10;
        }),
      ]);

      expect(seq.tick(15), NodeStatus.success);
      expect(callCount, 2);

      callCount = 0;
      expect(seq.tick(-5), NodeStatus.failure);
      // Short-circuit: second child should not be evaluated
      expect(callCount, 1);
    });

    test('Selector succeeds on first child success', () {
      var callCount = 0;
      final sel = Selector<int>([
        Condition<int>((x) {
          callCount++;
          return x == 100;
        }),
        Condition<int>((x) {
          callCount++;
          return x > 0;
        }),
        Condition<int>((x) {
          callCount++;
          return true;
        }),
      ]);

      expect(sel.tick(5), NodeStatus.success);
      // First child fails, second child succeeds, third is skipped
      expect(callCount, 2);
    });
  });

  group('CoachBrain decisions', () {
    late TacticalState tactics;
    late CoachBrain coach;

    setUp(() {
      tactics = TacticalState.fromStyle(ClubStyle.possession);
      coach = CoachBrain(
        coachName: 'Test Coach',
        desperationMinute: 78,
        protectLeadMinute: 75,
        possessionThreshold: 35.0,
      );
    });

    test('triggers Desperation Mode when losing after 78th minute', () {
      final snap = CoachSnapshot(
        minute: 82,
        goalDifference: -1,
        possessionPercentage: 45.0,
        tactics: tactics,
      );

      final status = coach.evaluate(snap);
      expect(status, NodeStatus.success);
      expect(tactics.tacticName, 'All-Out Chaos');
      expect(tactics.tempo, 'Fast');
      expect(tactics.shootMultiplier, 2.0);
    });

    test('does NOT trigger Desperation Mode if early in the match', () {
      final snap = CoachSnapshot(
        minute: 35,
        goalDifference: -1,
        possessionPercentage: 50.0,
        tactics: tactics,
      );

      coach.evaluate(snap);
      expect(tactics.tacticName, 'Control & Possession');
    });

    test('triggers Protect Lead when winning narrowly after 75th minute', () {
      final snap = CoachSnapshot(
        minute: 80,
        goalDifference: 1,
        possessionPercentage: 55.0,
        tactics: tactics,
      );

      coach.evaluate(snap);
      expect(tactics.tacticName, 'Defensive Shell');
      expect(tactics.tempo, 'Slow');
      expect(tactics.attackIntensity, 0.25);
    });

    test('triggers Control mode when possession drops below threshold', () {
      final snap = CoachSnapshot(
        minute: 40,
        goalDifference: 0,
        possessionPercentage: 30.0,
        tactics: tactics,
      );

      coach.evaluate(snap);
      expect(tactics.tacticName, 'Control');
      expect(tactics.passMultiplier, 1.6);
    });
  });

  group('CoachFactory', () {
    test('volatile modern progressive manager panics earlier than calm traditional manager', () {
      const volatileModern = Manager(
        name: 'Volatile Modern',
        age: 40,
        nationality: Nationality.spanish,
        philosophy: Philosophy.modernProgressive,
        formation: '4-3-3',
        youthTrust: 5,
        temperament: Temperament.volatile,
      );

      const calmTraditional = Manager(
        name: 'Calm Old School',
        age: 62,
        nationality: Nationality.english,
        philosophy: Philosophy.traditional,
        formation: '4-4-2',
        youthTrust: 1,
        temperament: Temperament.calm,
      );

      final coachModern = CoachFactory.createForManager(volatileModern);
      final coachTrad = CoachFactory.createForManager(calmTraditional);

      expect(coachModern.desperationMinute, lessThan(coachTrad.desperationMinute));
      expect(coachModern.desperationMinute, 70);
      expect(coachTrad.desperationMinute, 85);
    });
  });
}

