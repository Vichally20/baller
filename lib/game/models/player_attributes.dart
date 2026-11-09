import 'package:baller/game/models/attribute.dart';

/// A player's core attributes. Immutable — produce a new copy to change it.
class PlayerAttributes {
  const PlayerAttributes({
    required this.age,
    required this.pace,
    required this.shot,
    required this.pass,
    required this.dribble,
    required this.defence,
    required this.physical,
    this.ego = 50,
    this.tacticalDiscipline = 50,
    this.teamwork = 50,
    this.composure = 50,
    this.stamina = 70,
  });

  /// Builds attributes from a full set of wheel rolls.
  factory PlayerAttributes.fromRolls(
    Map<Attribute, int> rolls, {
    int ego = 50,
    int tacticalDiscipline = 50,
    int teamwork = 50,
    int composure = 50,
    int stamina = 70,
  }) {
    int read(Attribute a) {
      final value = rolls[a];
      if (value == null) throw ArgumentError('Missing roll for ${a.label}');
      return value;
    }

    return PlayerAttributes(
      age: read(Attribute.age),
      pace: read(Attribute.pace),
      shot: read(Attribute.shot),
      pass: read(Attribute.pass),
      dribble: read(Attribute.dribble),
      defence: read(Attribute.defence),
      physical: read(Attribute.physical),
      ego: ego,
      tacticalDiscipline: tacticalDiscipline,
      teamwork: teamwork,
      composure: composure,
      stamina: stamina,
    );
  }

  final int age;
  final int pace;
  final int shot;
  final int pass;
  final int dribble;
  final int defence;
  final int physical;

  /// Mental / Blue Lock personality attributes (1–99).
  ///
  /// High ego players demand the ball and take selfish shots.
  final int ego;

  /// High tactical discipline players strictly obey coach tactical instructions.
  final int tacticalDiscipline;

  /// High teamwork players prioritize passes and linking up with teammates.
  final int teamwork;

  /// High composure players perform reliably under pressure (e.g. late goals).
  final int composure;

  /// Player energy capacity before performance decays.
  final int stamina;

  PlayerAttributes copyWith({
    int? age,
    int? pace,
    int? shot,
    int? pass,
    int? dribble,
    int? defence,
    int? physical,
    int? ego,
    int? tacticalDiscipline,
    int? teamwork,
    int? composure,
    int? stamina,
  }) => PlayerAttributes(
    age: age ?? this.age,
    pace: pace ?? this.pace,
    shot: shot ?? this.shot,
    pass: pass ?? this.pass,
    dribble: dribble ?? this.dribble,
    defence: defence ?? this.defence,
    physical: physical ?? this.physical,
    ego: ego ?? this.ego,
    tacticalDiscipline: tacticalDiscipline ?? this.tacticalDiscipline,
    teamwork: teamwork ?? this.teamwork,
    composure: composure ?? this.composure,
    stamina: stamina ?? this.stamina,
  );

  int operator [](Attribute attribute) => switch (attribute) {
    Attribute.age => age,
    Attribute.pace => pace,
    Attribute.shot => shot,
    Attribute.pass => pass,
    Attribute.dribble => dribble,
    Attribute.defence => defence,
    Attribute.physical => physical,
  };
}
