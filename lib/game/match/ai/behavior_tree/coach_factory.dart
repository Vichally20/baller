import 'package:baller/game/match/ai/behavior_tree/coach_brain.dart';
import 'package:baller/game/world/world_models.dart';

/// Creates specialized [CoachBrain] behavior trees based on manager philosophy and temperament.
class CoachFactory {
  const CoachFactory._();

  /// Constructs a [CoachBrain] tailored to a manager's personal attributes.
  static CoachBrain createForManager(Manager manager) {
    // 1. Desperation threshold: when does this coach panic?
    // Modern Progressive and Volatile managers panic earlier (e.g. min 72-75).
    // Traditional and Calm managers hold their nerve until late (e.g. min 82-85).
    final int desperationMinute = switch (manager.philosophy) {
      Philosophy.modernProgressive => switch (manager.temperament) {
        Temperament.volatile => 70,
        Temperament.demanding => 74,
        Temperament.calm => 78,
      },
      Philosophy.newHybrid => switch (manager.temperament) {
        Temperament.volatile => 73,
        Temperament.demanding => 76,
        Temperament.calm => 80,
      },
      Philosophy.traditional => switch (manager.temperament) {
        Temperament.volatile => 78,
        Temperament.demanding => 82,
        Temperament.calm => 85,
      },
    };

    // 2. Protect lead minute:
    final int protectLeadMinute = switch (manager.philosophy) {
      Philosophy.traditional => 70,
      Philosophy.modernProgressive => 78,
      Philosophy.newHybrid => 75,
    };

    // 3. Possession threshold: when does the coach intervene for lack of ball?
    final double possessionThreshold = switch (manager.philosophy) {
      Philosophy.modernProgressive => 42.0, // Demands the ball
      Philosophy.newHybrid => 38.0,
      Philosophy.traditional => 32.0, // Comfortable without possession
    };

    return CoachBrain(
      coachName: manager.name,
      desperationMinute: desperationMinute,
      protectLeadMinute: protectLeadMinute,
      possessionThreshold: possessionThreshold,
    );
  }
}

