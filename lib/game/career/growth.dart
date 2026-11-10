import 'dart:math';

import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';

/// How the player's stats grow (PROVISIONAL numbers, to tune):
///
/// - In matches, every move that goes well earns experience (XP) for the
///   stat it uses. When a stat's XP reaches [xpToImprove], the stat goes
///   up by 1. Higher stats need more XP, and younger players earn more.
/// - At the end of each season the player ages a year: up to 21 every
///   skill grows by 1; from 30, pace and physical start to fade.

/// Skills never go above this or below [minSkill].
const int maxSkill = 99;
const int minSkill = 20;

/// The stat a move trains. At their corner every move is about clearing
/// the ball, so a "Shoot" there (a clearance) trains Physical.
Attribute statTrainedBy(MatchAction action, PlayState state) =>
    switch (action) {
      MatchAction.run => Attribute.pace,
      MatchAction.pass => Attribute.pass,
      MatchAction.shoot =>
        state == PlayState.cornerAgainst ? Attribute.physical : Attribute.shot,
      MatchAction.dribble => Attribute.dribble,
      MatchAction.mark ||
      MatchAction.slide ||
      MatchAction.shadow ||
      MatchAction.tackle => Attribute.defence,
      MatchAction.nod => Attribute.physical,
    };

/// A move went well: a goal for you, or you keep or win the ball (or a
/// corner, e.g. a shot the keeper tips over).
bool moveSucceeded(MoveOutcome outcome) =>
    outcome.goal == Side.home ||
    (outcome.goal == null &&
        (outcome.next == PlayState.attack ||
            outcome.next == PlayState.cornerFor));

/// Counts a match's successful moves per stat.
class MatchTraining {
  final Map<Attribute, int> successes = {};

  void record(MatchAction action, PlayState before, MoveOutcome outcome) {
    if (!moveSucceeded(outcome)) return;
    final stat = statTrainedBy(action, before);
    successes[stat] = (successes[stat] ?? 0) + 1;
  }
}

/// XP for one successful move.
const int xpPerSuccess = 10;

/// XP a stat needs to go up by 1: harder the better it already is
/// (350 at 55, 550 at 75).
int xpToImprove(int stat) => max(100, (stat - 20) * 10);

/// Younger players learn faster.
double learningRate(int age) => age <= 19
    ? 1.5
    : age <= 23
    ? 1.25
    : age <= 27
    ? 1.0
    : age <= 30
    ? 0.6
    : 0.3;

/// Stats after growth, the XP carried forward, and what changed.
class Growth {
  const Growth({
    required this.attributes,
    required this.xp,
    required this.changes,
  });

  final PlayerAttributes attributes;
  final Map<Attribute, int> xp;

  /// Stat → change (negative when a stat fades). Only non-zero entries.
  final Map<Attribute, int> changes;

  bool get isEmpty => changes.isEmpty;

  /// "+1 Shot, +1 Pace" (or "" when nothing changed).
  String describe() => [
    for (final MapEntry(:key, :value) in changes.entries)
      '${value > 0 ? '+' : '−'}${value.abs()} ${key.label}',
  ].join(', ');
}

/// Turns a match's successful moves into XP, and XP into better stats.
Growth trainFromMatch(Player player, Map<Attribute, int> successes) {
  final rate = learningRate(player.attributes.age);
  final technical = player.location.perk == CountryPerk.technicalSchooling;
  final xp = Map<Attribute, int>.of(player.xp);
  final values = {
    for (final a in Attribute.values.where((a) => a.isSkill))
      a: player.attributes[a],
  };
  final changes = <Attribute, int>{};
  for (final MapEntry(key: stat, value: count) in successes.entries) {
    final perkRate =
        technical && (stat == Attribute.pass || stat == Attribute.dribble)
        ? 1.5
        : 1.0;
    var total =
        (xp[stat] ?? 0) + (count * xpPerSuccess * rate * perkRate).round();
    while (values[stat]! < maxSkill && total >= xpToImprove(values[stat]!)) {
      total -= xpToImprove(values[stat]!);
      values[stat] = values[stat]! + 1;
      changes[stat] = (changes[stat] ?? 0) + 1;
    }
    xp[stat] = values[stat]! >= maxSkill ? 0 : total;
  }
  return Growth(
    attributes: _withSkills(player.attributes, values),
    xp: Map.unmodifiable(xp),
    changes: changes,
  );
}

/// The player a year older, at the end of a season.
Growth ageOneYear(Player player) {
  final age = player.attributes.age + 1;
  final values = {
    for (final a in Attribute.values.where((a) => a.isSkill))
      a: player.attributes[a],
  };
  final Map<Attribute, int> delta = age <= 21
      ? {for (final a in values.keys) a: 1}
      : age <= 29
      ? const {}
      : age <= 32
      ? const {Attribute.pace: -1, Attribute.physical: -1}
      : const {
          Attribute.pace: -2,
          Attribute.physical: -2,
          Attribute.shot: -1,
          Attribute.dribble: -1,
        };
  final changes = <Attribute, int>{};
  for (final MapEntry(key: stat, value: d) in delta.entries) {
    final next = (values[stat]! + d).clamp(minSkill, maxSkill);
    if (next != values[stat]) changes[stat] = next - values[stat]!;
    values[stat] = next;
  }
  return Growth(
    attributes: _withSkills(player.attributes, values).copyWith(age: age),
    xp: player.xp,
    changes: changes,
  );
}

PlayerAttributes _withSkills(
  PlayerAttributes base,
  Map<Attribute, int> values,
) => base.copyWith(
  pace: values[Attribute.pace],
  shot: values[Attribute.shot],
  pass: values[Attribute.pass],
  dribble: values[Attribute.dribble],
  defence: values[Attribute.defence],
  physical: values[Attribute.physical],
);
