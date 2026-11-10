import 'dart:math';

import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/world/world_models.dart';

/// Context provided to evaluate whether a talent can trigger.
class TalentActivationContext {
  const TalentActivationContext({
    required this.actor,
    required this.action,
    required this.zone,
    required this.goalkeeper,
    required this.defender,
    this.receiver,
    required this.momentum,
    required this.rng,
  });

  final SquadPlayer actor;
  final MatchAction action;
  final PitchZone zone;
  final SquadPlayer goalkeeper;
  final SquadPlayer defender;
  final SquadPlayer? receiver;
  final MatchMomentum momentum;
  final Random rng;
}

/// The result of an activated talent modifying contest parameters.
class TalentTriggerResult {
  const TalentTriggerResult({
    required this.talent,
    required this.announcement,
    this.boostedAttackStat,
    this.suppressedDefendStat,
    this.bypassDefence = false,
    this.bypassGoalkeeper = false,
    this.automaticGoal = false,
  });

  final Talent talent;

  /// Commentary text announcing the talent activation (e.g. "Kaiser's Predator Eye activates!").
  final String announcement;

  /// Replacement or boosted attack stat for the contest.
  final int? boostedAttackStat;

  /// Replacement or suppressed defend stat for the contest (e.g. 0).
  final int? suppressedDefendStat;

  /// True if defender blocking/interception check is completely bypassed.
  final bool bypassDefence;

  /// True if goalkeeper save roll is negated.
  final bool bypassGoalkeeper;

  /// Automatic 100% chance goal (e.g. El Fenómeno rounding the keeper).
  final bool automaticGoal;
}

/// Evaluates and triggers all 24 Innate and Logic talents.
class TalentResolver {
  const TalentResolver._();

  /// Checks if any talent held by [context.actor] triggers on this [context.action].
  static TalentTriggerResult? checkTalents(TalentActivationContext context) {
    // Check innate talent first, then logic talents
    final candidateTalents = <Talent>[
      if (context.actor.innateTalent != null) context.actor.innateTalent!,
      ...context.actor.logicTalents,
    ];

    for (final talent in candidateTalents) {
      final result = _evaluateTalent(talent, context);
      if (result != null) return result;
    }

    return null;
  }

  static TalentTriggerResult? _evaluateTalent(
    Talent talent,
    TalentActivationContext ctx,
  ) {
    final actorName = ctx.actor.name;
    final rng = ctx.rng;

    switch (talent.id) {
      // ===== INNATE TALENTS =====

      case 'unstoppable_locomotive':
        // The Knock-On: Dribble/Run on flanks with space ahead
        if (ctx.action == MatchAction.dribble ||
            ctx.action == MatchAction.run) {
          if (rng.nextDouble() < 0.60) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName's Knock-On activates! He pushes the ball 15 yards ahead in a pure footrace!",
              suppressedDefendStat: (ctx.defender.attributes.pace * 0.7)
                  .round(),
              boostedAttackStat: ctx.actor.attributes.pace + 15,
            );
          }
        }
        break;

