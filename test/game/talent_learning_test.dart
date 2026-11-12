import 'dart:convert';
import 'dart:math';

import 'package:baller/game/career/growth.dart';
import 'package:baller/game/career/talent_learning.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/match/autopilot.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

final _logic = [
  for (final t in allTalents)
    if (t.archetype == TalentArchetype.logic) t,
];

/// A player whose six skills are all [level] (talent score = [level]
/// with no innate talent).
Player _player(
  int level, {
  int logic = 0,
  Set<int>? milestones,
  int seed = 1,
}) => Player(
  identity: testIdentity,
  attributes: PlayerAttributes(
    age: 20,
    pace: level,
    shot: level,
    pass: level,
    dribble: level,
    defence: level,
    physical: level,
  ),
  location: startingLocations.firstWhere(
    (l) => l.perk != CountryPerk.tacticalBrain,
  ),
  preferredPosition: Position.w,
  worldSeed: seed,
  logicTalents: _logic.take(logic).toList(),
  talentMilestones: milestones,
);

Player _grownTo(Player p, int level) => p.copyWith(
  attributes: p.attributes.copyWith(
    pace: level,
    shot: level,
    pass: level,
    dribble: level,
    defence: level,
    physical: level,
  ),
);

void main() {
  group('starting logic talents by tier', () {
    test('Poor 0, Average 1 or 2, Rare and Genius 2', () {
      final rng = Random(1);
      expect(startingLogicCount(TalentTier.poor, rng), 0);
      expect(startingLogicCount(TalentTier.rare, rng), 2);
      expect(startingLogicCount(TalentTier.genius, rng), 2);
      final average = [
        for (var i = 0; i < 300; i++)
          startingLogicCount(TalentTier.average, rng),
      ];
      expect(average.toSet(), {1, 2});
      final twos = average.where((n) => n == 2).length / average.length;
      expect(twos, closeTo(averageSecondLogicChance, 0.08));
    });

    test('new players follow their tier', () {
      final notItaly = startingLocations.firstWhere(
        (l) => l.perk != CountryPerk.tacticalBrain,
      );
      for (var seed = 1; seed < 200; seed++) {
        final p = testPlayer(seed, location: notItaly);
        final expected = switch (p.tier) {
          TalentTier.poor => {0},
          TalentTier.average => {1, 2},
          _ => {2},
        };
        expect(expected, contains(p.logicTalents.length), reason: '$seed');
        // Milestones already passed at the start are spent.
        expect(p.talentMilestones, milestonesReached(p.talentScore));
      }
    });
  });

  group('learning at milestones', () {
    test('crossing Rare level is a 50% chance, rolled once', () {
      var learnedCount = 0;
      for (var seed = 0; seed < 400; seed++) {
        final before = _player(57, logic: 1, milestones: {52}, seed: seed);
        final (after, learned) = learnTalents(before, _grownTo(before, 63));
        expect(after.talentMilestones, {52, 62});
        expect(after.logicTalents.length, 1 + learned.length);
        if (learned.isNotEmpty) learnedCount++;
        // Already rolled: no second chance at the same milestone.
        final (again, more) = learnTalents(after, _grownTo(after, 64));
        expect(more, isEmpty);
        expect(again.logicTalents, after.logicTalents);
      }
      expect(learnedCount / 400, closeTo(learnChance, 0.08));
    });

    test('two at most below 70; a third only from 70', () {
      for (var seed = 0; seed < 50; seed++) {
        final full = _player(57, logic: 2, milestones: {52}, seed: seed);
        expect(learnTalents(full, _grownTo(full, 63)).$2, isEmpty);
      }
      var thirds = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rare = _player(65, logic: 2, milestones: {52, 62}, seed: seed);
        final (after, learned) = learnTalents(rare, _grownTo(rare, 70));
        expect(after.logicTalents.length, lessThanOrEqualTo(maxLogicTalents));
        if (learned.isNotEmpty) thirds++;
      }
      expect(thirds, greaterThan(0));
    });

    test('older saves count milestones already passed as rolled', () {
      final legacy = _player(63, logic: 1);
      expect(legacy.talentMilestones, isNull);
      final (after, learned) = learnTalents(legacy, _grownTo(legacy, 64));
      expect(learned, isEmpty);
      expect(after.talentMilestones, {52, 62});
    });

    test('milestones are saved', () {
      final p = _player(63, logic: 1, milestones: {52, 62});
      const codec = PlayerCodec();
      final back = codec.fromJson(jsonDecode(jsonEncode(codec.toJson(p))))!;
      expect(back.talentMilestones, {52, 62});
    });
  });

  group('weighted XP', () {
    test('goals, assists, tackles and clearances earn more', () {
      final t = MatchTraining();
      const keep = MoveOutcome(1, '', PlayState.attack);
      const goal = MoveOutcome(1, '', PlayState.defend, goal: Side.home);
      const won = MoveOutcome(1, '', PlayState.attack);
      t.record(MatchAction.pass, PlayState.attack, keep);
      t.record(MatchAction.shoot, PlayState.attack, goal);
      t.record(MatchAction.tackle, PlayState.defend, won);
      t.record(MatchAction.shoot, PlayState.cornerAgainst, won);
      t.recordAssist();
      expect(t.xp[Attribute.pass], xpPerSuccess + KeyMoment.assist.xp);
      expect(t.xp[Attribute.shot], KeyMoment.goal.xp);
      expect(t.xp[Attribute.defence], KeyMoment.tackle.xp);
      expect(t.xp[Attribute.physical], KeyMoment.clearance.xp);
      expect(t.moments, {
        KeyMoment.goal: 1,
        KeyMoment.assist: 1,
        KeyMoment.tackle: 1,
        KeyMoment.clearance: 1,
      });

      final player = _player(55);
      final growth = trainFromMatch(
        player,
        t.successes,
        attempts: t.attempts,
        earned: t.xp,
      );
      final rate = learningRate(player.attributes.age);
      final shot = growth.breakdown.firstWhere((s) => s.stat == Attribute.shot);
      expect(shot.xpGained, (KeyMoment.goal.xp * rate).round());
    });

    test('a pass that sets up a goal is your assist', () {
      final player = placedPlayer(offers: false);
      var assists = 0;
      for (var seed = 0; seed < 60; seed++) {
        final sim = MatchSim(
          shirtName: 'T',
          user: player,
          random: Random(seed),
          creditSeed: seed,
        );
        final t = MatchTraining();
        final rng = Random(seed);
        while (!sim.isOver) {
          if (sim.isHalfTime) sim.startSecondHalf();
          t.play(sim, autoMove(sim, player.attributes, rng));
        }
        final credited = sim.goals
            .where(
              (g) => g.side == Side.home && g.assist?.id == MatchSim.userId,
            )
            .length;
        expect(t.moments[KeyMoment.assist] ?? 0, credited);
        assists += credited;
      }
      expect(assists, greaterThan(0));
    });
  });
}
