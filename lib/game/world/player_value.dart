import 'dart:math';

import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

/// Market value in euros. See docs/career-design.md §8:
/// €50k × 1.15^(rating − 50) × age × tier × league × division.
int marketValue({
  required int rating,
  required int age,
  double tierMultiplier = 1,
  required double leagueMultiplier,
  required double divisionMultiplier,
}) {
  final raw =
      50000 *
      pow(1.15, rating - 50) *
      ageMultiplier(age) *
      tierMultiplier *
      leagueMultiplier *
      divisionMultiplier;
  return (raw / 1000).round() * 1000;
}

double ageMultiplier(int age) => age <= 19
    ? 1.5
    : age <= 23
    ? 1.2
    : age <= 27
    ? 1.0
    : age <= 30
    ? 0.8
    : 0.5;

double tierMultiplier(TalentTier tier) => switch (tier) {
  TalentTier.genius => 3,
  TalentTier.rare => 1.8,
  TalentTier.average => 1,
  TalentTier.poor => 0.6,
};

const divisionMultipliers = [1.0, 0.45, 0.2];

/// Added to every club player's (value, rating), by division index.
/// "Special" players get double: anyone with an Innate talent, and (for
/// generated squads) each club's best outfield player.
const List<(int, int)> divisionBoosts = [
  (15000000, 5),
  (5000000, 3),
  (1000000, 1),
];

/// The value part of the division boost, scaled by the league's money:
/// the top five leagues (England ×1.6, Spain ×1.3, Germany and Italy ×1.2,
/// France ×1.1) get more than the base, the rest (×0.6–0.7) less.
int divisionValueBonus(
  int divisionIndex,
  LeagueCountry country, {
  bool special = false,
}) =>
    (divisionBoosts[divisionIndex].$1 *
            country.valueMultiplier *
            (special ? 2 : 1))
        .round();

/// Value of a player with no club yet: as if in their home country's lowest
/// division (Nigeria and Ghana, which have no leagues, count as 0.5).
const double _unattachedMultiplier = 0.2;

double homeLeagueMultiplier(Location location) {
  for (final league in LeagueCountry.values) {
    if (league.label == location.country) return league.valueMultiplier;
  }
  return 0.5;
}

/// The player's value. Before signing: as an unattached player at home.
/// Signed to [club]: valued in its league and division, with the same
/// division boost as its players (double with an Innate talent).
int playerMarketValue(Player player, {Club? club}) {
  final best = Position.ranked(player.attributes).first.$2;
  final value = club == null
      ? marketValue(
          rating: best,
          age: player.attributes.age,
          tierMultiplier: tierMultiplier(player.tier),
          leagueMultiplier: homeLeagueMultiplier(player.location),
          divisionMultiplier: _unattachedMultiplier,
        )
      : marketValue(
              rating: best,
              age: player.attributes.age,
              tierMultiplier: tierMultiplier(player.tier),
              leagueMultiplier: club.country.valueMultiplier,
              divisionMultiplier: divisionMultipliers[club.division - 1],
            ) +
            divisionValueBonus(
              club.division - 1,
              club.country,
              special: player.innateTalent != null,
            );
  return player.location.perk == CountryPerk.bigMoney
      ? (value * 1.25).round()
      : value;
}

/// "€450k", "€12.3m", "€180m".
String formatEuros(int euros) {
  if (euros >= 100000000) return '€${(euros / 1e6).round()}m';
  if (euros >= 1000000) return '€${(euros / 1e6).toStringAsFixed(1)}m';
  return '€${(euros / 1000).round()}k';
}