      case 'apex_bully':
        // Target Man Dominance: Aerial duel / nod in box
        if (ctx.action == MatchAction.nod) {
          if (rng.nextDouble() < 0.65) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName's Apex Bully dominates! He physically overpowers his marker completely!",
              suppressedDefendStat: 0,
              boostedAttackStat: 99,
            );
          }
        }
        break;

      case 'gravity_well':
        // Sticky Feet: Invites tackles, draws fouls or slips past
        if (ctx.action == MatchAction.dribble) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName's Gravity Well draws in the tackle! The defender is completely off-balance!",
              suppressedDefendStat: 20,
              boostedAttackStat: ctx.actor.attributes.dribble + 20,
            );
          }
        }
        break;

      case 'artillery_strike':
        // Chaos Cannon: 30-yard screamer bypassing midfield
        if (ctx.action == MatchAction.shoot &&
            ctx.zone == PitchZone.finalThird) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName unleashes an Artillery Strike from 30 yards out! A thunderous Chaos Cannon!",
              bypassDefence: true,
              boostedAttackStat: ctx.actor.attributes.shot + 15,
            );
          }
        }
        break;

      case 'el_fenomeno':
        // The Keeper Bypass: Rounds keeper in 1-on-1 inside box
        if (ctx.action == MatchAction.shoot &&
            ctx.zone == PitchZone.opponentBox) {
          if (rng.nextDouble() < 0.45) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName drops a shoulder with El Fenómeno! He rounds the keeper for an open tap-in!",
              bypassGoalkeeper: true,
              automaticGoal: true,
            );
          }
        }
        break;

      case 'ambidextrous_chaos':
        // Two-Footed Threat: Removes angle/weak-foot penalty
        if (ctx.action == MatchAction.shoot) {
          if (rng.nextDouble() < 0.60) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName strikes with Two-Footed Threat! Weak-foot penalty completely ignored!",
              boostedAttackStat: ctx.actor.attributes.shot + 10,
            );
          }
        }
        break;

      case 'hyper_speed':
        // Explosive Acceleration: Outruns positioning checks
        if (ctx.action == MatchAction.run ||
            ctx.action == MatchAction.dribble) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Hyper-Speed explosion from $actorName! Pure burst of pace tears through the line!",
              boostedAttackStat: 99,
            );
          }
        }
        break;

      case 'acrobatic_finishing':
        // Biological Finishing: Impossible angles in box
        if (ctx.action == MatchAction.shoot && ctx.zone.isInShootingRange) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName contorts with Acrobatic Finishing! An impossible strike on target!",
              boostedAttackStat: ctx.actor.attributes.shot + 18,
            );
          }
        }
        break;

      case 'predator_eye':
        // Blinds the keeper behind defender
        if (ctx.action == MatchAction.shoot) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName's Predator Eye locks in! He hides his strike behind the defender's legs!",
              suppressedDefendStat: 15,
              bypassGoalkeeper: true,
            );
          }
        }
        break;

      case 'black_hole_trapping':
        // Kills pass momentum instantly
        if (ctx.action == MatchAction.dribble ||
            ctx.action == MatchAction.run) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Black Hole Trapping! $actorName kills the ball dead with an unreal first touch!",
              bypassDefence: true,
            );
          }
        }
        break;

      case 'elastic_dribbling':
        // Multiplies Dribble vs defenders
        if (ctx.action == MatchAction.dribble) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName enters Elastic Dribbling rhythm! Unpredictable footwork breaks standard logic!",
              boostedAttackStat: (ctx.actor.attributes.dribble * 1.25)
                  .round()
                  .clamp(50, 99),
            );
          }
        }
        break;

      case 'puppeteer':
        // Destructive Accuracy: curves into top corner
        if (ctx.action == MatchAction.shoot) {
          if (rng.nextDouble() < 0.45) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName plays Puppeteer! He manipulates the keeper's position and curls it top corner!",
              boostedAttackStat: 95,
            );
          }
        }
        break;

      // ===== LOGIC TALENTS =====

      case 'tactical_vacuum':
        // False 9: pulls CBs out of position
        if (ctx.action == MatchAction.pass || ctx.action == MatchAction.run) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName operates as a Tactical Vacuum! Defenders are pulled completely out of position!",
              suppressedDefendStat: (ctx.defender.attributes.defence * 0.5)
                  .round(),
            );
          }
        }
        break;

      case 'the_ghost':
        // Late arrival: free unmarked shot in box
        if ((ctx.action == MatchAction.shoot ||
                ctx.action == MatchAction.nod) &&
            ctx.zone == PitchZone.opponentBox) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "The Ghost arrives late! $actorName ghosted into the box completely unmarked!",
              bypassDefence: true,
              boostedAttackStat: ctx.actor.attributes.shot + 15,
            );
          }
        }
        break;

      case 'the_scalpel':
        // Line-breaking through ball
        if (ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName threads The Scalpel! A laser pass slices the entire opposition block in half!",
              bypassDefence: true,
              boostedAttackStat: 98,
            );
          }
        }
        break;

      case 'tempo_dictator':
        // Calms momentum and resets game pacing
        if (ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.60) {
            ctx.momentum.home = 0.5; // Resets momentum to neutral
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Tempo Dictator at work! $actorName slows down the tempo and resets team momentum!",
              boostedAttackStat: ctx.actor.attributes.pass + 15,
            );
          }
        }
        break;

      case 'preventative_vision':
        // Reads opponent and intercepts
        if (ctx.action == MatchAction.tackle ||
            ctx.action == MatchAction.mark) {
          if (rng.nextDouble() < 0.60) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Preventative Vision! $actorName snuffs out the attack before it can even start!",
              boostedAttackStat: 95,
            );
          }
        }
        break;

      case 'geometric_architect':
        // Impossible passing angles: backheels & flicks
        if (ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Geometric Architect! $actorName invents an impossible passing angle with a slick flick!",
              suppressedDefendStat: 20,
            );
          }
        }
        break;

      case 'meta_vision':
        // Supreme spatial IQ: anticipates 5 seconds ahead
        if (rng.nextDouble() < 0.60) {
          return TalentTriggerResult(
            talent: talent,
            announcement:
                "$actorName's Meta-Vision activates! Scanning the pitch, he foresees the optimal sequence!",
            boostedAttackStat:
                (ctx.actor.attributes.pass > ctx.actor.attributes.shot
                    ? ctx.actor.attributes.pass
                    : ctx.actor.attributes.shot) +
                15,
          );
        }
        break;

      case 'the_impact':
        // Zero-windup shot: unblockable by defender
        if (ctx.action == MatchAction.shoot) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "The Impact! $actorName unleashes with zero wind-up! The defense has no time to block!",
              bypassDefence: true,
              boostedAttackStat: ctx.actor.attributes.shot + 15,
            );
          }
        }
        break;

      case 'blind_spot_exploitation':
        // Unmarked movement
        if (ctx.action == MatchAction.run || ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "$actorName slips into the defender's blind spot! He collects the ball in complete freedom!",
              bypassDefence: true,
            );
          }
        }
        break;

      case 'egocentrism':
        // Uses teammates as bait
        if (ctx.action == MatchAction.shoot ||
            ctx.action == MatchAction.dribble) {
          if (rng.nextDouble() < 0.50) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Egocentrism! $actorName uses his teammate as bait to seize the protagonist role!",
              boostedAttackStat: ctx.actor.attributes.shot + 12,
            );
          }
        }
        break;

      case 'planetary_hotline':
        // High-speed one-touch linkup
        if (ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.55) {
            return TalentTriggerResult(
              talent: talent,
              announcement: "Planetary Hotline linkup! Rapid one-touch combinations slice open the backline!",
              boostedAttackStat: 94,
            );
          }
        }
        break;

      case 'logical_playmaking':
        // Perfect tactical information pass
        if (ctx.action == MatchAction.pass) {
          if (rng.nextDouble() < 0.60) {
            return TalentTriggerResult(
              talent: talent,
              announcement:
                  "Logical Playmaking! $actorName delivers a millimeter-perfect pass loaded with tactical IQ!",
              boostedAttackStat: 96,
            );
          }
        }
        break;
    }

    return null;
  }
}
