import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/real_clubs.dart';
import 'package:baller/game/world/world_generator.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every country has 3 named divisions of 20 different real clubs', () {
    for (final country in LeagueCountry.values) {
      expect(divisionNames(country), hasLength(League.divisionCount));
      final names = realClubNames(country).toList();
      expect(names, hasLength(League.divisionCount * League.clubsPerDivision));
      expect(names.toSet(), hasLength(names.length), reason: country.label);
    }
  });

  test('the world uses the real names, strongest club first', () {
    final world = generateWorld(2026);
    final england = world.leagues.firstWhere(
      (l) => l.country == LeagueCountry.england,
    );
    expect(england.divisions[0].first.name, 'Liverpool');
    expect(england.divisions[0].first.stars, 5);
    expect(england.divisions[0].first.hasAcademy, isTrue);
    expect(League.nameOf(LeagueCountry.england, 2), 'Championship');
    for (final league in world.leagues) {
      for (final (d, clubs) in league.divisions.indexed) {
        for (final (rank, club) in clubs.indexed) {
          expect(club.name, realClub(league.country, d, rank).$1);
        }
      }
    }
  });
}
