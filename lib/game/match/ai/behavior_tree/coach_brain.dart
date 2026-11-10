import 'package:baller/game/match/ai/behavior_tree/coach_snapshot.dart';
import 'package:baller/game/match/ai/behavior_tree/composite.dart';
import 'package:baller/game/match/ai/behavior_tree/leaf.dart';
import 'package:baller/game/match/ai/behavior_tree/node.dart';

/// The tactical decision engine of a coach, constructed as a Behavior Tree.
class CoachBrain {
  CoachBrain({
    required this.coachName,
    this.desperationMinute = 78,
    this.protectLeadMinute = 75,
    this.possessionThreshold = 38.0,
    BTNode<CoachSnapshot>? customRoot,
  }) {
    rootNode = customRoot ?? _buildDefaultTree();
  }

  final String coachName;
  final int desperationMinute;
  final int protectLeadMinute;
  final double possessionThreshold;

  late final BTNode<CoachSnapshot> rootNode;

  /// Evaluates the coach's behavior tree against the current match snapshot.
  NodeStatus evaluate(CoachSnapshot snapshot) => rootNode.tick(snapshot);

  BTNode<CoachSnapshot> _buildDefaultTree() => Selector<CoachSnapshot>([
    // PRIORITY 1: Late-game Desperation (Are we losing late?)
    Sequence<CoachSnapshot>([
      Condition<CoachSnapshot>(
        (s) => s.minute >= desperationMinute,
        label: "Minute >= $desperationMinute",
      ),
      Condition<CoachSnapshot>(
        (s) => s.goalDifference < 0,
        label: 'Team is losing',
      ),
      Condition<CoachSnapshot>(
        (s) => s.tactics.tacticName != 'All-Out Chaos',
        label: 'Not already in All-Out Chaos',
      ),
      BTAction<CoachSnapshot>(
        (s) => s.tactics.setDesperationMode(
          s.minute,
          reason: 'Chasing the game late',
        ),
        label: 'Switch to All-Out Chaos',
      ),
    ]),

    // PRIORITY 2: Protect Lead (Are we holding a narrow lead late?)
    Sequence<CoachSnapshot>([
      Condition<CoachSnapshot>(
        (s) => s.minute >= protectLeadMinute,
        label: "Minute >= $protectLeadMinute",
      ),
      Condition<CoachSnapshot>(
        (s) => s.goalDifference > 0 && s.goalDifference <= 2,
        label: 'Leading narrowly',
      ),
      Condition<CoachSnapshot>(
        (s) => s.tactics.tacticName != 'Defensive Shell',
        label: 'Not already in Defensive Shell',
      ),
      BTAction<CoachSnapshot>(
        (s) => s.tactics.setProtectLeadMode(
          s.minute,
          reason: 'Locking down the lead',
        ),
        label: 'Switch to Defensive Shell',
      ),
    ]),

    // PRIORITY 3: Possession Crisis (Getting starved of the ball?)
    Sequence<CoachSnapshot>([
      Condition<CoachSnapshot>(
        (s) => s.minute >= 25,
        label: 'Past opening 25 minutes',
      ),
      Condition<CoachSnapshot>(
        (s) => s.possessionPercentage < possessionThreshold,
        label: 'Possession < $possessionThreshold%',
      ),
      Condition<CoachSnapshot>(
        (s) => s.tactics.tacticName != 'Control',
        label: 'Not already in Control',
      ),
      BTAction<CoachSnapshot>(
        (s) =>
            s.tactics.setControlMode(s.minute, reason: 'Starved of possession'),
        label: 'Switch to Control tactic',
      ),
    ]),

    // PRIORITY 4: Conceded Recently (Shock response)
    Sequence<CoachSnapshot>([
      Condition<CoachSnapshot>(
        (s) => s.concededRecently,
        label: 'Conceded in last 10 minutes',
      ),
      Condition<CoachSnapshot>(
        (s) => s.goalDifference <= 0,
        label: 'Not winning comfortably',
      ),
      Condition<CoachSnapshot>(
        (s) => s.tactics.tempo == 'Fast',
        label: 'Playing too recklessly fast',
      ),
      BTAction<CoachSnapshot>((s) {
        s.tactics.tempo = 'Normal';
        s.tactics.passMultiplier = 1.3;
        s.tactics.lastAdjustmentMinute = s.minute;
        s.tactics.lastAdjustmentReason = 'Calming the team after conceding';
      }, label: 'Steady the ship'),
    ]),

    // PRIORITY 5: Cruising (Comfortable 3+ lead)
    Sequence<CoachSnapshot>([
      Condition<CoachSnapshot>(
        (s) => s.goalDifference >= 3,
        label: 'Leading by 3+ goals',
      ),
      Condition<CoachSnapshot>(
        (s) => s.tactics.attackIntensity > 0.4,
        label: 'Attacking too aggressively',
      ),
      BTAction<CoachSnapshot>((s) {
        s.tactics.attackIntensity = 0.35;
        s.tactics.tempo = 'Slow';
        s.tactics.lastAdjustmentMinute = s.minute;
        s.tactics.lastAdjustmentReason =
            'Managing energy with comfortable lead';
      }, label: 'Conserve energy'),
    ]),

    // DEFAULT: Keep executing the current tactical plan
    BTAction<CoachSnapshot>((s) {
      // Intentionally do nothing; hold course
    }, label: 'Maintain system'),
  ]);
}
