import 'package:baller/game/models/player_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nameError', () {
    test('accepts real names from many places', () {
      for (final name in [
        'Tunde Bakare',
        'Ada Obi-Nwosu',
        "N'Golo Kanté",
        'J. Smith',
        'Ødegaard',
        'Sóla',
      ]) {
        expect(PlayerIdentity.nameError(name), isNull, reason: name);
      }
    });

    test('rejects too short, too long and odd characters', () {
      expect(PlayerIdentity.nameError(''), isNotNull);
      expect(PlayerIdentity.nameError(' a '), isNotNull);
      expect(PlayerIdentity.nameError('x' * 25), isNotNull);
      expect(PlayerIdentity.nameError('Player 1'), isNotNull);
      expect(PlayerIdentity.nameError('-Ada'), isNotNull);
      expect(PlayerIdentity.nameError('Ada!'), isNotNull);
    });
  });

  test('shirt name: empty is fine, otherwise letters and ≤ 12', () {
    expect(PlayerIdentity.shirtError(''), isNull);
    expect(PlayerIdentity.shirtError('OBI'), isNull);
    expect(PlayerIdentity.shirtError('x' * 13), isNotNull);
    expect(PlayerIdentity.shirtError('No.9'), isNotNull);
  });

  test('suggested shirt is the surname, upper case, max 12', () {
    expect(PlayerIdentity.suggestShirt('Tunde Bakare'), 'BAKARE');
    expect(PlayerIdentity.suggestShirt('  Ada   Obi-Nwosu '), 'OBI-NWOSU');
    expect(PlayerIdentity.suggestShirt('Pelé'), 'PELÉ');
    expect(PlayerIdentity.suggestShirt('A Featherstonehaughs'), 'FEATHERSTONE');
    expect(PlayerIdentity.suggestShirt('J. Smith Jr.'), 'JR');
  });

  test('fromInput tidies spaces and falls back to the suggestion', () {
    final auto = PlayerIdentity.fromInput(
      name: '  Ada   Obi ',
      shirtName: '',
      foot: Foot.left,
    );
    expect(auto.name, 'Ada Obi');
    expect(auto.shirtName, 'OBI');
    expect(auto.foot, Foot.left);

    final custom = PlayerIdentity.fromInput(
      name: 'Ada Obi',
      shirtName: 'ada',
      foot: Foot.right,
    );
    expect(custom.shirtName, 'ADA');
  });
}
