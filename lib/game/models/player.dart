import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
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

  double get talentScore =>
      TalentTier.score(attributes, hasInnate: innateTalent != null);

  TalentTier get tier => TalentTier.of(talentScore);

  Player withStatus(CareerStatus status) =>
      _copy(status: status, placement: placement);

  Player withPlacement(Placement placement) =>
      _copy(status: status, placement: placement);

  Player _copy({required CareerStatus status, required Placement? placement}) =>
      Player(
        identity: identity,
        attributes: attributes,
        location: location,
        preferredPosition: preferredPosition,
        worldSeed: worldSeed,
        innateTalent: innateTalent,
        logicTalents: logicTalents,
        status: status,
        placement: placement,
      );
}
