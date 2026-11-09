import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player_attributes.dart';

/// Outfield positions (no goalkeepers for the player).
enum Position {
  cb('CB', 'Centre-back', 'Wins headers, wins tackles, organises everyone.', {
    Attribute.pace: .10,
    Attribute.pass: .15,
    Attribute.defence: .40,
    Attribute.physical: .35,
  }),
  fb(
    'FB',
    'Full-back',
    'Defends the flank, then overlaps to join the attack.',
    {
      Attribute.pace: .30,
      Attribute.pass: .15,
      Attribute.dribble: .10,
      Attribute.defence: .30,
      Attribute.physical: .15,
    },
  ),
  dm(
    'DM',
    'Defensive midfielder',
    'Shields the back four and starts every attack.',
    {
      Attribute.pace: .10,
      Attribute.shot: .05,
      Attribute.pass: .25,
      Attribute.dribble: .05,
      Attribute.defence: .30,
      Attribute.physical: .25,
    },
  ),
  cm(
    'CM',
    'Central midfielder',
    'Box to box. Does a bit of everything, all game.',
    {
      Attribute.pace: .15,
      Attribute.shot: .10,
      Attribute.pass: .30,
      Attribute.dribble: .15,
      Attribute.defence: .15,
      Attribute.physical: .15,
    },
  ),
  am(
    'AM',
    'Attacking midfielder',
    'The last pass and the late run, between the lines.',
    {
      Attribute.pace: .10,
      Attribute.shot: .20,
      Attribute.pass: .30,
      Attribute.dribble: .25,
      Attribute.defence: .05,
      Attribute.physical: .10,
    },
  ),
  w('W', 'Winger', 'Beats players one-on-one and creates from wide.', {
    Attribute.pace: .30,
    Attribute.shot: .15,
    Attribute.pass: .15,
    Attribute.dribble: .30,
    Attribute.defence: .05,
    Attribute.physical: .05,
  }),
  st('ST', 'Striker', 'Lives in the box. Judged on goals, nothing else.', {
    Attribute.pace: .15,
    Attribute.shot: .35,
    Attribute.pass: .10,
    Attribute.dribble: .15,
    Attribute.defence: .05,
    Attribute.physical: .20,
  });

  const Position(this.code, this.label, this.blurb, this.weights);

  final String code;
  final String label;
  final String blurb;

  /// How much each skill counts toward this position's rating (sums to 1).
  final Map<Attribute, double> weights;

  /// The skills that matter most here, heaviest first.
  List<Attribute> get keyStats {
    final sorted = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(2)) e.key];
  }

  /// Rating at this position, 0–100.
  int rating(PlayerAttributes stats) {
    var total = 0.0;
    weights.forEach((attribute, weight) => total += stats[attribute] * weight);
    return total.round();
  }

  /// Every position, best rating first (ties keep enum order).
  static List<(Position, int)> ranked(PlayerAttributes stats) =>
      [for (final p in values) (p, p.rating(stats))]
        ..sort((a, b) => b.$2.compareTo(a.$2));
}
