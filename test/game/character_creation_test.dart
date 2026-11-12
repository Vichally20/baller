import 'package:baller/game/data/locations.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/data/wheels.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Location _country(String id) => startingLocations.firstWhere((l) => l.id == id);

PlayerAttributes _stats(int all) => PlayerAttributes(
  age: 16,
  pace: all,
  shot: all,
  pass: all,
  dribble: all,
  defence: all,
  physical: all,
);

void main() {
  test('data matches the design', () {
    expect(defaultWheels.first.segments, [for (var a = 15; a <= 26; a++) a]);
    expect(allTalents, hasLength(24));
    expect(talentsOf(TalentArchetype.innate), hasLength(12));
    expect(startingLocations, hasLength(10));
    expect(
      startingLocations.map((l) => l.country),
      containsAll(['Japan', 'Germany', 'France', 'Italy']),
    );
    expect(startingLocations.map((l) => l.id).toSet(), hasLength(10));
  });

  test('spins each stat wheel once, in order', () {
    final creation = testCreation();
    for (final wheel in defaultWheels) {
      expect(creation.currentWheel, same(wheel));
      final result = creation.spinStat();
      expect(wheel.segments, contains(result.value));
      expect(creation.rolls[wheel.attribute], result.value);
    }
    expect(creation.statsComplete, isTrue);
    expect(creation.spinStat, throwsStateError);
  });

  test('stages run in order and only once', () {
    final creation = testCreation();
    expect(creation.drawTalents, throwsStateError);
    expect(creation.build, throwsStateError);
    while (!creation.statsComplete) {
      creation.spinStat();
    }
    final drawn = creation.drawTalents();
    expect(creation.startingTalents, same(drawn));
    expect(creation.drawTalents, throwsStateError);
    expect(creation.isComplete, isTrue);
  });

  group('country', () {
    test('adds its stat bonus on top of the wheel', () {
      for (final location in startingLocations) {
        final creation = rolledCreation(seed: 3, location: location);
        final stats = creation.finalAttributes();
        for (final a in Attribute.values) {
          final expected = a == location.bonusStat
              ? creation.rolls[a]! + 5
              : creation.rolls[a]!;
          expect(stats[a], expected, reason: '${location.country} ${a.label}');
        }
      }
    });

    test('starting perks change the opening status', () {
      CareerStatus status(String id) =>
          testPlayer(1, location: _country(id)).status;
      expect(status('ghana').coach, 60);
      expect(status('brazil').morale, 60);
      expect(status('japan').coach, 60);
      expect(status('japan').teammates, 60);
      expect(status('england').coach, 50);
    });

    test('Italy always starts with a Logic talent', () {
      for (var seed = 0; seed < 200; seed++) {
        final drawn = rolledCreation(
          seed: seed,
          location: _country('italy'),
        ).drawTalents();
        expect(drawn.logic, isNotEmpty);
      }
    });
  });

  group('talent tier', () {
    test('thresholds', () {
      expect(TalentTier.of(51.9), TalentTier.poor);
      expect(TalentTier.of(52), TalentTier.average);
      expect(TalentTier.of(61.9), TalentTier.average);
      expect(TalentTier.of(62), TalentTier.rare);
      expect(TalentTier.of(67.9), TalentTier.rare);
      expect(TalentTier.of(68), TalentTier.genius);
    });

    test('an Innate talent adds 3 to the score', () {
      expect(TalentTier.score(_stats(60), hasInnate: false), 60);
      expect(TalentTier.score(_stats(60), hasInnate: true), 63);
    });

    test('player exposes score and tier', () {
      final player = testPlayer(5, innateChance: 0);
      expect(
        player.talentScore,
        TalentTier.score(player.attributes, hasInnate: false),
      );
      expect(player.tier, TalentTier.of(player.talentScore));
    });
  });

  group('position', () {
    test('weights sum to 1 for every position', () {
      for (final p in Position.values) {
        final sum = p.weights.values.fold(0.0, (a, b) => a + b);
        expect(sum, closeTo(1, 1e-9), reason: p.label);
      }
    });

    test('ratings follow the stats that matter', () {
      final fast = PlayerAttributes(
        age: 18,
        pace: 80,
        shot: 40,
        pass: 40,
        dribble: 80,
        defence: 40,
        physical: 40,
      );
      expect(Position.ranked(fast).first.$1, Position.w);
      final wall = PlayerAttributes(
        age: 18,
        pace: 40,
        shot: 40,
        pass: 40,
        dribble: 40,
        defence: 80,
        physical: 80,
      );
      expect(Position.ranked(wall).first.$1, Position.cb);
      expect(Position.cb.rating(_stats(60)), 60);
    });

    test('the chosen position is kept on the player', () {
      final creation = testCreation(position: Position.st);
      while (!creation.statsComplete) {
        creation.spinStat();
      }
      creation.drawTalents();
      expect(creation.build().preferredPosition, Position.st);
    });
  });

  test('starting talents obey the archetype limits', () {
    final logicCounts = <int>{};
    var innateCount = 0;
    const runs = 2000;
    for (var seed = 0; seed < runs; seed++) {
      final drawn = rolledCreation(seed: seed).drawTalents();
      if (drawn.innate case final innate?) {
        innateCount++;
        expect(innate.archetype, TalentArchetype.innate);
      }
      expect(drawn.logic.length, lessThanOrEqualTo(maxStartingLogicTalents));
      expect(drawn.logic.toSet(), hasLength(drawn.logic.length));
      logicCounts.add(drawn.logic.length);
    }
    expect(logicCounts, {0, 1, 2});
    expect(innateCount / runs, closeTo(innateTalentChance, 0.05));
  });

  test('innate chance of 0 or 1 is respected', () {
    for (var seed = 0; seed < 50; seed++) {
      expect(
        rolledCreation(seed: seed, innateChance: 0).drawTalents().innate,
        isNull,
      );
      expect(
        rolledCreation(seed: seed, innateChance: 1).drawTalents().innate,
        isNotNull,
      );
    }
  });

  test('same seed gives the same player', () {
    final a = testPlayer(7);
    final b = testPlayer(7);
    for (final attr in Attribute.values) {
      expect(a.attributes[attr], b.attributes[attr]);
    }
    expect(a.innateTalent, same(b.innateTalent));
    expect(a.logicTalents, b.logicTalents);
  });
}
