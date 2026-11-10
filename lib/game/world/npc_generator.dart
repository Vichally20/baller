import 'dart:math';

import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/world/world_models.dart';

/// Deterministically generates full attributes, mental stats, foot, talents,
/// and contract information for NPC footballers.
class NpcGenerator {
  const NpcGenerator._();

  /// Generates complete [PlayerAttributes] from a player's role, rating and age.
  static PlayerAttributes generateAttributes({
    required SquadRole role,
    required int rating,
    required int age,
    required Random rng,
  }) {
    final position = role.position;

    int pace;
    int shot;
    int pass;
    int dribble;
    int defence;
    int physical;

    if (position == null) {
      // Goalkeeper: outfield skills are low, physical/defence are moderate.
      physical = (rating * 0.95 + rng.nextInt(9) - 4).round().clamp(30, 95);
      defence = (rating * 0.85 + rng.nextInt(9) - 4).round().clamp(25, 90);
      pass = (rating * 0.65 + rng.nextInt(11) - 5).round().clamp(20, 85);
      pace = (rating * 0.55 + rng.nextInt(11) - 5).round().clamp(20, 80);
      dribble = (rating * 0.35 + rng.nextInt(11) - 5).round().clamp(15, 70);
      shot = (rating * 0.25 + rng.nextInt(11) - 5).round().clamp(15, 60);
    } else {
      // Outfield position: distribute stats according to position weights.
      // Higher weighted attributes sit above the average rating; lower weighted ones sit below.
      int computeStat(Attribute attr) {
        final weight = position.weights[attr] ?? 0.0;
        final double delta;
        if (weight >= 0.30) {
          delta = 10.0 + (weight - 0.30) * 40.0;
        } else if (weight >= 0.15) {
          delta = (weight - 0.15) * 20.0;
        } else if (weight >= 0.08) {
          delta = -10.0;
        } else {
          delta = -22.0 - (0.08 - weight) * 60.0;
        }
        final jitter = rng.nextInt(9) - 4;
        final raw = rating + delta + jitter;
        return raw.round().clamp(20, 99);
      }

      pace = computeStat(Attribute.pace);
      shot = computeStat(Attribute.shot);
      pass = computeStat(Attribute.pass);
      dribble = computeStat(Attribute.dribble);
      defence = computeStat(Attribute.defence);
      physical = computeStat(Attribute.physical);
    }

    // Mental stats (Ego, Discipline, Teamwork, Composure, Stamina)
    final ego = _generateEgo(role, rating, rng);
    final discipline = _generateDiscipline(role, rating, ego, rng);
    final teamwork = (110 - (ego * 0.6) + (rng.nextInt(15) - 7)).round().clamp(
      15,
      95,
    );
    final composure = (rating * 0.8 + (age - 17) * 0.6 + (rng.nextInt(11) - 5))
        .round()
        .clamp(25, 99);
    final stamina = (physical * 0.75 + 20 + (rng.nextInt(11) - 5))
        .round()
        .clamp(35, 99);

    return PlayerAttributes(
      age: age,
      pace: pace,
      shot: shot,
      pass: pass,
      dribble: dribble,
      defence: defence,
      physical: physical,
      ego: ego,
      tacticalDiscipline: discipline,
      teamwork: teamwork,
      composure: composure,
      stamina: stamina,
    );
  }

  /// Ego is role-based and influenced by overall rating (superstars lean selfish).
  static int _generateEgo(SquadRole role, int rating, Random rng) {
    final base = switch (role) {
      SquadRole.st => 65,
      SquadRole.w => 60,
      SquadRole.am => 55,
      SquadRole.cm => 45,
      SquadRole.fb => 40,
      SquadRole.dm => 32,
      SquadRole.cb => 28,
      SquadRole.gk => 35,
    };
    final ratingBonus = rating >= 80 ? (rating - 75) : 0;
    final noise = rng.nextInt(25) - 12; // -12 to +12
    return (base + ratingBonus + noise).clamp(10, 99);
  }

  /// Tactical discipline is higher in defenders and system players.
  static int _generateDiscipline(
    SquadRole role,
    int rating,
    int ego,
    Random rng,
  ) {
    final base = switch (role) {
      SquadRole.cb || SquadRole.dm => 72,
      SquadRole.fb || SquadRole.gk => 68,
      SquadRole.cm => 62,
      SquadRole.am => 52,
      SquadRole.w => 48,
      SquadRole.st => 42,
    };
    // Higher ego tends to slightly dampen discipline, though exceptions exist.
    final egoPenalty = (ego - 50) * 0.25;
    final noise = rng.nextInt(21) - 10;
    return (base - egoPenalty + noise).round().clamp(15, 95);
  }

  /// Preferred foot: left-sided players have higher left-foot rate.
  static Foot generateFoot(SquadRole role, Random rng) {
    if (role == SquadRole.fb || role == SquadRole.w) {
      return rng.nextDouble() < 0.40 ? Foot.left : Foot.right;
    }
    return rng.nextDouble() < 0.22 ? Foot.left : Foot.right;
  }

  /// Assigns talents based on rating tiers.
  static (Talent?, List<Talent>) generateTalents(int rating, Random rng) {
    Talent? innate;
    final logic = <Talent>[];

    final innatePool = talentsOf(TalentArchetype.innate);
    final logicPool = talentsOf(TalentArchetype.logic);

    if (rating >= 80) {
      // Genius tier
      if (rng.nextDouble() < 0.45 && innatePool.isNotEmpty) {
        innate = innatePool[rng.nextInt(innatePool.length)];
      }
      final logicCount = 1 + rng.nextInt(2); // 1 or 2
      final shuffled = List<Talent>.from(logicPool)..shuffle(rng);
      logic.addAll(shuffled.take(logicCount));
    } else if (rating >= 72) {
      // Rare tier
      if (rng.nextDouble() < 0.18 && innatePool.isNotEmpty) {
        innate = innatePool[rng.nextInt(innatePool.length)];
      }
      if (rng.nextDouble() < 0.60 && logicPool.isNotEmpty) {
        logic.add(logicPool[rng.nextInt(logicPool.length)]);
      }
    } else if (rating >= 58) {
      // Average tier
      if (rng.nextDouble() < 0.25 && logicPool.isNotEmpty) {
        logic.add(logicPool[rng.nextInt(logicPool.length)]);
      }
    }

    return (innate, List.unmodifiable(logic));
  }

  /// Weekly wage in euros estimated from market value and division.
  static int generateWage(int value, int division, Random rng) {
    final wagePercentage = switch (division) {
      1 => 0.10,
      2 => 0.08,
      _ => 0.06,
    };
    final annualWage = value * wagePercentage;
    final weekly = (annualWage / 52.0).round();
    final clamped = weekly.clamp(250, 450000);
    final variation = 0.95 + rng.nextDouble() * 0.10;
    return (clamped * variation).round();
  }
}
