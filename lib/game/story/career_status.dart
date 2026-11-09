import 'package:baller/game/story/story_content.dart';

/// Everything a career's story changes: money, morale, relationships,
/// items, and how far through the story the player is.
class CareerStatus {
  const CareerStatus({
    required this.money,
    required this.morale,
    required this.coach,
    required this.teammates,
    this.items = const [],
    this.eventIndex = 0,
  });

  /// Where every new career starts.
  static const initial = CareerStatus(
    money: 100,
    morale: 50,
    coach: 50,
    teammates: 50,
  );

  /// Morale and relationships run 0–100.
  static const int meterMax = 100;

  final int money;
  final int morale;
  final int coach;
  final int teammates;

  /// Item ids from items.json, in the order they were gained.
  final List<String> items;

  /// Position in the story schedule (scenarios and matches).
  final int eventIndex;

  /// Applies an outcome's effects. Meters clamp to 0–100 and money never
  /// goes below 0.
  CareerStatus apply(Effects effects) {
    final items = [...this.items, ...effects.addItems];
    for (final id in effects.removeItems) {
      items.remove(id);
    }
    return CareerStatus(
      money: (money + effects.money).clamp(0, 1 << 31),
      morale: (morale + effects.morale).clamp(0, meterMax),
      coach: (coach + effects.coach).clamp(0, meterMax),
      teammates: (teammates + effects.teammates).clamp(0, meterMax),
      items: List.unmodifiable(items),
      eventIndex: eventIndex,
    );
  }

  CareerStatus advance() => CareerStatus(
    money: money,
    morale: morale,
    coach: coach,
    teammates: teammates,
    items: items,
    eventIndex: eventIndex + 1,
  );

  /// Back to the first event, keeping everything else. Used when a career
  /// from before pathways picks one and its story starts over.
  CareerStatus restart() => CareerStatus(
    money: money,
    morale: morale,
    coach: coach,
    teammates: teammates,
    items: items,
  );

  Map<String, Object?> toJson() => {
    'money': money,
    'morale': morale,
    'coach': coach,
    'teammates': teammates,
    'items': items,
    'event': eventIndex,
  };

  /// Null when [json] is malformed.
  static CareerStatus? fromJson(Object? json) {
    if (json
        case {
          'money': final int money,
          'morale': final int morale,
          'coach': final int coach,
          'teammates': final int teammates,
          'items': final List<Object?> items,
          'event': final int event,
        }
        when money >= 0 && event >= 0 && items.every((i) => i is String)) {
      bool meter(int v) => v >= 0 && v <= meterMax;
      if (!meter(morale) || !meter(coach) || !meter(teammates)) return null;
      return CareerStatus(
        money: money,
        morale: morale,
        coach: coach,
        teammates: teammates,
        items: List.unmodifiable(items.cast<String>()),
        eventIndex: event,
      );
    }
    return null;
  }
}
