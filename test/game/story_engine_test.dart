import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Map<String, Object?> _scenario(String id) => {
  'id': id,
  'title': id,
  'text': 'Text',
  'choices': [
    {
      'text': 'A',
      'outcomes': [
        {'text': 'ok'},
      ],
    },
    {
      'text': 'B',
      'outcomes': [
        {'text': 'ok'},
      ],
    },
  ],
};

StoryContent _content(List<int> scenariosPerChapter) => StoryContent.fromJson(
  itemsJson: <String, Object?>{},
  chapterJson: [
    for (final (c, n) in scenariosPerChapter.indexed)
      (
        'c$c.json',
        {
          'id': 'c$c',
          'title': 'Chapter $c',
          'scenarios': [for (var i = 0; i < n; i++) _scenario('c${c}_s$i')],
          'matches': [
            {'title': 'First match', 'opponent': 'Them'},
          ],
        },
      ),
  ],
);

String _shape(List<StoryEvent> events) =>
    events.map((e) => e is MatchEvent ? 'M' : 'S').join();

final _anyone = testPlayer(1);

/// One chapter per condition map, two scenes each.
StoryContent _conditional(List<Map<String, Object?>?> conditions) =>
    StoryContent.fromJson(
      itemsJson: <String, Object?>{},
      chapterJson: [
        for (final (c, condition) in conditions.indexed)
          (
            'c$c.json',
            {
              'id': 'c$c',
              'title': 'Chapter $c',
              'when': ?condition,
              'verdict': c == 0,
              'scenarios': [_scenario('c${c}_a'), _scenario('c${c}_b')],
            },
          ),
      ],
    );

List<String> _chapterIds(StoryContent content, Player player) =>
    buildSchedule(content, player).map((e) => e.chapter.id).toSet().toList();

