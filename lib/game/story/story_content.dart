/// Story content written in JSON files under assets/content/ — see
/// docs/writing-scenarios.md for the format. Parsing is strict: a mistake in
/// a file throws a [FormatException] naming the exact place, so writers find
/// it immediately (the content test runs every file).
library;

import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/talent_tier.dart';

/// Changes an outcome makes to the career. All numbers are deltas.
class Effects {
  const Effects({
    this.money = 0,
    this.morale = 0,
    this.coach = 0,
    this.teammates = 0,
    this.addItems = const [],
    this.removeItems = const [],
  });

  static const none = Effects();

  final int money;
  final int morale;
  final int coach;
  final int teammates;
  final List<String> addItems;
  final List<String> removeItems;

  bool get isEmpty =>
      money == 0 &&
      morale == 0 &&
      coach == 0 &&
      teammates == 0 &&
      addItems.isEmpty &&
      removeItems.isEmpty;
}

class Outcome {
  const Outcome({
    required this.text,
    this.weight = 1,
    this.effects = Effects.none,
  });

  final String text;

  /// Relative chance among the choice's outcomes.
  final int weight;
  final Effects effects;
}

class Choice {
  const Choice({required this.text, required this.outcomes});

  final String text;

  /// One is picked at random (by weight) when the choice is made.
  final List<Outcome> outcomes;
}

class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.text,
    required this.choices,
  });

  final String id;
  final String title;
  final String text;
  final List<Choice> choices;
}

class MatchInfo {
  const MatchInfo({required this.title, required this.opponent});

  static const fallback = MatchInfo(title: 'Match', opponent: 'Opponents');

  final String title;
  final String opponent;
}

/// Which players a chapter is for. Every given part must match; a part
/// left out matches everyone.
class ChapterCondition {
  const ChapterCondition({
    this.pathways,
    this.tiers,
    this.regions,
    this.countries,
    this.minAge,
    this.maxAge,
  });

  static const always = ChapterCondition();

  /// "offers", "trials" or a [PathwayKind] id.
  final Set<String>? pathways;
  final Set<TalentTier>? tiers;
  final Set<Region>? regions;

  /// Starting location ids, e.g. "nigeria".
  final Set<String>? countries;
  final int? minAge;
  final int? maxAge;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.scenarios,
    this.matches = const [],
    this.when = ChapterCondition.always,
    this.verdict = false,
    this.pool = false,
  });

  final String id;
  final String title;
  final List<Scenario> scenarios;

  /// Who plays this chapter.
  final ChapterCondition when;

  /// For trial chapters: the club gives its verdict when the chapter ends.
  final bool verdict;

  /// A pool of repeatable scenes for season mode, not part of the story's
  /// order. Its scenes are drawn two before each league match.
  final bool pool;

  /// Names the matches that follow each pair of scenarios, in order.
  final List<MatchInfo> matches;
}

class Item {
  const Item({required this.id, required this.name, required this.description});

  final String id;
  final String name;
  final String description;
}

/// Everything the writers have written, loaded and checked.
class StoryContent {
  StoryContent({required this.chapters, required this.items}) {
    _checkReferences();
  }

  final List<Chapter> chapters;
  final Map<String, Item> items;

  /// Parses the item catalogue and chapter files.
  factory StoryContent.fromJson({
    required Object? itemsJson,
    required List<(String file, Object? json)> chapterJson,
  }) {
    final items = _parseItems(itemsJson);
    final chapters = [
      for (final (file, json) in chapterJson) _parseChapter(json, file),
    ];
    return StoryContent(chapters: chapters, items: items);
  }

  void _checkReferences() {
    final scenarioIds = <String>{};
    for (final chapter in chapters) {
      for (final scenario in chapter.scenarios) {
        if (!scenarioIds.add(scenario.id)) {
          throw FormatException('Scenario id "${scenario.id}" is used twice');
        }
        for (final choice in scenario.choices) {
          for (final outcome in choice.outcomes) {
            for (final id in [
              ...outcome.effects.addItems,
              ...outcome.effects.removeItems,
            ]) {
              if (!items.containsKey(id)) {
                throw FormatException(
                  'Scenario "${scenario.id}" uses item "$id", which is not in '
                  'items.json',
                );
              }
            }
          }
        }
      }
    }
  }
}

// --- Parsing ----------------------------------------------------------------

Map<String, Item> _parseItems(Object? json) {
  final map = _map(json, 'items.json');
  return {
    for (final MapEntry(:key, :value) in map.entries)
      key: () {
        final where = 'items.json › $key';
        final item = _map(value, where);
        return Item(
          id: key,
          name: _string(item, 'name', where),
          description: _string(item, 'description', where),
        );
      }(),
  };
}

Chapter _parseChapter(Object? json, String file) {
  final map = _map(json, file);
  final id = _string(map, 'id', file);
  final scenarios = _list(map, 'scenarios', file);
  if (scenarios.isEmpty) throw FormatException('$file: "scenarios" is empty');
  final verdict = map['verdict'] ?? false;
  if (verdict is! bool) {
    throw FormatException('$file: "verdict" must be true or false');
  }
  final pool = map['pool'] ?? false;
  if (pool is! bool) {
    throw FormatException('$file: "pool" must be true or false');
  }
  if (pool && verdict) {
    throw FormatException('$file: a pool chapter cannot have a verdict');
  }
  return Chapter(
    id: id,
    title: _string(map, 'title', file),
    when: map.containsKey('when')
        ? _parseCondition(map['when'], '$file › when')
        : ChapterCondition.always,
    verdict: verdict,
    pool: pool,
    scenarios: [
      for (var i = 0; i < scenarios.length; i++)
        _parseScenario(scenarios[i], '$file › scenarios[$i]'),
    ],
    matches: [
      for (final (i, m) in (_optionalList(map, 'matches', file)).indexed)
        () {
          final where = '$file › matches[$i]';
          final match = _map(m, where);
          return MatchInfo(
            title: _string(match, 'title', where),
            opponent: _string(match, 'opponent', where),
          );
        }(),
    ],
  );
}

