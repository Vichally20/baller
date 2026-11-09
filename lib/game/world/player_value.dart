import 'dart:math';

import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/world/league_countries.dart';

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

/// Value of a player with no club yet: as if in their home country's lowest
/// division (Nigeria and Ghana, which have no leagues, count as 0.5).
const double _unattachedMultiplier = 0.2;

double homeLeagueMultiplier(Location location) {
  for (final league in LeagueCountry.values) {
    if (league.label == location.country) return league.valueMultiplier;
  }
  return 0.5;
}

int playerMarketValue(Player player) {
  final best = Position.ranked(player.attributes).first.$2;
  final value = marketValue(
    rating: best,
    age: player.attributes.age,
    tierMultiplier: tierMultiplier(player.tier),
    leagueMultiplier: homeLeagueMultiplier(player.location),
    divisionMultiplier: _unattachedMultiplier,
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
