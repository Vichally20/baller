/// The numeric attributes rolled on the stat wheels at the start of a career.
enum Attribute {
  age('Age'),
  pace('Pace'),
  shot('Shot'),
  pass('Pass'),
  dribble('Dribble'),
  defence('Defence'),
  physical('Physical');

  const Attribute(this.label);

  final String label;

  /// Everything except age is a 0–100 skill rating.
  bool get isSkill => this != Attribute.age;
}
