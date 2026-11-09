import 'package:baller/game/models/attribute.dart';

enum Region {
  africa('africa'),
  europe('europe'),
  southAmerica('south_america'),
  asia('asia');

  const Region(this.id);

  /// Used in chapter conditions.
  final String id;
}

/// The lasting advantage a starting country gives.
enum CountryPerk {
  scoutsRadar(
    "Scouts' radar",
    'Rare and genius players under 17 get offers from European academies.',
  ),
  mentors(
    'Mentors',
    'Start with +10 coach relationship. European academies watch closely.',
  ),
  bigMoney('Big money', 'Wages and transfer value ×1.25.'),
  technicalSchooling(
    'Technical schooling',
    'Pass and Dribble improve faster in training.',
  ),
  bTeams('B-teams', 'Young players get more minutes.'),
  wideNet('Wide net', 'One extra club scouts you: an extra offer or trial.'),
  flair('Flair', 'Start with +10 morale.'),
  grit('Grit', 'Morale never drops below 20.'),
  professionalism('Professionalism', 'Start with +10 coach and +10 teammates.'),
  tacticalBrain(
    'Tactical brain',
    'Always start with at least one Logic talent.',
  );

  const CountryPerk(this.label, this.description);

  final String label;
  final String description;
}

/// A country the player can start in, with its football identity and bonus.
class Location {
  const Location({
    required this.id,
    required this.city,
    required this.country,
    required this.region,
    required this.identity,
    required this.bonusStat,
    required this.perk,
    required this.blurb,
    this.bonusAmount = 5,
  });

  final String id;
  final String city;
  final String country;
  final Region region;

  /// Short football identity, e.g. "Street football".
  final String identity;

  /// Stat raised by [bonusAmount] on top of the wheel roll.
  final Attribute bonusStat;
  final int bonusAmount;

  final CountryPerk perk;
  final String blurb;

  String get displayName => '$city, $country';

  String get bonusLabel => '+$bonusAmount ${bonusStat.label}';
}
