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
///   skill grows by 2, then by 1 up to 29; nothing changes from 30 to 32;
///   from 33, pace, physical, shot and dribble fade.

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

/// The big moments that earn more than [xpPerSuccess].
enum KeyMoment {
  goal('Goal', 'Goals', 30),
  assist('Assist', 'Assists', 25),
  tackle('Tackle won', 'Tackles won', 20),
  clearance('Clearance', 'Clearances', 20);

  const KeyMoment(this.label, this.plural, this.xp);

  final String label;
  final String plural;

  /// XP before the age and country multipliers.
  final int xp;
}

/// What a successful move was: a [KeyMoment], or null for an ordinary one.
KeyMoment? keyMomentOf(
  MatchAction action,
  PlayState before,
  MoveOutcome outcome,
) {
  if (!moveSucceeded(outcome)) return null;
  if (outcome.goal == Side.home) return KeyMoment.goal;
  if (before == PlayState.cornerAgainst &&
      (action == MatchAction.shoot || action == MatchAction.nod)) {
    return KeyMoment.clearance;
  }
  if (action == MatchAction.tackle || action == MatchAction.slide) {
    return KeyMoment.tackle;
  }
  return null;
}

/// Counts a match's moves per stat, how many went well, the XP they
/// earned (before multipliers) and the key moments.
class MatchTraining {
  final Map<Attribute, int> successes = {};
  final Map<Attribute, int> attempts = {};
  final Map<Attribute, int> xp = {};
  final Map<KeyMoment, int> moments = {};

  void record(MatchAction action, PlayState before, MoveOutcome outcome) {
    final stat = statTrainedBy(action, before);
    attempts[stat] = (attempts[stat] ?? 0) + 1;
    if (!moveSucceeded(outcome)) return;
    successes[stat] = (successes[stat] ?? 0) + 1;
    final moment = keyMomentOf(action, before, outcome);
    _add(stat, moment?.xp ?? xpPerSuccess);
    if (moment != null) moments[moment] = (moments[moment] ?? 0) + 1;
  }

  /// A teammate scored from the player's pass: extra XP for Pass.
  void recordAssist() {
    _add(Attribute.pass, KeyMoment.assist.xp);
    moments[KeyMoment.assist] = (moments[KeyMoment.assist] ?? 0) + 1;
  }

  void _add(Attribute stat, int amount) => xp[stat] = (xp[stat] ?? 0) + amount;

  /// Plays [action] in [sim] and records it, including any assist from
  /// the play that followed.
  MoveOutcome play(MatchSim sim, MatchAction action) {
    final before = sim.state;
    final goalsBefore = sim.goals.length;
    final outcome = sim.play(action);
    record(action, before, outcome);
    for (final g in sim.goals.skip(goalsBefore)) {
      if (g.side == Side.home && g.assist?.id == MatchSim.userId) {
        recordAssist();
      }
    }
    return outcome;
  }
}

/// How one stat did in a match: the moves that used it, the XP they
/// earned, and where that leaves the stat.
class StatTraining {
  const StatTraining({
    required this.stat,
    required this.attempts,
    required this.successes,
    required this.multiplier,
    required this.xpGained,
    required this.before,
    required this.after,
    required this.xpBefore,
    required this.xpAfter,
  });

  final Attribute stat;
  final int attempts;
  final int successes;

  /// Age and country perk together (1.5 = 50% more XP).
  final double multiplier;
  final int xpGained;

  /// The stat's value before and after the match.
  final int before;
  final int after;

  /// XP banked towards the next +1, before and after.
  final int xpBefore;
  final int xpAfter;

  int get levelsGained => after - before;

  /// XP the stat now needs for its next +1.
  int get xpNeeded => xpToImprove(after);
}

/// XP for an ordinary successful move ([KeyMoment]s earn more).
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
    this.breakdown = const [],
    this.learningRate = 1,
  });

  final PlayerAttributes attributes;
  final Map<Attribute, int> xp;

  /// Stat → change (negative when a stat fades). Only non-zero entries.
  final Map<Attribute, int> changes;

  /// After a match: every stat the player used, most XP first.
  final List<StatTraining> breakdown;

  /// The age multiplier the match XP was earned at.
  final double learningRate;

  int get totalXp => breakdown.fold(0, (s, t) => s + t.xpGained);

  bool get isEmpty => changes.isEmpty;

  /// "+1 Shot, +1 Pace" (or "" when nothing changed).
  String describe() => [
    for (final MapEntry(:key, :value) in changes.entries)
      '${value > 0 ? '+' : '−'}${value.abs()} ${key.label}',
  ].join(', ');
}

/// Turns a match's successful moves into XP, and XP into better stats.
/// [earned] is each stat's XP before multipliers ([MatchTraining.xp]);
/// without it every success is worth [xpPerSuccess]. [attempts] (moves
/// tried per stat) only feeds the [Growth.breakdown].
Growth trainFromMatch(
  Player player,
  Map<Attribute, int> successes, {
  Map<Attribute, int> attempts = const {},
  Map<Attribute, int>? earned,
}) {
  final rate = learningRate(player.attributes.age);
  final technical = player.location.perk == CountryPerk.technicalSchooling;
  final xp = Map<Attribute, int>.of(player.xp);
  final values = {
    for (final a in Attribute.values.where((a) => a.isSkill))
      a: player.attributes[a],
  };
  final changes = <Attribute, int>{};
  final breakdown = <StatTraining>[];
  for (final stat in {...attempts.keys, ...successes.keys, ...?earned?.keys}) {
    final count = successes[stat] ?? 0;
    final perkRate =
        technical && (stat == Attribute.pass || stat == Attribute.dribble)
        ? 1.5
        : 1.0;
    final before = values[stat]!;
    final xpBefore = xp[stat] ?? 0;
    final raw = earned?[stat] ?? count * xpPerSuccess;
    final gained = (raw * rate * perkRate).round();
    var total = xpBefore + gained;
    while (values[stat]! < maxSkill && total >= xpToImprove(values[stat]!)) {
      total -= xpToImprove(values[stat]!);
      values[stat] = values[stat]! + 1;
      changes[stat] = (changes[stat] ?? 0) + 1;
    }
    xp[stat] = values[stat]! >= maxSkill ? 0 : total;
    breakdown.add(
      StatTraining(
        stat: stat,
        attempts: max(attempts[stat] ?? 0, count),
        successes: count,
        multiplier: rate * perkRate,
        xpGained: gained,
        before: before,
        after: values[stat]!,
        xpBefore: xpBefore,
        xpAfter: xp[stat]!,
      ),
    );
  }
  breakdown.sort((a, b) {
    final byXp = b.xpGained.compareTo(a.xpGained);
    return byXp != 0 ? byXp : b.attempts.compareTo(a.attempts);
  });
  return Growth(
    attributes: _withSkills(player.attributes, values),
    xp: Map.unmodifiable(xp),
    changes: changes,
    breakdown: List.unmodifiable(breakdown),
    learningRate: rate,
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
      ? {for (final a in values.keys) a: 2}
      : age <= 29
      ? {for (final a in values.keys) a: 1}
      : age <= 32
      ? const {}
      : const {
          Attribute.pace: -1,
          Attribute.physical: -1,
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
