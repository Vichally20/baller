import 'dart:math';

import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/npc_generator.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';

/// Builds every league from one seed: the same seed always gives the same
/// world, so a save only needs to store the seed.
World generateWorld(int seed) {
  final rng = Random(seed);
  return World(
    seed: seed,
    leagues: [
      for (final country in LeagueCountry.values) _league(country, rng),
    ],
  );
}

/// The 22-man squad shape: 2 GK, 4 CB, 4 FB, 2 DM, 3 CM, 2 AM, 3 W, 2 ST.
const _squadShape = [
  (SquadRole.gk, 2),
  (SquadRole.cb, 4),
  (SquadRole.fb, 4),
  (SquadRole.dm, 2),
  (SquadRole.cm, 3),
  (SquadRole.am, 2),
  (SquadRole.w, 3),
  (SquadRole.st, 2),
];

/// Stars by position in the division's strength order.
int starsFor(int divisionIndex, int rank) {
  final top = 5 - divisionIndex;
  return rank < 4
      ? top
      : rank < 13
      ? top - 1
      : top - 2;
}

/// Division 1's strongest clubs run academies.
const int academyClubs = 6;

/// Most clubs in one division sharing a naming pattern (e.g. "… United").
const int maxPatternUses = 3;

League _league(LeagueCountry country, Random rng) {
  final towns = <String>{};
  final names = <String>{};
  final divisions = <List<Club>>[];
  for (var d = 0; d < League.divisionCount; d++) {
    final clubs = <Club>[];
    // How often each naming pattern ("… Wanderers", "Real …") is used in
    // this division, so one doesn't dominate.
    final patterns = <String, int>{};
    for (var rank = 0; rank < League.clubsPerDivision; rank++) {
      String town;
      String name;
      String pattern;
      var attempts = 0;
      do {
        town = country.randomTown(rng);
        name = country.clubName(town, rng);
        pattern = name.replaceFirst(town, '…');
        attempts++;
      } while (towns.contains(town) ||
          names.contains(name) ||
          // Safety valve: never loop forever if a country has too few
          // patterns to stay under the limit.
          ((patterns[pattern] ?? 0) >= maxPatternUses && attempts < 500));
      towns.add(town);
      names.add(name);
      patterns[pattern] = (patterns[pattern] ?? 0) + 1;

      final stars = starsFor(d, rank);
      final manager = _manager(country, rng);
      final clubId = '${country.name}-${d + 1}-$rank';
      clubs.add(
        Club(
          id: clubId,
          name: name,
          town: town,
          country: country,
          division: d + 1,
          stars: stars,
          style: manager
              .philosophy
              .styles[rng.nextInt(manager.philosophy.styles.length)],
          hasAcademy: d == 0 && rank < academyClubs,
          manager: manager,
          squad: _squad(clubId, country, d, stars, rng),
        ),
      );
    }
    divisions.add(List.unmodifiable(clubs));
  }
  return League(country: country, divisions: List.unmodifiable(divisions));
}

/// Mostly local; sometimes from abroad (including Nigeria and Ghana).
Nationality _nationality(LeagueCountry country, Random rng, double local) =>
    rng.nextDouble() < local
    ? country.nationality
    : Nationality.values[rng.nextInt(Nationality.values.length)];

Manager _manager(LeagueCountry country, Random rng) {
  final roll = rng.nextDouble();
  final philosophy = roll < 0.35
      ? Philosophy.traditional
      : roll < 0.70
      ? Philosophy.modernProgressive
      : Philosophy.newHybrid;
  final (low, high) = philosophy.youthTrust;
  final nationality = _nationality(country, rng, 0.8);
  return Manager(
    name: nationality.randomName(rng),
    age: 35 + rng.nextInt(34),
    nationality: nationality,
    philosophy: philosophy,
    formation: philosophy.formations[rng.nextInt(philosophy.formations.length)],
    youthTrust: low + rng.nextInt(high - low + 1),
    temperament: Temperament.values[rng.nextInt(Temperament.values.length)],
  );
}

List<SquadPlayer> _squad(
  String clubId,
  LeagueCountry country,
  int divisionIndex,
  int stars,
  Random rng,
) {
  // 1★ ≈ 52 average rating … 5★ ≈ 76.
  final mean = 46 + stars * 6;
  var playerIndex = 0;
  return [
    for (final (role, count) in _squadShape)
      for (var i = 0; i < count; i++)
        () {
          final pIndex = playerIndex++;
          final age = 17 + rng.nextInt(18);
          // Roughly bell-shaped spread of ±12, younger players a bit lower.
          final spread = rng.nextInt(9) + rng.nextInt(9) + rng.nextInt(9) - 12;
          final rating = (mean + spread - (age < 20 ? 3 : 0)).clamp(40, 92);
          final nationality = _nationality(country, rng, 0.75);
          final name = nationality.randomName(rng);
          final value = marketValue(
            rating: rating,
            age: age,
            leagueMultiplier: country.valueMultiplier,
            divisionMultiplier: divisionMultipliers[divisionIndex],
          );

          final playerRng = Random(rng.nextInt(0x7fffffff));
          final attributes = NpcGenerator.generateAttributes(
            role: role,
            rating: rating,
            age: age,
            rng: playerRng,
          );
          final foot = NpcGenerator.generateFoot(role, playerRng);
          final (innate, logic) = NpcGenerator.generateTalents(rating, playerRng);
          final contractYears = 1 + playerRng.nextInt(4);
          final wage = NpcGenerator.generateWage(value, divisionIndex + 1, playerRng);

          return SquadPlayer(
            id: '$clubId-p$pIndex',
            name: name,
            age: age,
            nationality: nationality,
            role: role,
            rating: rating,
            value: value,
            attributes: attributes,
            foot: foot,
            innateTalent: innate,
            logicTalents: logic,
            contractYears: contractYears,
            wage: wage,
            clubId: clubId,
            squadNumber: pIndex + 1,
          );
        }(),
  ];
}