void main() {
  group('chapter conditions', () {
    final trialist = placedPlayer(offers: false); // Lagos
    final signed = placedPlayer(offers: true);

    test('pathway: offers, trials or an exact kind', () {
      final content = _conditional([
        {
          'pathway': ['trials'],
        },
        {
          'pathway': ['offers'],
        },
        {
          'pathway': ['academy_trials'],
        },
        null,
      ]);
      expect(_chapterIds(content, trialist), ['c0', 'c2', 'c3']);
      expect(_chapterIds(content, signed), ['c1', 'c3']);
      // No pathway yet: only unconditional chapters.
      expect(_chapterIds(content, _anyone), ['c3']);
    });

    test('tier, region, country and age', () {
      final p = trialist;
      final content = _conditional([
        {
          'tier': [p.tier.name],
        },
        {
          'region': ['europe'],
        },
        {
          'country': ['nigeria'],
          'age': {'min': p.attributes.age, 'max': p.attributes.age},
        },
        {
          'age': {'max': p.attributes.age - 1},
        },
      ]);
      expect(_chapterIds(content, p), ['c0', 'c2']);
    });

    test('mistakes are explained', () {
      for (final (condition, fragment) in [
        (
          {
            'pathway': ['fame'],
          },
          '"fame" is not one of',
        ),
        ({'tier': <String>[]}, '"tier" is empty'),
        (
          {
            'mood': ['happy'],
          },
          'unknown condition "mood"',
        ),
        (
          {
            'age': {'min': 20, 'max': 18},
          },
          '"min" is above "max"',
        ),
        (
          {
            'age': {'oldest': 3},
          },
          'use "min" and/or "max"',
        ),
      ]) {
        expect(
          () => _conditional([condition]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(contains('c0.json › when'), contains(fragment)),
            ),
          ),
        );
      }
    });

    test('the trial verdict is due once the verdict chapter is played', () {
      final content = _conditional([
        {
          'pathway': ['trials'],
        },
        null,
      ]);
      final schedule = buildSchedule(content, trialist);
      // c0: scene, scene, match (3 events), then c1.
      CareerStatus at(int i) =>
          List.filled(i, 0).fold(trialist.status, (s, _) => s.advance());
      expect(trialVerdictDue(schedule, trialist.withStatus(at(2))), isFalse);
      expect(trialVerdictDue(schedule, trialist.withStatus(at(3))), isTrue);
      final afterSigning = trialist
          .withStatus(at(3))
          .withPlacement(trialist.placement!.sign());
      expect(trialVerdictDue(schedule, afterSigning), isFalse);
      expect(trialVerdictDue(schedule, signed), isFalse);
    });
  });

  group('schedule', () {
    test('two scenes, then a match', () {
      expect(_shape(buildSchedule(_content([4]), _anyone)), 'SSMSSM');
    });

    test('an odd scene at the end of a chapter still gets its match', () {
      expect(_shape(buildSchedule(_content([3, 2]), _anyone)), 'SSMSMSSM');
    });

    test('named matches first, then a fallback name', () {
      final matches = buildSchedule(
        _content([4]),
        _anyone,
      ).whereType<MatchEvent>();
      expect(matches.map((m) => m.match.title), ['First match', 'Match']);
    });

    test('cycleOf finds the scenes leading to the next match', () {
      final schedule = buildSchedule(_content([4]), _anyone);
      final c = cycleOf(schedule, 4);
      expect(_shape(c.events), 'SSM');
      expect(c.position, 1);
    });
  });

  test('outcomes are picked by weight', () {
    const choice = Choice(
      text: 'x',
      outcomes: [
        Outcome(text: 'common', weight: 3),
        Outcome(text: 'rare'),
      ],
    );
    final rng = Random(1);
    var common = 0;
    for (var i = 0; i < 4000; i++) {
      if (resolveChoice(choice, rng).text == 'common') common++;
    }
    expect(common / 4000, closeTo(0.75, 0.03));
  });

  test('status: effects apply, meters clamp, money never negative', () {
    final status = CareerStatus.initial.apply(
      const Effects(
        money: -500,
        morale: 80,
        coach: -90,
        teammates: 5,
        addItems: ['boots', 'boots'],
      ),
    );
    expect(status.money, 0);
    expect(status.morale, 100);
    expect(status.coach, 0);
    expect(status.teammates, 55);
    expect(status.items, ['boots', 'boots']);
    final after = status.apply(const Effects(removeItems: ['boots']));
    expect(after.items, ['boots']);
    expect(after.advance().eventIndex, 1);
  });

  test('status survives JSON', () {
    final status = CareerStatus.initial
        .apply(const Effects(money: 20, addItems: ['x']))
        .advance();
    final back = CareerStatus.fromJson(status.toJson())!;
    expect(back.money, 120);
    expect(back.items, ['x']);
    expect(back.eventIndex, 1);
    expect(CareerStatus.fromJson({'money': -1}), isNull);
  });

  test('fillText swaps placeholders for the player', () {
    final player = Player(
      identity: testIdentity,
      attributes: const PlayerAttributes(
        age: 17,
        pace: 50,
        shot: 50,
        pass: 50,
        dribble: 50,
        defence: 50,
        physical: 50,
      ),
      location: startingLocations.first,
      preferredPosition: Position.w,
      worldSeed: 1,
    );
    expect(
      fillText('{first} ({name}, {shirt}) from {city}, {country}', player),
      'Test (Test Player, PLAYER) from Lagos, Nigeria',
    );
  });

  test('fillText names the club, manager and position', () {
    final player = placedPlayer(offers: false); // an academy in Nigeria
    final club = careerClubOf(
      player,
      WorldRepository.forSeed(player.worldSeed),
    )!;
    expect(
      fillText('{club}|{manager}|{position}', player, club: club),
      '${club.club.name} Academy ${player.placement!.site}|'
      '${club.club.manager.name}|${club.decision.position.label}',
    );
    expect(
      fillText('{club}, {manager}, {position}', player),
      'the club, the manager, ${player.preferredPosition.label}',
    );
  });

  group('bad content explains itself', () {
    void expectError(Map<String, Object?> chapter, String fragment) {
      expect(
        () => StoryContent.fromJson(
          itemsJson: <String, Object?>{},
          chapterJson: [('bad.json', chapter)],
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(fragment),
          ),
        ),
      );
    }

    Map<String, Object?> withScenario(Map<String, Object?> s) => {
      'id': 'c',
      'title': 'C',
      'scenarios': [s],
    };

    test('one choice', () {
      final s = _scenario('s')
        ..['choices'] = [(_scenario('s')['choices']! as List).first];
      expectError(withScenario(s), 'give 2 to 4 choices');
    });

    test('unknown effect', () {
      final s = _scenario('s');
      ((s['choices']! as List).first as Map)['outcomes'] = [
        {
          'text': 'x',
          'effects': {'happiness': 5},
        },
      ];
      expectError(withScenario(s), 'unknown effect "happiness"');
    });

    test('item not in items.json', () {
      final s = _scenario('s');
      ((s['choices']! as List).first as Map)['outcomes'] = [
        {
          'text': 'x',
          'effects': {
            'addItems': ['golden_boot'],
          },
        },
      ];
      expectError(withScenario(s), 'golden_boot');
    });

    test('duplicate scenario id', () {
      expectError({
        'id': 'c',
        'title': 'C',
        'scenarios': [_scenario('same'), _scenario('same')],
      }, 'used twice');
    });
  });
}
