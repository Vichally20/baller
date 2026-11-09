// Checks every story file in assets/content/. Writers: run
//   flutter test test/content_test.dart
// after editing; a failure names the exact file and place to fix.
import 'dart:convert';
import 'dart:io';

import 'package:baller/game/models/placement.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

StoryContent _loadFromDisk() {
  Object? read(String path) =>
      jsonDecode(File('assets/content/$path').readAsStringSync());
  final story = read('story.json')! as Map<String, Object?>;
  final files = (story['chapters']! as List).cast<String>();
  return StoryContent.fromJson(
    itemsJson: read('items.json'),
    chapterJson: [for (final f in files) (f, read(f))],
  );
}

const _placeholders = {
  '{name}',
  '{first}',
  '{shirt}',
  '{city}',
  '{country}',
  '{club}',
  '{manager}',
  '{position}',
};

void main() {
  test('every content file loads', () {
    final content = _loadFromDisk();
    expect(content.chapters, isNotEmpty);
  });

  test('only known {placeholders} are used', () {
    final content = _loadFromDisk();
    final token = RegExp(r'\{[^}]*\}');
    for (final chapter in content.chapters) {
      for (final s in chapter.scenarios) {
        final texts = [
          s.text,
          for (final c in s.choices) ...[
            c.text,
            for (final o in c.outcomes) o.text,
          ],
        ];
        for (final text in texts) {
          for (final m in token.allMatches(text)) {
            expect(
              _placeholders,
              contains(m[0]),
              reason: 'Unknown placeholder ${m[0]} in scenario "${s.id}"',
            );
          }
        }
      }
    }
  });

  test('trialists open with the trial: two scenes, then the trial match', () {
    final schedule = buildSchedule(
      _loadFromDisk(),
      placedPlayer(offers: false),
    );
    expect(schedule.map((e) => e.chapter.id).toSet(), {'trial'});
    expect((schedule[0] as ScenarioEvent).scenario.id, 'the_scout');
    expect((schedule[1] as ScenarioEvent).scenario.id, 'training_ground');
    expect((schedule[2] as MatchEvent).match.title, 'Trial match');
    expect(schedule.first.chapter.verdict, isTrue);
  });

  test('players with offers open with their first days at the club', () {
    final schedule = buildSchedule(_loadFromDisk(), placedPlayer(offers: true));
    expect(schedule.map((e) => e.chapter.id).toSet(), {'first_days'});
    expect((schedule[0] as ScenarioEvent).scenario.id, 'arrival');
  });

  test('every pathway has a chapter to play', () {
    final content = _loadFromDisk();
    for (final kind in PathwayKind.values) {
      expect(
        content.chapters.any((c) => c.when.pathways?.any(kind.matches) ?? true),
        isTrue,
        reason: kind.id,
      );
    }
  });
}
