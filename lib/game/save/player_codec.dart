import 'package:baller/game/data/locations.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/story/career_status.dart';

/// Converts a [Player] to and from JSON for saving.
///
/// Talents and locations are stored by id and looked up again on load, so
/// renaming or rewording them doesn't break old saves. A save that no longer
/// fits the game data (unknown id, missing stat, broken limits) decodes to
/// null instead of throwing.
class PlayerCodec {
  const PlayerCodec({
    this.talents = allTalents,
    this.locations = startingLocations,
  });

  /// Bump when the JSON shape changes incompatibly.
  static const int version = 1;

  final List<Talent> talents;
  final List<Location> locations;

  Map<String, Object?> toJson(Player player) => {
    'version': version,
    'identity': {
      'name': player.identity.name,
      'shirt': player.identity.shirtName,
      'foot': player.identity.foot.name,
    },
    'attributes': {
      for (final a in Attribute.values) a.name: player.attributes[a],
      'ego': player.attributes.ego,
      'tacticalDiscipline': player.attributes.tacticalDiscipline,
      'teamwork': player.attributes.teamwork,
      'composure': player.attributes.composure,
      'stamina': player.attributes.stamina,
    },
    'location': player.location.id,
    'position': player.preferredPosition.name,
    'world': player.worldSeed,
    'innate': player.innateTalent?.id,
    'logic': [for (final t in player.logicTalents) t.id],
    'status': player.status.toJson(),
    'placement': ?player.placement?.toJson(),
  };

  Player? fromJson(Object? json) {
    if (json case {
      'version': version,
      'attributes': final Map<String, Object?> attributes,
      'location': final String locationId,
      'innate': final String? innateId,
      'logic': final List<Object?> logicIds,
    }) {
      // Saves from before names existed have no identity.
      final identity = json.containsKey('identity')
          ? _identity(json['identity'])
          : PlayerIdentity.unnamed;
      if (identity == null) return null;

      // Saves from before the story existed start at the beginning.
      final status = json.containsKey('status')
          ? CareerStatus.fromJson(json['status'])
          : CareerStatus.initial;
      if (status == null) return null;

      // Saves from before pathways existed have none; the hub asks for one.
      Placement? placement;
      if (json['placement'] case final Object placementJson) {
        placement = Placement.fromJson(placementJson);
        if (placement == null) return null;
      }

      final rolls = <Attribute, int>{};
      for (final a in Attribute.values) {
        if (attributes[a.name] case final int value) {
          rolls[a] = value;
        } else {
          return null;
        }
      }

      final location = _find(locations, (l) => l.id == locationId);
      if (location == null) return null;

      Talent? innate;
      if (innateId != null) {
        innate = _talent(innateId, TalentArchetype.innate);
        if (innate == null) return null;
      }

      final logic = <Talent>[];
      for (final id in logicIds) {
        final talent = id is String ? _talent(id, TalentArchetype.logic) : null;
        if (talent == null || logic.contains(talent)) return null;
        logic.add(talent);
      }
      if (logic.length > maxLogicTalents) return null;

      final ego = attributes['ego'] is int ? attributes['ego'] as int : 50;
      final tacticalDiscipline = attributes['tacticalDiscipline'] is int
          ? attributes['tacticalDiscipline'] as int
          : 50;
      final teamwork = attributes['teamwork'] is int
          ? attributes['teamwork'] as int
          : 50;
      final composure = attributes['composure'] is int
          ? attributes['composure'] as int
          : 50;
      final stamina = attributes['stamina'] is int
          ? attributes['stamina'] as int
          : 70;

      final stats = PlayerAttributes.fromRolls(
        rolls,
        ego: ego,
        tacticalDiscipline: tacticalDiscipline,
        teamwork: teamwork,
        composure: composure,
        stamina: stamina,
      );
      // Saves from before positions existed use the best-fitting one.
      final Position position;
      if (json['position'] case final String name) {
        final found = _find(Position.values, (p) => p.name == name);
        if (found == null) return null;
        position = found;
      } else {
        position = Position.ranked(stats).first.$1;
      }

      // Saves from before the world existed get a seed from their own data,
      // so it is the same every time they load.
      final worldSeed = switch (json['world']) {
        final int seed => seed,
        _ => _stableHash(
          '${identity.name}|$locationId|${rolls.values.join(',')}',
        ),
      };

      return Player(
        identity: identity,
        worldSeed: worldSeed,
        attributes: stats,
        location: location,
        preferredPosition: position,
        innateTalent: innate,
        logicTalents: List.unmodifiable(logic),
        status: status,
        placement: placement,
      );
    }
    return null;
  }

  PlayerIdentity? _identity(Object? json) {
    if (json case {
      'name': final String name,
      'shirt': final String shirt,
      'foot': final String footName,
    }) {
      final foot = _find(Foot.values, (f) => f.name == footName);
      if (foot == null ||
          PlayerIdentity.nameError(name) != null ||
          PlayerIdentity.shirtError(shirt) != null ||
          shirt.trim().isEmpty) {
        return null;
      }
      return PlayerIdentity.fromInput(name: name, shirtName: shirt, foot: foot);
    }
    return null;
  }

  Talent? _talent(String id, TalentArchetype archetype) =>
      _find(talents, (t) => t.id == id && t.archetype == archetype);

  static T? _find<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  /// FNV-1a: stable across runs and platforms, unlike String.hashCode.
  static int _stableHash(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
