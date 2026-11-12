import 'dart:math';

import 'package:baller/game/world/world_models.dart';

/// Who gets credit for goals the engine doesn't pin on anyone: in
/// simulated league games, and for some goals in the player's own
/// matches. PROVISIONAL weights, to tune.
///
/// A player's chance is their role's weight times how good they are at
/// the skill: strikers score most, creative midfielders and wingers
/// assist most, and better finishers and passers get more of each.

const Map<SquadRole, double> _scoringByRole = {
  SquadRole.gk: 0,
  SquadRole.cb: 1.2,
  SquadRole.fb: 1,
  SquadRole.dm: 1,
  SquadRole.cm: 2.5,
  SquadRole.am: 5,
  SquadRole.w: 6,
  SquadRole.st: 7,
};

const Map<SquadRole, double> _assistingByRole = {
  SquadRole.gk: 0.1,
  SquadRole.cb: 0.6,
  SquadRole.fb: 2.5,
  SquadRole.dm: 1.5,
  SquadRole.cm: 4,
  SquadRole.am: 6,
  SquadRole.w: 6,
  SquadRole.st: 3,
};

/// Share of goals that have an assist.
const double assistRate = 0.7;

double scorerWeight(SquadPlayer p) =>
    _scoringByRole[p.role]! * pow(p.attributes.shot / 60, 1.5);

double assistWeight(SquadPlayer p) =>
    _assistingByRole[p.role]! * pow(p.attributes.pass / 60, 1.5);

/// One of [pool], each as likely as its [weight]. Null if [pool] is empty
/// or nobody has any weight.
T? weightedPick<T>(List<T> pool, double Function(T) weight, Random rng) {
  final weights = [for (final p in pool) max(0.0, weight(p))];
  final total = weights.fold(0.0, (s, w) => s + w);
  if (total <= 0) return null;
  var roll = rng.nextDouble() * total;
  for (final (i, w) in weights.indexed) {
    if (roll < w) return pool[i];
    roll -= w;
  }
  return pool.last;
}
