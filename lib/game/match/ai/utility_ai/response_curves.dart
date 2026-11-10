import 'dart:math';

/// Curve types for normalizing Utility AI considerations.
enum CurveType {
  /// Proportional 1:1 scoring.
  linear,

  /// Gradual rise, steeper at high values: x^2.
  quadratic,

  /// Highly selective, only massive values spike: x^3.
  /// Ideal for Ego: only extreme ego players make rogue decisions.
  exponential,

  /// S-curve with a soft threshold around 0.5.
  /// Ideal for stamina cliffs and pressure states.
  logistic,

  /// Binary on/off trigger (1.0 if x > 0.5, else 0.0).
  step,
}

/// Applies a response curve to an input value clamped between 0.0 and 1.0.
double applyCurve(double input, CurveType curve) {
  final x = input.clamp(0.0, 1.0);
  return switch (curve) {
    CurveType.linear => x,
    CurveType.quadratic => x * x,
    CurveType.exponential => x * x * x,
    CurveType.logistic => 1.0 / (1.0 + exp(-10.0 * (x - 0.5))),
    CurveType.step => x >= 0.5 ? 1.0 : 0.0,
  };
}
