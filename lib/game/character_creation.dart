import 'dart:math';

import 'package:baller/game/career/talent_learning.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/data/wheels.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:baller/game/story/story_content.dart';

/// The outcome of one stat-wheel spin.
class SpinResult {
  const SpinResult({required this.wheel, required this.index});

  final WheelSpec wheel;

  /// Index of the segment the wheel landed on.
  final int index;

  int get value => wheel.segments[index];
}

/// The talents a new player starts with.
class StartingTalents {
  const StartingTalents({this.innate, this.logic = const []});

  /// Null for most players.
  final Talent? innate;

  /// 0 to [maxStartingLogicTalents] distinct logic talents.
  final List<Talent> logic;
}

/// Builds a new player from choices made up front ([identity], [location],
/// [preferredPosition]) and two random stages, in order:
/// 1. spin each stat wheel once ([spinStat]),
/// 2. draw starting talents ([drawTalents]).
///
/// Outcomes are decided here (not in the UI) so they can be seeded and tested;
/// the UI only displays them.
class CharacterCreation {
  CharacterCreation({
    required this.identity,
    required this.location,
    required this.preferredPosition,
    Random? rng,
    this.wheels = defaultWheels,
    this.talents = allTalents,
    this.innateChance = innateTalentChance,
  }) : _rng = rng ?? Random();

  /// Name, shirt name and foot, chosen before any spins.
  final PlayerIdentity identity;

  /// Chosen starting country; gives a stat bonus and a perk.
  final Location location;
  final Position preferredPosition;

  final Random _rng;
  final List<WheelSpec> wheels;
  final List<Talent> talents;
  final double innateChance;

  final Map<Attribute, int> _rolls = {};
  StartingTalents? _talents;

  // --- Stage 1: stats -------------------------------------------------------

  bool get statsComplete => _rolls.length == wheels.length;

  /// The next stat wheel to spin, or null when every one has been spun.
  WheelSpec? get currentWheel => statsComplete ? null : wheels[_rolls.length];

  /// Raw wheel results, before the country bonus.
  Map<Attribute, int> get rolls => Map.unmodifiable(_rolls);

  /// What the country adds to [attribute] (0 for most).
  int bonusFor(Attribute attribute) =>
      attribute == location.bonusStat ? location.bonusAmount : 0;

  SpinResult spinStat() {
    final wheel = currentWheel;
    if (wheel == null) throw StateError('All stat wheels have been spun');
    final result = SpinResult(
      wheel: wheel,
      index: _rng.nextInt(wheel.segments.length),
    );
    _rolls[wheel.attribute] = result.value;
    return result;
  }

  // --- Stage 2: talents -----------------------------------------------------

  StartingTalents? get startingTalents => _talents;

  /// Rolls [innateChance] for one innate talent, then gives logic talents
  /// by talent tier (Poor 0, Average 1 or 2, Rare and Genius 2; see
  /// career/talent_learning.dart). Italy's Tactical brain perk guarantees
  /// at least one.
  StartingTalents drawTalents() {
    if (!statsComplete) throw StateError('Spin every stat wheel first');
    if (_talents != null) throw StateError('Talents already drawn');

    final innatePool = [
      for (final t in talents)
        if (t.archetype == TalentArchetype.innate) t,
    ];
    final logicPool = [
      for (final t in talents)
        if (t.archetype == TalentArchetype.logic) t,
    ]..shuffle(_rng);

    final innate = innatePool.isNotEmpty && _rng.nextDouble() < innateChance
        ? innatePool[_rng.nextInt(innatePool.length)]
        : null;
    final tier = TalentTier.of(
      TalentTier.score(finalAttributes(), hasInnate: innate != null),
    );
    var logicCount = startingLogicCount(tier, _rng);
    if (location.perk == CountryPerk.tacticalBrain) {
      logicCount = max(logicCount, 1);
    }

    return _talents = StartingTalents(
      innate: innate,
      logic: List.unmodifiable(
        logicPool.take(min(logicCount, logicPool.length)),
      ),
    );
  }

  // --- Result ---------------------------------------------------------------

  bool get isComplete => _talents != null;

  /// Drawn once so building twice gives the same world.
  late final int _worldSeed = _rng.nextInt(1 << 31);

  /// Stats with the country bonus added (capped at 100).
  PlayerAttributes finalAttributes() {
    if (!statsComplete) throw StateError('Spin every stat wheel first');
    return PlayerAttributes.fromRolls({
      for (final MapEntry(:key, :value) in _rolls.entries)
        key: min(100, value + bonusFor(key)),
    });
  }

  Player build() {
    final talents = _talents;
    if (talents == null) {
      throw StateError('Character creation is not finished');
    }
    return Player(
      identity: identity,
      attributes: finalAttributes(),
      location: location,
      preferredPosition: preferredPosition,
      worldSeed: _worldSeed,
      innateTalent: talents.innate,
      logicTalents: talents.logic,
      // Milestones already passed at the start don't give a talent.
      talentMilestones: milestonesReached(
        TalentTier.score(finalAttributes(), hasInnate: talents.innate != null),
      ),
      status: CareerStatus.initial.apply(startingPerkEffects(location.perk)),
    );
  }
}

/// Perks that change where a career starts. The rest act later in the game.
Effects startingPerkEffects(CountryPerk perk) => switch (perk) {
  CountryPerk.mentors => const Effects(coach: 10),
  CountryPerk.flair => const Effects(morale: 10),
  CountryPerk.professionalism => const Effects(coach: 10, teammates: 10),
  _ => Effects.none,
};
