import 'dart:math';

import 'package:baller/game/career/growth.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/player_attributes.dart';

/// Plays the player's moves when they simulate a match instead of picking
/// them. PROVISIONAL: a move is as likely as the square of the skill it
/// uses, so a quick winger mostly runs and a playmaker mostly passes.
MatchAction autoMove(MatchSim sim, PlayerAttributes attributes, Random rng) {
  final options = sim.pad.values.toSet().toList();
  final weights = [
    for (final a in options) pow(attributes[statTrainedBy(a, sim.state)], 2),
  ];
  final total = weights.fold<num>(0, (s, w) => s + w);
  var roll = rng.nextDouble() * total;
  for (final (i, w) in weights.indexed) {
    if (roll < w) return options[i];
    roll -= w;
  }
  return options.last;
}
