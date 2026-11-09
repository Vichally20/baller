import 'dart:math';

import 'package:baller/game/match/match_engine.dart';

/// Tracks in-game momentum between Home and Away sides.
class MatchMomentum {
  MatchMomentum({this.home = 0.5});

  /// 0.0 (completely deflated) to 1.0 (on fire). 0.5 is neutral equilibrium.
  double home;

  double get away => (1.0 - home).clamp(0.0, 1.0);

  /// Momentum multiplier applied to stat contests (-10% to +10%).
  double multiplierFor(Side side) {
    final value = side == Side.home ? home : away;
    return 0.90 + (value * 0.20);
  }

  /// Swings momentum after a goal (+20%).
  void onGoal(Side scorer) {
    final swing = scorer == Side.home ? 0.20 : -0.20;
    home = (home + swing).clamp(0.1, 0.9);
  }

  /// Small boost after a clutch save (+10%).
  void onSave(Side keeperSide) {
    final swing = keeperSide == Side.home ? 0.10 : -0.10;
    home = (home + swing).clamp(0.1, 0.9);
  }

  /// Natural decay back toward 0.5 over time.
  void decay() {
    home = (home * 0.95 + 0.5 * 0.05).clamp(0.1, 0.9);
  }
}

