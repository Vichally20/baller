/// The spatial zones of the pitch used for tactical reasoning.
enum PitchZone {
  /// Inside own penalty area (immediate danger when defending; clearances common).
  ownBox,

  /// Defensive half of the pitch (building from back).
  ownHalf,

  /// Center circle and contested midfield area.
  midfield,

  /// Opponent's defensive territory (creating chances).
  attackingThird,

  /// Edge of the penalty box (shooting and key through balls).
  finalThird,

  /// Inside opponent's penalty area (prime scoring zone).
  opponentBox;

  /// Returns true if this zone is in shooting range of the opponent goal.
  bool get isInShootingRange => switch (this) {
    PitchZone.opponentBox || PitchZone.finalThird => true,
    PitchZone.attackingThird => true, // Long shots
    _ => false,
  };

  /// Multiplier for shot viability based on distance to goal.
  double get shotViabilityMultiplier => switch (this) {
    PitchZone.opponentBox => 1.0,
    PitchZone.finalThird => 0.70,
    PitchZone.attackingThird => 0.35,
    PitchZone.midfield => 0.05,
    PitchZone.ownHalf || PitchZone.ownBox => 0.0,
  };

  /// Returns true if clearing the ball is a sensible option.
  bool get isClearanceZone => switch (this) {
    PitchZone.ownBox => true,
    PitchZone.ownHalf => true,
    _ => false,
  };
}
