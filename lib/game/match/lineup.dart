import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/world_models.dart';

/// A place in a formation. [x] runs 0 (left) to 1 (right) as the team
/// attacks; [depth] runs 0 (goalkeeper) to 1 (the most advanced striker).
class FormationSlot {
  const FormationSlot(this.role, this.x, this.depth);

  final SquadRole role;
  final double x;
  final double depth;
}

/// Used when a side has no manager (the engine's stand-in squads).
const String defaultFormation = '4-2-3-1';

const _gk = FormationSlot(SquadRole.gk, 0.5, 0);
const _backFour = [
  FormationSlot(SquadRole.fb, 0.12, 0.25),
  FormationSlot(SquadRole.cb, 0.37, 0.22),
  FormationSlot(SquadRole.cb, 0.63, 0.22),
  FormationSlot(SquadRole.fb, 0.88, 0.25),
];

/// Slot layouts for every formation a manager can use.
const Map<String, List<FormationSlot>> formations = {
  '4-2-3-1': [
    _gk,
    ..._backFour,
    FormationSlot(SquadRole.dm, 0.33, 0.47),
    FormationSlot(SquadRole.dm, 0.67, 0.47),
    FormationSlot(SquadRole.w, 0.13, 0.73),
    FormationSlot(SquadRole.am, 0.5, 0.7),
    FormationSlot(SquadRole.w, 0.87, 0.73),
    FormationSlot(SquadRole.st, 0.5, 0.95),
  ],
  '4-4-2': [
    _gk,
    ..._backFour,
    FormationSlot(SquadRole.w, 0.12, 0.6),
    FormationSlot(SquadRole.cm, 0.37, 0.55),
    FormationSlot(SquadRole.cm, 0.63, 0.55),
    FormationSlot(SquadRole.w, 0.88, 0.6),
    FormationSlot(SquadRole.st, 0.35, 0.93),
    FormationSlot(SquadRole.st, 0.65, 0.93),
  ],
  '4-3-3': [
    _gk,
    ..._backFour,
    FormationSlot(SquadRole.cm, 0.25, 0.6),
    FormationSlot(SquadRole.dm, 0.5, 0.48),
    FormationSlot(SquadRole.cm, 0.75, 0.6),
    FormationSlot(SquadRole.w, 0.14, 0.88),
    FormationSlot(SquadRole.st, 0.5, 0.95),
    FormationSlot(SquadRole.w, 0.86, 0.88),
  ],
  '4-5-1': [
    _gk,
    ..._backFour,
    FormationSlot(SquadRole.w, 0.1, 0.66),
    FormationSlot(SquadRole.cm, 0.3, 0.6),
    FormationSlot(SquadRole.dm, 0.5, 0.48),
    FormationSlot(SquadRole.cm, 0.7, 0.6),
    FormationSlot(SquadRole.w, 0.9, 0.66),
    FormationSlot(SquadRole.st, 0.5, 0.95),
  ],
  '3-5-2': [
    _gk,
    FormationSlot(SquadRole.cb, 0.25, 0.23),
    FormationSlot(SquadRole.cb, 0.5, 0.2),
    FormationSlot(SquadRole.cb, 0.75, 0.23),
    FormationSlot(SquadRole.fb, 0.08, 0.56),
    FormationSlot(SquadRole.cm, 0.3, 0.6),
    FormationSlot(SquadRole.dm, 0.5, 0.48),
    FormationSlot(SquadRole.cm, 0.7, 0.6),
    FormationSlot(SquadRole.fb, 0.92, 0.56),
    FormationSlot(SquadRole.st, 0.35, 0.93),
    FormationSlot(SquadRole.st, 0.65, 0.93),
  ],
};

/// Who covers a slot when nobody in the squad plays that role, best first.
const Map<SquadRole, List<SquadRole>> _cover = {
  SquadRole.gk: [],
  SquadRole.cb: [SquadRole.fb, SquadRole.dm],
  SquadRole.fb: [SquadRole.cb, SquadRole.w],
  SquadRole.dm: [SquadRole.cm, SquadRole.cb],
  SquadRole.cm: [SquadRole.dm, SquadRole.am],
  SquadRole.am: [SquadRole.cm, SquadRole.w],
  SquadRole.w: [SquadRole.am, SquadRole.fb, SquadRole.st],
  SquadRole.st: [SquadRole.w, SquadRole.am],
};

/// One player in a formation slot. [player] is null for the user, who
/// isn't a [SquadPlayer].
class LineupSpot {
  const LineupSpot(this.slot, this.player);

  final FormationSlot slot;
  final SquadPlayer? player;

  bool get isUser => player == null;
}

/// A side's starting eleven in its formation.
class Lineup {
  const Lineup({required this.formation, required this.spots});

  final String formation;
  final List<LineupSpot> spots;

  /// Everyone on the pitch except the user.
  List<SquadPlayer> get players => [for (final s in spots) ?s.player];

  LineupSpot? get userSpot => spots.where((s) => s.isUser).firstOrNull;
}

/// Picks the starting eleven for [formation] from [squad]: the best-rated
/// player for each slot's role, then the closest cover. With
/// [userPosition], the user takes the slot for that position (or the
/// closest one) and the player with [userId] is left out of the squad.
Lineup pickLineup(
  List<SquadPlayer> squad,
  String formation, {
  Position? userPosition,
  String? userId,
}) {
  final shape = formations[formation] ?? formations[defaultFormation]!;
  final pool = [
    for (final p in squad)
      if (userId == null || p.id != userId) p,
  ]..sort((a, b) => b.rating.compareTo(a.rating));
  final picked = List<SquadPlayer?>.filled(shape.length, null);
  final used = <SquadPlayer>{};

  var userSlot = -1;
  if (userPosition != null) {
    final role = SquadRole.values.firstWhere((r) => r.position == userPosition);
    userSlot = shape.indexWhere((s) => s.role == role);
    for (final cover in _cover[role]!) {
      if (userSlot >= 0) break;
      userSlot = shape.indexWhere((s) => s.role == cover);
    }
    if (userSlot < 0) {
      userSlot = shape.indexWhere((s) => s.role != SquadRole.gk);
    }
  }

  SquadPlayer? best(bool Function(SquadPlayer) test) {
    for (final p in pool) {
      if (!used.contains(p) && test(p)) return p;
    }
    return null;
  }

  void fill(bool Function(FormationSlot, SquadPlayer) fits) {
    for (var i = 0; i < shape.length; i++) {
      if (i == userSlot || picked[i] != null) continue;
      final p = best((p) => fits(shape[i], p));
      if (p != null) {
        picked[i] = p;
        used.add(p);
      }
    }
  }

  // Exact roles first, then cover, then anyone of the right kind.
  fill((slot, p) => p.role == slot.role);
  for (var level = 0; level < 3; level++) {
    fill((slot, p) {
      final cover = _cover[slot.role]!;
      return level < cover.length && p.role == cover[level];
    });
  }
  fill((slot, p) => (slot.role == SquadRole.gk) == (p.role == SquadRole.gk));
  fill((slot, p) => true);

  return Lineup(
    formation: formations.containsKey(formation) ? formation : defaultFormation,
    spots: [
      for (var i = 0; i < shape.length; i++)
        if (i == userSlot || picked[i] != null) LineupSpot(shape[i], picked[i]),
    ],
  );
}
