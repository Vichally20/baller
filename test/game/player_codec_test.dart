import 'dart:convert';

import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Player _player(int seed, {double innateChance = 1}) => testPlayer(
  seed,
  innateChance: innateChance,
  location: startingLocations[seed % startingLocations.length],
);

void main() {
  const codec = PlayerCodec();

  /// Encodes to a JSON string and back, like the real save does.
  Player? roundTrip(Player p) =>
      codec.fromJson(jsonDecode(jsonEncode(codec.toJson(p))));

  test('round-trips stats, talents and country', () {
    for (var seed = 0; seed < 50; seed++) {
      final original = _player(seed, innateChance: seed.isEven ? 1 : 0);
      final loaded = roundTrip(original)!;
      for (final a in Attribute.values) {
        expect(loaded.attributes[a], original.attributes[a]);
      }
      expect(loaded.attributes.ego, original.attributes.ego);
      expect(
        loaded.attributes.tacticalDiscipline,
        original.attributes.tacticalDiscipline,
      );
      expect(loaded.attributes.teamwork, original.attributes.teamwork);
      expect(loaded.attributes.composure, original.attributes.composure);
      expect(loaded.attributes.stamina, original.attributes.stamina);
      expect(loaded.location, same(original.location));
      expect(loaded.innateTalent, same(original.innateTalent));
      expect(loaded.logicTalents, original.logicTalents);
      expect(loaded.identity.name, original.identity.name);
      expect(loaded.identity.shirtName, original.identity.shirtName);
      expect(loaded.identity.foot, original.identity.foot);
      expect(loaded.preferredPosition, original.preferredPosition);
      expect(loaded.status.coach, original.status.coach);
      expect(loaded.worldSeed, original.worldSeed);
    }
  });

  test('round-trips the placement; older saves have none', () {
    final player = placedPlayer(offers: false);
    final back = codec.fromJson(jsonDecode(jsonEncode(codec.toJson(player))))!;
    final placement = back.placement!;
    expect(placement.kind, player.placement!.kind);
    expect(placement.clubId, player.placement!.clubId);
    expect(placement.site, player.placement!.site);
    expect(placement.signed, isFalse);

    final legacy = codec.toJson(testPlayer(3))..remove('placement');
    expect(codec.fromJson(legacy)!.placement, isNull);
    final broken = codec.toJson(player)..['placement'] = {'kind': 'fame'};
    expect(codec.fromJson(broken), isNull);
  });

  test('saves from before the world existed get a stable seed', () {
    final json =
        jsonDecode(jsonEncode(codec.toJson(_player(8)))) as Map<String, Object?>
          ..remove('world');
    final first = codec.fromJson(json)!.worldSeed;
    expect(codec.fromJson(json)!.worldSeed, first);
    expect(first, greaterThanOrEqualTo(0));
  });

  test('saves from before positions existed use the best fit', () {
    final player = _player(6);
    final json =
        jsonDecode(jsonEncode(codec.toJson(player))) as Map<String, Object?>
          ..remove('position');
    expect(
      codec.fromJson(json)!.preferredPosition,
      Position.ranked(player.attributes).first.$1,
    );
    json['position'] = 'goalkeeper';
    expect(codec.fromJson(json), isNull);
  });

  test('saves from before names existed load as "Player"', () {
    final json =
        jsonDecode(jsonEncode(codec.toJson(_player(4)))) as Map<String, Object?>
          ..remove('identity');
    final loaded = codec.fromJson(json)!;
    expect(loaded.identity.name, PlayerIdentity.unnamed.name);
    expect(loaded.identity.foot, Foot.right);
  });

  group('rejects saves that no longer fit the game', () {
    late Map<String, Object?> json;
    setUp(() => json = jsonDecode(jsonEncode(codec.toJson(_player(1)))));

    test('valid baseline', () => expect(codec.fromJson(json), isNotNull));

    test('not a map', () {
      expect(codec.fromJson(null), isNull);
      expect(codec.fromJson('oops'), isNull);
    });

    test('other version', () {
      json['version'] = PlayerCodec.version + 1;
      expect(codec.fromJson(json), isNull);
    });

    test('missing stat', () {
      (json['attributes']! as Map).remove('pace');
      expect(codec.fromJson(json), isNull);
    });

    test('broken identity', () {
      (json['identity']! as Map)['foot'] = 'middle';
      expect(codec.fromJson(json), isNull);
      (json['identity']! as Map)
        ..['foot'] = 'left'
        ..['name'] = '!';
      expect(codec.fromJson(json), isNull);
    });

    test('unknown country', () {
      json['location'] = 'atlantis';
      expect(codec.fromJson(json), isNull);
    });

    test('unknown or wrong-archetype talent', () {
      json['innate'] = 'meta_vision'; // a logic talent
      expect(codec.fromJson(json), isNull);
      json['innate'] = null;
      json['logic'] = ['not_a_talent'];
      expect(codec.fromJson(json), isNull);
    });

    test('too many or duplicate logic talents', () {
      json['innate'] = null;
      // Three are allowed (earned from talent score 70); four never.
      json['logic'] = ['meta_vision', 'the_ghost', 'the_scalpel'];
      expect(codec.fromJson(json), isNotNull);
      json['logic'] = ['meta_vision', 'the_ghost', 'the_scalpel', 'the_impact'];
      expect(codec.fromJson(json), isNull);
      json['logic'] = ['meta_vision', 'meta_vision'];
      expect(codec.fromJson(json), isNull);
    });
  });
}
