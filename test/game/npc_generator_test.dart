import 'dart:math';

import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/npc_generator.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rng = Random(42);

  group('NpcGenerator attributes', () {
    test('striker attributes prioritize shot over defence', () {
      for (var i = 0; i < 20; i++) {
        final stats = NpcGenerator.generateAttributes(
          role: SquadRole.st,
          rating: 75,
          age: 22,
          rng: rng,
        );
        expect(stats.shot, greaterThan(stats.defence));
        expect(stats.shot, inInclusiveRange(65, 95));
        expect(stats.defence, inInclusiveRange(20, 65));
        expect(stats.ego, inInclusiveRange(30, 99));
        expect(stats.tacticalDiscipline, inInclusiveRange(15, 95));
        expect(stats.teamwork, inInclusiveRange(15, 95));
        expect(stats.composure, inInclusiveRange(25, 99));
        expect(stats.stamina, inInclusiveRange(35, 99));
      }
    });

    test('centre-back attributes prioritize defence over shot', () {
      for (var i = 0; i < 20; i++) {
        final stats = NpcGenerator.generateAttributes(
          role: SquadRole.cb,
          rating: 75,
          age: 26,
          rng: rng,
        );
        expect(stats.defence, greaterThan(stats.shot));
        expect(stats.defence, inInclusiveRange(65, 95));
        expect(stats.physical, inInclusiveRange(60, 95));
        expect(stats.shot, inInclusiveRange(20, 60));
        // CBs lean higher in discipline and lower in ego
        expect(stats.tacticalDiscipline, inInclusiveRange(40, 95));
      }
    });

    test('goalkeepers have low outfield skills but decent physical/defence', () {
      final stats = NpcGenerator.generateAttributes(
        role: SquadRole.gk,
        rating: 70,
        age: 28,
        rng: rng,
      );
      expect(stats.shot, lessThan(stats.physical));
      expect(stats.dribble, lessThan(stats.physical));
      expect(stats.physical, inInclusiveRange(55, 85));
    });

    test('mental stats scale with age and rating', () {
      final youngRaw = NpcGenerator.generateAttributes(
        role: SquadRole.w,
        rating: 50,
        age: 17,
        rng: Random(1),
      );
      final veteranElite = NpcGenerator.generateAttributes(
        role: SquadRole.w,
        rating: 88,
        age: 32,
        rng: Random(1),
      );

      expect(veteranElite.composure, greaterThan(youngRaw.composure));
      expect(veteranElite.ego, greaterThanOrEqualTo(youngRaw.ego));
    });
  });

  group('NpcGenerator talents', () {
    test('genius tier players (80+) have higher talent probability', () {
      var innateCount = 0;
      var logicCount = 0;
      const samples = 100;
      for (var i = 0; i < samples; i++) {
        final (innate, logic) = NpcGenerator.generateTalents(85, rng);
        if (innate != null) innateCount++;
        logicCount += logic.length;
      }
      expect(innateCount, greaterThan(25));
      expect(logicCount, greaterThan(80));
    });

    test('low tier players (<58) rarely have talents', () {
      var innateCount = 0;
      for (var i = 0; i < 50; i++) {
        final (innate, _) = NpcGenerator.generateTalents(48, rng);
        if (innate != null) innateCount++;
      }
      expect(innateCount, 0);
    });
  });

  group('NpcGenerator wage and foot', () {
    test('wage increases with market value', () {
      final cheapWage = NpcGenerator.generateWage(100000, 3, rng);
      final expensiveWage = NpcGenerator.generateWage(50000000, 1, rng);
      expect(expensiveWage, greaterThan(cheapWage * 50));
      expect(cheapWage, greaterThan(0));
    });

    test('foot generates valid enum values', () {
      final foot = NpcGenerator.generateFoot(SquadRole.st, rng);
      expect(foot, isNotNull);
    });
  });
}

