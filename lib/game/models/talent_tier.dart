import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player_attributes.dart';

/// How gifted a player is, from their stats. See docs/career-design.md §3.
enum TalentTier {
  poor(
    'Poor',
    'Raw. Open trials at small clubs, and a long road ahead.',
    '"The talent is hiding somewhere. Hunger might find it."',
  ),
  average(
    'Average',
    'Decent foundations. You will have to earn your chance at trials.',
    '"Works hard, good engine. Needs a coach who will be patient."',
  ),
  rare(
    'Rare talent',
    'Clearly special. Several clubs will come calling.',
    '"Special. Get this one in front of an academy now."',
  ),
  genius(
    'Genius',
    'Generational. Clubs at home and abroad will fight over you.',
    '"I have watched football for thirty years. I have not seen this."',
  );

  const TalentTier(this.label, this.summary, this.scoutNote);

  final String label;
  final String summary;
  final String scoutNote;

  /// Lowest talent score for [average], [rare] and [genius].
  static const int averageFrom = 50;
  static const int rareFrom = 59;
  static const int geniusFrom = 64;

  /// Added to the score when the player has an Innate talent.
  static const int innateBonus = 3;

  /// Average of the six skills, plus [innateBonus] with an Innate talent.
  static double score(PlayerAttributes stats, {required bool hasInnate}) {
    final skills = Attribute.values.where((a) => a.isSkill);
    final average =
        skills.fold<int>(0, (sum, a) => sum + stats[a]) / skills.length;
    return average + (hasInnate ? innateBonus : 0);
  }

  static TalentTier of(double score) => score >= geniusFrom
      ? genius
      : score >= rareFrom
      ? rare
      : score >= averageFrom
      ? average
      : poor;
}
