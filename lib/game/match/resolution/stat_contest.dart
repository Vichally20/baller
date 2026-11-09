import 'dart:math';

import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/resolution/contest_outcome.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/world/world_models.dart';

/// Stat-based probability resolution for all in-match actions.
class StatContestResolver {
  const StatContestResolver._();

  /// Core 1-on-1 contest between an attacking stat and defending stat.
  ///
  /// Effective stats are reduced by fatigue up to 30%.
  /// Output probability is clamped between 15% and 85%.
  static bool rollContest({
    required int attackStat,
    required int defendStat,
    double attackFatigue = 0.0,
    double defendFatigue = 0.0,
    double momentumMultiplier = 1.0,
    required Random rng,
  }) {
    final effectiveAttack = (attackStat * (1.0 - (attackFatigue * 0.30))) * momentumMultiplier;
    final effectiveDefend = defendStat * (1.0 - (defendFatigue * 0.30));

    final diff = effectiveAttack - effectiveDefend;
    final probability = (0.50 + (diff / 160.0)).clamp(0.15, 0.85);

    return rng.nextDouble() < probability;
  }

  /// Resolves a shot attempt on goal.
  static ContestOutcome resolveShot({
    required SquadPlayer shooter,
    required SquadPlayer goalkeeper,
    required PitchZone zone,
    required Side attackingSide,
    required MatchMomentum momentum,
    required Random rng,
    double fatigue = 0.0,
    bool isUser = false,
  }) {
    final zoneMult = zone.shotViabilityMultiplier;
    final effectiveShot = shooter.attributes.shot * (1.0 - (fatigue * 0.30));
    final composureBonus = (shooter.attributes.composure / 100.0) * 10.0;
    final shotPower = (effectiveShot + composureBonus) * zoneMult * momentum.multiplierFor(attackingSide);

    // Goalkeeper saving capability
    final gkSaveRating = goalkeeper.rating * 0.75;

    final roll = rng.nextDouble() * 100.0;

    // Defending side is the opposite
    final defendingSide = attackingSide == Side.home ? Side.away : Side.home;

    if (roll < shotPower * 0.65) {
      // Clean strike on target! GK gets a save roll
      final gkRoll = rng.nextDouble() * 100.0;
      if (gkRoll > gkSaveRating) {
        // GOAL!
        momentum.onGoal(attackingSide);
        return ContestOutcome(
          result: ContestResult.goal,
          text: '${shooter.name} lets fly… GOAL!',
          nextState: PlayState.defend,
          scoringSide: attackingSide,
          actor: shooter,
          isUserMove: isUser,
        );
      } else {
        // Tipped round the post / saved
        momentum.onSave(defendingSide);
        return ContestOutcome(
          result: ContestResult.saved,
          text: 'Tipped round the post by ${goalkeeper.name}. Corner.',
          nextState: PlayState.cornerFor,
          actor: shooter,
          isUserMove: isUser,
        );
      }
    } else if (roll < shotPower * 0.90) {
      // Blocked by defender or deflected
      return ContestOutcome(
        result: ContestResult.blocked,
        text: 'The shot is blocked by a defender. Corner.',
        nextState: PlayState.cornerFor,
        actor: shooter,
        isUserMove: isUser,
      );
    } else {
      // Off target
      return ContestOutcome(
        result: ContestResult.miss,
        text: 'Wide. Goal kick.',
        nextState: PlayState.defend,
        actor: shooter,
        isUserMove: isUser,
      );
    }
  }

