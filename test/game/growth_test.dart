import 'dart:convert';
import 'dart:math';

import 'package:baller/game/career/growth.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Player _player({int age = 18, int level = 55, String location = 'nigeria'}) =>
    Player(
      identity: testIdentity,
      attributes: PlayerAttributes(
        age: age,
        pace: level,
        shot: level,
        pass: level,
        dribble: level,
        defence: level,
        physical: level,
      ),
      location: startingLocations.firstWhere((l) => l.id == location),
      preferredPosition: Position.w,
      worldSeed: 1,
    );

void main() {
  test('each move trains its stat; a clearance trains Physical', () {
    expect(statTrainedBy(MatchAction.shoot, PlayState.attack), Attribute.shot);
    expect(
      statTrainedBy(MatchAction.shoot, PlayState.cornerAgainst),
      Attribute.physical,
    );
    expect(statTrainedBy(MatchAction.run, PlayState.attack), Attribute.pace);
    expect(
      statTrainedBy(MatchAction.tackle, PlayState.defend),
      Attribute.defence,
    );
    expect(
      statTrainedBy(MatchAction.nod, PlayState.cornerFor),
      Attribute.physical,
    );
  });

  test('success: a goal, or keeping or winning the ball', () {
    expect(
      moveSucceeded(
        const MoveOutcome(1, 'GOAL', PlayState.defend, goal: Side.home),
      ),
      isTrue,
    );
    expect(moveSucceeded(const MoveOutcome(1, 'x', PlayState.attack)), isTrue);
    expect(
      moveSucceeded(const MoveOutcome(1, 'x', PlayState.cornerFor)),
      isTrue,
    );
    expect(moveSucceeded(const MoveOutcome(1, 'x', PlayState.defend)), isFalse);
    expect(
      moveSucceeded(
        const MoveOutcome(1, 'x', PlayState.attack, goal: Side.away),
      ),
      isFalse,
    );
  });

  group('training', () {
    test('XP builds up; the stat rises when it reaches the threshold', () {
      // 25 years old: 10 XP a success. Shot 55 needs 350.
      final player = _player(age: 25);
      final some = trainFromMatch(player, {Attribute.shot: 20});
      expect(some.isEmpty, isTrue);
      expect(some.xp[Attribute.shot], 200);

      final enough = trainFromMatch(player.copyWith(xp: some.xp), {
        Attribute.shot: 20,
      });
      expect(enough.changes, {Attribute.shot: 1});
      expect(enough.attributes.shot, 56);
      expect(enough.xp[Attribute.shot], 50); // 400 − 350 carried over
      expect(enough.describe(), '+1 Shot');
    });

    test('young players learn faster; old ones slower', () {
      int xpAt(int age) => trainFromMatch(_player(age: age), {
        Attribute.pace: 10,
      }).xp[Attribute.pace]!;
      expect(xpAt(17), 150);
      expect(xpAt(25), 100);
      expect(xpAt(33), 30);
    });

    test("Spain's technical schooling speeds up Pass and Dribble", () {
      final spain = _player(age: 25, location: 'spain');
      final g = trainFromMatch(spain, {Attribute.pass: 10, Attribute.shot: 10});
      expect(g.xp[Attribute.pass], 150);
      expect(g.xp[Attribute.shot], 100);
    });

    test('stats stop at 99', () {
      final g = trainFromMatch(_player(level: 99), {Attribute.shot: 500});
      expect(g.attributes.shot, 99);
      expect(g.isEmpty, isTrue);
    });

    test('a season of matches gives a few points, not dozens', () {
      // A 16-year-old playing 38 matches, moves picked at random.
      var player = _player(age: 16);
      final start = player.attributes;
      for (var m = 0; m < 38; m++) {
        final sim = MatchSim(shirtName: 'ME', user: player, random: Random(m));
        final training = MatchTraining();
        final pick = Random(m + 1);
        while (!sim.isOver) {
          if (sim.isHalfTime) {
            sim.startSecondHalf();
            continue;
          }
          final options = sim.pad.values.toList();
          final action = options[pick.nextInt(options.length)];
          final before = sim.state;
          training.record(action, before, sim.play(action));
        }
        final g = trainFromMatch(player, training.successes);
        player = player.copyWith(attributes: g.attributes, xp: g.xp);
      }
      final gained = [
        for (final a in Attribute.values.where((a) => a.isSkill))
          player.attributes[a] - start[a],
      ];
      final total = gained.fold(0, (s, g) => s + g);
      expect(total, inInclusiveRange(4, 30), reason: '$gained');
    });
  });

  group('ageing', () {
    test('up to 21: +2 to every skill', () {
      final g = ageOneYear(_player(age: 18));
      expect(g.attributes.age, 19);
      expect(g.changes.values.toSet(), {2});
      expect(g.changes, hasLength(6));
    });

    test('22 to 29: +1; 30 to 32: no change; 33+: four skills fade', () {
      final mid = ageOneYear(_player(age: 25));
      expect(mid.changes.values.toSet(), {1});
      expect(mid.changes, hasLength(6));
      expect(ageOneYear(_player(age: 30)).isEmpty, isTrue);
      final old = ageOneYear(_player(age: 33));
      expect(old.changes, {
        Attribute.pace: -1,
        Attribute.physical: -1,
        Attribute.shot: -1,
        Attribute.dribble: -1,
      });
      expect(old.describe(), '−1 Pace, −1 Physical, −1 Shot, −1 Dribble');
    });
  });

  test("a match's growth is saved with the result", () {
    final player = _player(age: 18);
    const chapter = Chapter(id: 'c', title: 'C', scenarios: []);
    const event = MatchEvent(chapter, MatchInfo.fallback);
    final growth = trainFromMatch(player, {Attribute.shot: 40});
    final after = afterMatch(
      player,
      event,
      goalsFor: 1,
      goalsAgainst: 0,
      growth: growth,
    );
    expect(after.attributes.shot, greaterThan(55));
    expect(after.status.eventIndex, 1);

    const codec = PlayerCodec();
    final back = codec.fromJson(jsonDecode(jsonEncode(codec.toJson(after))))!;
    expect(back.attributes.shot, after.attributes.shot);
    expect(back.xp, after.xp);
    final legacy = codec.toJson(after)..remove('xp');
    expect(codec.fromJson(legacy)!.xp, isEmpty);
  });
}