ChapterCondition _parseCondition(Object? json, String where) {
  final map = _map(json, where);
  const keys = {'pathway', 'tier', 'region', 'country', 'age'};
  for (final key in map.keys) {
    if (!keys.contains(key)) {
      throw FormatException(
        '$where: unknown condition "$key" (use ${keys.join(', ')})',
      );
    }
  }

  /// A non-empty list of known ids, or null when the key is absent.
  Set<T>? ids<T>(String key, Map<String, T> known) {
    if (!map.containsKey(key)) return null;
    final list = _list(map, key, where);
    if (list.isEmpty) throw FormatException('$where: "$key" is empty');
    return {
      for (final (i, v) in list.indexed)
        known[v] ??
            (throw FormatException(
              '$where › $key[$i]: "$v" is not one of ${known.keys.join(', ')}',
            )),
    };
  }

  int? minAge;
  int? maxAge;
  if (map.containsKey('age')) {
    final age = _map(map['age'], '$where › age');
    for (final key in age.keys) {
      if (key != 'min' && key != 'max') {
        throw FormatException('$where › age: use "min" and/or "max"');
      }
    }
    int? bound(String key) {
      final value = age[key];
      if (value == null) return null;
      if (value is! int) {
        throw FormatException('$where › age: "$key" must be a whole number');
      }
      return value;
    }

    minAge = bound('min');
    maxAge = bound('max');
    if (minAge == null && maxAge == null) {
      throw FormatException('$where › age: give "min" and/or "max"');
    }
    if (minAge != null && maxAge != null && minAge > maxAge) {
      throw FormatException('$where › age: "min" is above "max"');
    }
  }

  return ChapterCondition(
    pathways: ids('pathway', {
      for (final v in PathwayKind.conditionValues) v: v,
    }),
    tiers: ids('tier', {for (final t in TalentTier.values) t.name: t}),
    regions: ids('region', {for (final r in Region.values) r.id: r}),
    countries: ids('country', {for (final l in startingLocations) l.id: l.id}),
    minAge: minAge,
    maxAge: maxAge,
  );
}

Scenario _parseScenario(Object? json, String where) {
  final map = _map(json, where);
  final id = _string(map, 'id', where);
  final here = '$where ($id)';
  final choices = _list(map, 'choices', here);
  if (choices.length < 2 || choices.length > 4) {
    throw FormatException('$here: give 2 to 4 choices');
  }
  return Scenario(
    id: id,
    title: _string(map, 'title', here),
    text: _string(map, 'text', here),
    choices: [
      for (var i = 0; i < choices.length; i++)
        _parseChoice(choices[i], '$here › choices[$i]'),
    ],
  );
}

Choice _parseChoice(Object? json, String where) {
  final map = _map(json, where);
  final outcomes = _list(map, 'outcomes', where);
  if (outcomes.isEmpty) throw FormatException('$where: "outcomes" is empty');
  return Choice(
    text: _string(map, 'text', where),
    outcomes: [
      for (var i = 0; i < outcomes.length; i++)
        _parseOutcome(outcomes[i], '$where › outcomes[$i]'),
    ],
  );
}

Outcome _parseOutcome(Object? json, String where) {
  final map = _map(json, where);
  final weight = map['weight'] ?? 1;
  if (weight is! int || weight < 1) {
    throw FormatException('$where: "weight" must be a whole number ≥ 1');
  }
  return Outcome(
    text: _string(map, 'text', where),
    weight: weight,
    effects: map.containsKey('effects')
        ? _parseEffects(map['effects'], '$where › effects')
        : Effects.none,
  );
}

const _effectKeys = {
  'money',
  'morale',
  'coach',
  'teammates',
  'addItems',
  'removeItems',
};

Effects _parseEffects(Object? json, String where) {
  final map = _map(json, where);
  for (final key in map.keys) {
    if (!_effectKeys.contains(key)) {
      throw FormatException(
        '$where: unknown effect "$key" (use ${_effectKeys.join(', ')})',
      );
    }
  }
  int number(String key) {
    final value = map[key] ?? 0;
    if (value is! int) {
      throw FormatException('$where: "$key" must be a whole number');
    }
    return value;
  }

  List<String> ids(String key) => [
    for (final (i, v) in _optionalList(map, key, where).indexed)
      v is String && v.isNotEmpty
          ? v
          : throw FormatException('$where › $key[$i]: must be an item id'),
  ];

  return Effects(
    money: number('money'),
    morale: number('morale'),
    coach: number('coach'),
    teammates: number('teammates'),
    addItems: ids('addItems'),
    removeItems: ids('removeItems'),
  );
}

Map<String, Object?> _map(Object? json, String where) {
  if (json is Map<String, Object?>) return json;
  throw FormatException('$where: expected an object { ... }');
}

String _string(Map<String, Object?> map, String key, String where) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$where: "$key" must be non-empty text');
}

List<Object?> _list(Map<String, Object?> map, String key, String where) {
  final value = map[key];
  if (value is List<Object?>) return value;
  throw FormatException('$where: "$key" must be a list [ ... ]');
}

List<Object?> _optionalList(
  Map<String, Object?> map,
  String key,
  String where,
) => map.containsKey(key) ? _list(map, key, where) : const [];
