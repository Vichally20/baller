import 'package:baller/game/models/attribute.dart';

/// One wheel on the stat-rolling screen.
class WheelSpec {
  const WheelSpec(this.attribute, this.segments);

  final Attribute attribute;

  /// Values printed on the wheel; each segment is equally likely.
  final List<int> segments;
}

// PLACEHOLDER skill values — tune once the stat mechanics are decided.
const List<int> _skillSegments = [35, 40, 45, 50, 55, 60, 65, 75];

/// Stat wheels in the order they are spun.
const List<WheelSpec> defaultWheels = [
  WheelSpec(Attribute.age, [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]),
  WheelSpec(Attribute.pace, _skillSegments),
  WheelSpec(Attribute.shot, _skillSegments),
  WheelSpec(Attribute.pass, _skillSegments),
  WheelSpec(Attribute.dribble, _skillSegments),
  WheelSpec(Attribute.defence, _skillSegments),
  WheelSpec(Attribute.physical, _skillSegments),
];
