import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_generator.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  final world = generateWorld(2026);

  test('the same seed builds the same world; a new seed a new one', () {
    final again = generateWorld(2026);
    final other = generateWorld(7);
    final names = [for (final c in world.clubs) c.name];
    expect([for (final c in again.clubs) c.name], names);
    expect(
      [for (final c in again.clubs) c.squad.first.rating],
      [for (final c in world.clubs) c.squad.first.rating],
    );
    // Clubs are real, so a new seed changes the people, not the names.
    expect([for (final c in other.clubs) c.name], names);
    expect([
      for (final c in other.clubs) c.squad.first.name,
    ], isNot([for (final c in world.clubs) c.squad.first.name]));
  });

  test('8 leagues × 3 divisions × 20 clubs, 38-game seasons', () {
    expect(world.leagues.map((l) => l.country), LeagueCountry.values);
    expect(League.matchesPerSeason, 38);
    for (final league in world.leagues) {
      expect(league.divisions, hasLength(3));
      for (final division in league.divisions) {
        expect(division, hasLength(20));
      }
    }
    expect(world.clubs, hasLength(8 * 3 * 20));
  });

  test('club names are unique in every league', () {
    for (final league in world.leagues) {
      final names = [for (final d in league.divisions) ...d.map((c) => c.name)];
      expect(
        names.toSet(),
        hasLength(names.length),
        reason: league.country.label,
      );
    }
  });

  test('stars and academies follow the division', () {
    for (final league in world.leagues) {
      for (final (d, division) in league.divisions.indexed) {
        final stars = division.map((c) => c.stars).toSet();
        expect(stars, {5 - d, 4 - d, 3 - d}, reason: 'Division ${d + 1}');
        final academies = division.where((c) => c.hasAcademy).length;
        expect(academies, d == 0 ? academyClubs : 0);
      }
    }
  });

  test('squads: 22 players, 2 goalkeepers, stronger clubs rate higher', () {
    for (final club in world.clubs) {
      expect(club.squad, hasLength(Club.maxSquadSize));
      expect(club.squad.where((p) => p.role == SquadRole.gk), hasLength(2));
      for (final p in club.squad) {
        expect(p.rating, inInclusiveRange(40, 99));
        expect(p.age, inInclusiveRange(17, 34));
        expect(p.value, greaterThan(0));
        expect(p.id, startsWith(club.id));
        expect(p.attributes.pace, inInclusiveRange(15, 99));
        expect(p.attributes.shot, inInclusiveRange(15, 99));
        expect(p.attributes.pass, inInclusiveRange(15, 99));
        expect(p.attributes.dribble, inInclusiveRange(15, 99));
        expect(p.attributes.defence, inInclusiveRange(15, 99));
        expect(p.attributes.physical, inInclusiveRange(15, 99));
        expect(p.attributes.ego, inInclusiveRange(10, 99));
        expect(p.attributes.tacticalDiscipline, inInclusiveRange(10, 99));
        expect(p.attributes.teamwork, inInclusiveRange(10, 99));
        expect(p.attributes.composure, inInclusiveRange(20, 99));
        expect(p.attributes.stamina, inInclusiveRange(30, 99));
        expect(p.wage, greaterThan(0));
        expect(p.contractYears, inInclusiveRange(1, 4));
        expect(p.squadNumber, inInclusiveRange(1, 22));
      }
    }
    double avg(int stars) {
      final clubs = world.clubs.where((c) => c.stars == stars).toList();
      return clubs.fold(0.0, (s, c) => s + c.averageRating) / clubs.length;
    }

    for (var s = 1; s < 5; s++) {
      expect(avg(s + 1), greaterThan(avg(s)));
    }
  });

  test('division boosts: value and rating, double for special players', () {
    for (final league in world.leagues) {
      for (final (d, division) in league.divisions.indexed) {
        final country = league.country;
        for (final club in division) {
          for (final p in club.squad) {
            expect(
              p.value,
              greaterThanOrEqualTo(
                divisionValueBonus(d, country, special: p.innateTalent != null),
              ),
              reason: '${club.name} ${p.name}',
            );
          }
          // Each club's best outfield player is special too.
          final best = club.squad
              .where((p) => p.role != SquadRole.gk)
              .reduce((a, b) => b.rating > a.rating ? b : a);
          expect(
            best.value,
            greaterThanOrEqualTo(divisionValueBonus(d, country, special: true)),
          );
        }
      }
    }
    // Division 1 averages well above before the boost (about 68 and €1.5m).
    final top = world.leagues.first.divisions.first.expand((c) => c.squad);
    final avg = top.fold(0, (s, p) => s + p.rating) / top.length;
    expect(avg, greaterThan(71));
  });

  test(
    'the bonus follows the league: top five above the base, others below',
    () {
      for (final c in LeagueCountry.values) {
        final bonus = divisionValueBonus(0, c);
        final topFive = {
          LeagueCountry.england,
          LeagueCountry.spain,
          LeagueCountry.germany,
          LeagueCountry.italy,
          LeagueCountry.france,
        }.contains(c);
        expect(
          topFive ? bonus > 15000000 : bonus < 15000000,
          isTrue,
          reason: '${c.label}: $bonus',
        );
      }
      expect(divisionValueBonus(0, LeagueCountry.england), 24000000);
      expect(
        divisionValueBonus(0, LeagueCountry.england, special: true),
        48000000,
      );
    },
  );

  test('a signed player gets the division boost in their value', () {
    final player = testPlayer(3);
    final club = world.leagues.first.divisions.first.first; // England D1
    final signed = playerMarketValue(player, club: club);
    expect(signed, greaterThan(playerMarketValue(player)));
    expect(
      signed,
      greaterThanOrEqualTo(
        divisionValueBonus(
          0,
          LeagueCountry.england,
          special: player.innateTalent != null,
        ),
      ),
    );
  });

  test('managers match their philosophy', () {
    for (final club in world.clubs) {
      final m = club.manager;
      final (low, high) = m.philosophy.youthTrust;
      expect(m.youthTrust, inInclusiveRange(low, high));
      expect(m.philosophy.formations, contains(m.formation));
      expect(m.philosophy.styles, contains(club.style));
      expect(m.age, inInclusiveRange(35, 68));
    }
    // Every philosophy appears.
    expect(
      world.clubs.map((c) => c.manager.philosophy).toSet(),
      Philosophy.values.toSet(),
    );
  });

  group('values', () {
    test('formula', () {
      expect(
        marketValue(
          rating: 50,
          age: 25,
          leagueMultiplier: 1,
          divisionMultiplier: 1,
        ),
        50000,
      );
      // England Div 1, 80-rated 25-year-old ≈ €3.3m × 1.6.
      expect(
        marketValue(
          rating: 80,
          age: 25,
          leagueMultiplier: 1.6,
          divisionMultiplier: 1,
        ),
        closeTo(5300000, 50000),
      );
    });

    test('formatting', () {
      expect(formatEuros(450000), '€450k');
      expect(formatEuros(12345678), '€12.3m');
      expect(formatEuros(180000000), '€180m');
    });

    test('England\'s Big money perk adds 25%', () {
      final england = startingLocations.firstWhere((l) => l.id == 'england');
      final player = testPlayer(3, location: england);
      final plain = marketValue(
        rating: Position.ranked(player.attributes).first.$2,
        age: player.attributes.age,
        tierMultiplier: tierMultiplier(player.tier),
        leagueMultiplier: LeagueCountry.england.valueMultiplier,
        divisionMultiplier: 0.2,
      );
      expect(playerMarketValue(player), (plain * 1.25).round());
    });

    test('Nigeria and Ghana, with no leagues, value players at 0.5', () {
      final ghana = startingLocations.firstWhere((l) => l.id == 'ghana');
      expect(homeLeagueMultiplier(ghana), 0.5);
    });

    test('SquadPlayer round-trips to and from JSON', () {
      final player = world.clubs.first.squad.first;
      final json = player.toJson();
      final loaded = SquadPlayer.fromJson(json);
      expect(loaded, isNotNull);
      expect(loaded!.id, player.id);
      expect(loaded.name, player.name);
      expect(loaded.rating, player.rating);
      expect(loaded.attributes.pace, player.attributes.pace);
      expect(loaded.attributes.ego, player.attributes.ego);
      expect(
        loaded.attributes.tacticalDiscipline,
        player.attributes.tacticalDiscipline,
      );
      expect(loaded.wage, player.wage);
      expect(loaded.contractYears, player.contractYears);
    });
  });
}
