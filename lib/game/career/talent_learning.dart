import 'dart:math';

import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';

/// Logic talents by tier, and learning new ones (docs/career-design.md §13).
///
/// - New players start with: Poor 0, Average 1 ([averageSecondLogicChance]
///   for a second), Rare 2, Genius 2.
/// - The first time the talent score reaches each of [logicMilestones]
///   (Average level, Rare level, 70), there's a [learnChance] of learning
///   a new logic talent, if there's room: 2 at most, 3 from 70.

/// Chance an Average player starts with a second logic talent.
const double averageSecondLogicChance = 1 / 3;

/// Talent scores where a new logic talent may be learned, each once.
const List<int> logicMilestones = [
  TalentTier.averageFrom,
  TalentTier.rareFrom,
  thirdLogicFrom,
];

/// Chance of learning one at each milestone.
const double learnChance = 0.5;

/// How many logic talents a new player of [tier] starts with.
int startingLogicCount(TalentTier tier, Random rng) => switch (tier) {
  TalentTier.poor => 0,
  TalentTier.average => rng.nextDouble() < averageSecondLogicChance ? 2 : 1,
  TalentTier.rare || TalentTier.genius => 2,
};

/// How many logic talents a player with [score] can hold.
int logicCap(double score) =>
    score >= thirdLogicFrom ? maxLogicTalents : usualLogicTalents;

/// The milestones [score] has reached.
Set<int> milestonesReached(double score) => {
  for (final m in logicMilestones)
    if (score >= m) m,
};

/// [after] (the player once their stats changed) with any logic talents
/// learned at milestones crossed since [before], and which were learned.
/// Each milestone is rolled once, ever, and remembered on the player.
(Player, List<Talent>) learnTalents(Player before, Player after) {
  final checked = <int>{
    ...(before.talentMilestones ?? milestonesReached(before.talentScore)),
  };
  final score = after.talentScore;
  final logic = [...after.logicTalents];
  final learned = <Talent>[];
  final rng = Random(
    after.worldSeed ^
        (after.season.season * 7919) ^
        (after.season.round * 104729) ^
        (after.status.eventIndex * 31),
  );
  for (final m in logicMilestones) {
    if (score < m || checked.contains(m)) continue;
    checked.add(m);
    if (logic.length >= logicCap(score)) continue;
    if (rng.nextDouble() >= learnChance) continue;
    final pool = [
      for (final t in allTalents)
        if (t.archetype == TalentArchetype.logic && !logic.contains(t)) t,
    ];
    if (pool.isEmpty) continue;
    final talent = pool[rng.nextInt(pool.length)];
    logic.add(talent);
    learned.add(talent);
  }
  return (
    after.copyWith(
      logicTalents: List.unmodifiable(logic),
      talentMilestones: Set.unmodifiable(checked),
    ),
    learned,
  );
}
