import 'package:baller/game/world/world_models.dart';

/// Mutable tactical parameters modified in real-time by the coach's Behavior Tree.
class TacticalState {
  TacticalState({
    required this.tacticName,
    required this.tempo,
    this.attackIntensity = 0.5,
    this.passMultiplier = 1.0,
    this.shootMultiplier = 1.0,
    this.dribbleMultiplier = 1.0,
    this.pressMultiplier = 1.0,
    this.lastAdjustmentMinute = 0,
    this.lastAdjustmentReason,
  });

  /// Name of the active tactical instruction (e.g., "Possession", "All-Out Chaos").
  String tacticName;

  /// Tactical pacing: "Slow", "Normal", "Fast".
  String tempo;

  /// 0.0 (park the bus) to 1.0 (all-out attack).
  double attackIntensity;

  /// Multiplier applied to passing action evaluations in Utility AI.
  double passMultiplier;

  /// Multiplier applied to shooting action evaluations in Utility AI.
  double shootMultiplier;

  /// Multiplier applied to dribbling / 1-on-1 actions.
  double dribbleMultiplier;

  /// Multiplier applied to defensive pressing actions.
  double pressMultiplier;

  /// Last in-game minute when a tactical change was triggered.
  int lastAdjustmentMinute;

  /// Human-readable explanation of why this tactic was chosen (for commentary/analysis).
  String? lastAdjustmentReason;

  /// Initializes default tactical parameters from a club's style.
  factory TacticalState.fromStyle(ClubStyle style) => switch (style) {
    ClubStyle.possession => TacticalState(
      tacticName: 'Control & Possession',
      tempo: 'Normal',
      attackIntensity: 0.55,
      passMultiplier: 1.4,
      shootMultiplier: 0.8,
      dribbleMultiplier: 1.0,
      pressMultiplier: 1.0,
    ),
    ClubStyle.highPress => TacticalState(
      tacticName: 'Heavy Pressing',
      tempo: 'Fast',
      attackIntensity: 0.7,
      passMultiplier: 1.0,
      shootMultiplier: 1.1,
      dribbleMultiplier: 1.1,
      pressMultiplier: 1.6,
    ),
    ClubStyle.counterAttack => TacticalState(
      tacticName: 'Counter-Attack',
      tempo: 'Fast',
      attackIntensity: 0.6,
      passMultiplier: 1.1,
      shootMultiplier: 1.3,
      dribbleMultiplier: 1.3,
      pressMultiplier: 0.8,
    ),
    ClubStyle.direct => TacticalState(
      tacticName: 'Direct Route',
      tempo: 'Fast',
      attackIntensity: 0.65,
      passMultiplier: 0.9,
      shootMultiplier: 1.3,
      dribbleMultiplier: 1.0,
      pressMultiplier: 1.1,
    ),
    ClubStyle.lowBlock => TacticalState(
      tacticName: 'Low Block',
      tempo: 'Slow',
      attackIntensity: 0.3,
      passMultiplier: 1.0,
      shootMultiplier: 0.7,
      dribbleMultiplier: 0.8,
      pressMultiplier: 0.6,
    ),
  };

  /// Switches into late-game desperation / aggressive mode.
  void setDesperationMode(int minute, {String reason = 'Desperation Mode'}) {
    tacticName = 'All-Out Chaos';
    tempo = 'Fast';
    attackIntensity = 0.95;
    passMultiplier = 0.7;
    shootMultiplier = 2.0;
    dribbleMultiplier = 1.4;
    pressMultiplier = 1.5;
    lastAdjustmentMinute = minute;
    lastAdjustmentReason = reason;
  }

  /// Switches into defensive lead protection mode.
  void setProtectLeadMode(int minute, {String reason = 'Protect Lead'}) {
    tacticName = 'Defensive Shell';
    tempo = 'Slow';
    attackIntensity = 0.25;
    passMultiplier = 1.3;
    shootMultiplier = 0.6;
    dribbleMultiplier = 0.7;
    pressMultiplier = 0.7;
    lastAdjustmentMinute = minute;
    lastAdjustmentReason = reason;
  }

  /// Switches into possession recovery mode.
  void setControlMode(int minute, {String reason = 'Reclaim Possession'}) {
    tacticName = 'Control';
    tempo = 'Normal';
    attackIntensity = 0.5;
    passMultiplier = 1.6;
    shootMultiplier = 0.7;
    dribbleMultiplier = 0.9;
    pressMultiplier = 1.2;
    lastAdjustmentMinute = minute;
    lastAdjustmentReason = reason;
  }
}