  /// Resolves a pass from [passer] to [receiver].
  static ContestOutcome resolvePass({
    required SquadPlayer passer,
    required SquadPlayer receiver,
    required SquadPlayer defender,
    required Side attackingSide,
    required MatchMomentum momentum,
    required Random rng,
    double openness = 0.7,
    double fatigue = 0.0,
    bool isUser = false,
  }) {
    final success = rollContest(
      attackStat: (passer.attributes.pass * (0.8 + openness * 0.4)).round(),
      defendStat: defender.attributes.defence,
      attackFatigue: fatigue,
      momentumMultiplier: momentum.multiplierFor(attackingSide),
      rng: rng,
    );

    if (success) {
      return ContestOutcome(
        result: ContestResult.passCompleted,
        text: '${passer.name} finds ${receiver.name} cleanly. Still yours.',
        nextState: PlayState.attack,
        actor: passer,
        target: receiver,
        isUserMove: isUser,
      );
    } else {
      return ContestOutcome(
        result: ContestResult.turnover,
        text: 'Intercepted by ${defender.name}. They read the pass.',
        nextState: PlayState.defend,
        actor: passer,
        target: defender,
        isUserMove: isUser,
      );
    }
  }

  /// Resolves a dribble / take-on attempt against [defender].
  static ContestOutcome resolveDribble({
    required SquadPlayer dribbler,
    required SquadPlayer defender,
    required Side attackingSide,
    required MatchMomentum momentum,
    required Random rng,
    double fatigue = 0.0,
    bool isUser = false,
  }) {
    final success = rollContest(
      attackStat: dribbler.attributes.dribble,
      defendStat: defender.attributes.defence,
      attackFatigue: fatigue,
      momentumMultiplier: momentum.multiplierFor(attackingSide),
      rng: rng,
    );

    if (success) {
      return ContestOutcome(
        result: ContestResult.dribbleSuccess,
        text: '${dribbler.name} drops a shoulder and is past his man.',
        nextState: PlayState.attack,
        actor: dribbler,
        target: defender,
        isUserMove: isUser,
      );
    } else {
      final isFoul = rng.nextDouble() < 0.20;
      if (isFoul) {
        return ContestOutcome(
          result: ContestResult.foul,
          text: '${defender.name} lunges in and brings down ${dribbler.name}. Free kick.',
          nextState: PlayState.attack,
          actor: dribbler,
          target: defender,
          isUserMove: isUser,
        );
      }
      return ContestOutcome(
        result: ContestResult.tackled,
        text: 'Tackled by ${defender.name}. They break the other way.',
        nextState: PlayState.defend,
        actor: dribbler,
        target: defender,
        isUserMove: isUser,
      );
    }
  }

  /// Resolves a defensive tackle or slide by [defender] against [attacker].
  static ContestOutcome resolveTackle({
    required SquadPlayer defender,
    required SquadPlayer attacker,
    required Side defendingSide,
    required MatchMomentum momentum,
    required Random rng,
    bool isSlide = false,
    double fatigue = 0.0,
    bool isUser = false,
  }) {
    final success = rollContest(
      attackStat: defender.attributes.defence,
      defendStat: attacker.attributes.dribble,
      attackFatigue: fatigue,
      momentumMultiplier: momentum.multiplierFor(defendingSide),
      rng: rng,
    );

    if (success) {
      return ContestOutcome(
        result: ContestResult.tackled,
        text: isSlide
            ? 'Perfect slide tackle from ${defender.name}. Ball won.'
            : 'Clean tackle. ${defender.name} comes away with it.',
        nextState: PlayState.attack,
        actor: defender,
        target: attacker,
        isUserMove: isUser,
      );
    } else {
      // Failed tackle: attacker gets past and can score
      final scores = rng.nextDouble() < 0.35;
      if (scores) {
        final scoringSide = defendingSide == Side.home ? Side.away : Side.home;
        momentum.onGoal(scoringSide);
        return ContestOutcome(
          result: ContestResult.goal,
          text: 'Beaten, and they finish it. Goal for them.',
          nextState: PlayState.attack,
          scoringSide: scoringSide,
          actor: attacker,
          isUserMove: isUser,
        );
      } else {
        return ContestOutcome(
          result: ContestResult.turnover,
          text: 'Beaten. The shot deflects behind for a corner.',
          nextState: PlayState.cornerAgainst,
          actor: defender,
          target: attacker,
          isUserMove: isUser,
        );
      }
    }
  }
}

