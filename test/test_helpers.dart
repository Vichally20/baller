import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/character_creation.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';

/// A valid identity for tests that don't care about names.
const testIdentity = PlayerIdentity(
  name: 'Test Player',
  shirtName: 'PLAYER',
  foot: Foot.right,
);

/// A fresh creation (Lagos, winger unless given) with a seeded random.
CharacterCreation testCreation({
  int seed = 1,
  double? innateChance,
  Location? location,
  Position position = Position.w,
}) => CharacterCreation(
  identity: testIdentity,
  location: location ?? startingLocations.first,
  preferredPosition: position,
  rng: Random(seed),
  innateChance: innateChance ?? innateTalentChance,
);

/// Spins every stat wheel.
CharacterCreation rolledCreation({
  int seed = 1,
  double? innateChance,
  Location? location,
}) {
  final creation = testCreation(
    seed: seed,
    innateChance: innateChance,
    location: location,
  );
  while (!creation.statsComplete) {
    creation.spinStat();
  }
  return creation;
}

/// A finished, valid player built from the real game data.
Player testPlayer(int seed, {double? innateChance, Location? location}) =>
    (rolledCreation(
      seed: seed,
      innateChance: innateChance,
      location: location,
    )..drawTalents()).build();

/// A test player whose pathway is offers (or trials), placed at the first
/// option. Offers are signed straight away; trials only if [signed].
Player placedPlayer({
  required bool offers,
  bool signed = false,
  Location? location,
}) {
  final player = pathwayPlayer(offers: offers, location: location);
  final pathway = pathwayFor(player, WorldRepository.forSeed(player.worldSeed));
  final option = pathway.options.first;
  return player.withPlacement(
    Placement(
      kind: pathway.kind,
      clubId: option.club.id,
      site: option.site,
      signed: offers || signed,
    ),
  );
}

/// [placedPlayer] for trials, made 17 so a signing plays youth football
/// against sides generated at their level.
Player youthTrialist({bool signed = false}) {
  final p = placedPlayer(offers: false, signed: signed);
  return p.copyWith(attributes: p.attributes.copyWith(age: 17));
}

/// The first test player whose pathway is offers (or trials), not yet
/// placed anywhere.
Player pathwayPlayer({required bool offers, Location? location}) {
  for (var seed = 1; ; seed++) {
    final player = testPlayer(seed, location: location);
    if (pathwayKindFor(player).offers == offers) return player;
  }
}
