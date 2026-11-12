import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/life.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/match_progress.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/season_progress.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/story/career_status.dart';

/// The player's career state.
class Player {
  Player({
    required this.identity,
    required this.attributes,
    required this.location,
    required this.preferredPosition,
    required this.worldSeed,
    this.innateTalent,
    this.logicTalents = const [],
    this.status = CareerStatus.initial,
    this.placement,
    this.season = SeasonProgress.first,
    this.xp = const {},
    this.life = Life.start,
    this.match,
    this.talentMilestones,
  }) : assert(
         innateTalent == null ||
             innateTalent.archetype == TalentArchetype.innate,
       ),
       assert(logicTalents.length <= maxLogicTalents),
       assert(logicTalents.every((t) => t.archetype == TalentArchetype.logic));

  final PlayerIdentity identity;

  /// Final skills, country bonus included.
  final PlayerAttributes attributes;
  final Location location;

  /// Where the player wants to play. The manager has the final say.
  final Position preferredPosition;

  /// Seed of this career's generated world (leagues, clubs, managers).
  final int worldSeed;

  /// Most players have none.
  final Talent? innateTalent;

  /// Up to [maxLogicTalents]; more can be learned during the career.
  final List<Talent> logicTalents;

  /// Money, morale, relationships, items and story progress.
  final CareerStatus status;

  /// The club the career is attached to. Null until a pathway is chosen
  /// (and in saves from before pathways existed).
  final Placement? placement;

  /// League progress once the written story runs out (season mode).
  final SeasonProgress season;

  /// Match experience banked towards each skill's next +1.
  final Map<Attribute, int> xp;

  /// Agent, manager talks and an agreed move.
  final Life life;

  /// A match started but not finished (resumed when the player comes back).
  final MatchProgress? match;

  /// Talent-score milestones already rolled for a new logic talent
  /// (career/talent_learning.dart). Null in older saves: then the ones the
  /// player has already passed count as rolled.
  final Set<int>? talentMilestones;

  double get talentScore =>
      TalentTier.score(attributes, hasInnate: innateTalent != null);

  TalentTier get tier => TalentTier.of(talentScore);

  Player withStatus(CareerStatus status) => copyWith(status: status);

  Player withPlacement(Placement placement) => copyWith(placement: placement);

  Player withSeason(SeasonProgress season) => copyWith(season: season);

  Player copyWith({
    PlayerIdentity? identity,
    PlayerAttributes? attributes,
    Location? location,
    Position? preferredPosition,
    int? worldSeed,
    Talent? innateTalent,
    List<Talent>? logicTalents,
    CareerStatus? status,
    Placement? placement,
    SeasonProgress? season,
    Map<Attribute, int>? xp,
    Life? life,
    MatchProgress? match,
    bool clearMatch = false,
    Set<int>? talentMilestones,
  }) => Player(
    identity: identity ?? this.identity,
    attributes: attributes ?? this.attributes,
    location: location ?? this.location,
    preferredPosition: preferredPosition ?? this.preferredPosition,
    worldSeed: worldSeed ?? this.worldSeed,
    innateTalent: innateTalent ?? this.innateTalent,
    logicTalents: logicTalents ?? this.logicTalents,
    status: status ?? this.status,
    placement: placement ?? this.placement,
    season: season ?? this.season,
    xp: xp ?? this.xp,
    life: life ?? this.life,
    match: clearMatch ? null : (match ?? this.match),
    talentMilestones: talentMilestones ?? this.talentMilestones,
  );
}
