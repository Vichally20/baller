import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/ai/utility_ai/player_brain.dart';
import 'package:baller/game/match/ai/utility_ai/response_curves.dart';
import 'package:baller/game/match/ai/utility_ai/utility_action.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Response Curves', () {
    test('exponential curve heavily suppresses low/mid values and spikes at top', () {
      expect(applyCurve(0.5, CurveType.exponential), closeTo(0.125, 0.001));
      expect(applyCurve(0.7, CurveType.exponential), closeTo(0.343, 0.001));
      expect(applyCurve(0.95, CurveType.exponential), closeTo(0.857, 0.005));
    });

    test('quadratic curve curves moderately', () {
      expect(applyCurve(0.5, CurveType.quadratic), 0.25);
      expect(applyCurve(0.8, CurveType.quadratic), closeTo(0.64, 0.001));
    });
  });

  group('PlayerBrain Utility AI decisions', () {
    late TacticalState possessionTactics;
    late SquadPlayer nessTeammate;

    setUp(() {
      possessionTactics = TacticalState.fromStyle(ClubStyle.possession);

      nessTeammate = const SquadPlayer(
        id: 'team-ness',
        name: 'Alexis Ness',
        age: 20,
        nationality: Nationality.german,
        role: SquadRole.am,
        rating: 80,
        value: 12000000,
        attributes: PlayerAttributes(
          age: 20,
          pace: 75,
          shot: 72,
          pass: 85,
          dribble: 80,
          defence: 50,
          physical: 65,
          ego: 30,
          tacticalDiscipline: 85,
        ),
      );
    });

    test('The Kaiser scenario: High ego striker chooses to shoot instead of passing to open teammate', () {
      // Kaiser: Extreme Ego (95), Low Tactical Discipline (20), High Shot (88)
      const kaiser = SquadPlayer(
        id: 'team-kaiser',
        name: 'Michael Kaiser',
        age: 21,
        nationality: Nationality.german,
        role: SquadRole.st,
        rating: 88,
        value: 45000000,
        attributes: PlayerAttributes(
          age: 21,
          pace: 85,
          shot: 88,
          pass: 74,
          dribble: 82,
          defence: 35,
          physical: 78,
          ego: 95, // Massive ego
          tacticalDiscipline: 20, // Ignores coach
          teamwork: 25,
        ),
      );

      final context = MatchDecisionContext(
        actor: kaiser,
        ballZone: PitchZone.opponentBox, // In the box!
        tactics: possessionTactics, // Coach says "Pass & Control"
        teammates: [kaiser, nessTeammate],
        targetOpenness: 0.9, // Ness is wide open!
      );

      final decision = PlayerBrain.decide(context);

      expect(decision.type, CandidateActionType.shoot);
      expect(decision.name, 'Take the Shot');
    });

    test('The System Midfielder scenario: High discipline midfielder chooses to pass', () {
      // System Midfielder: Low Ego (25), High Tactical Discipline (92), High Pass (84)
      const systemMidfielder = SquadPlayer(
        id: 'team-system',
        name: 'System Midfielder',
        age: 25,
        nationality: Nationality.spanish,
        role: SquadRole.cm,
        rating: 79,
        value: 14000000,
        attributes: PlayerAttributes(
          age: 25,
          pace: 68,
          shot: 70,
          pass: 84,
          dribble: 75,
          defence: 65,
          physical: 70,
          ego: 25, // Low ego
          tacticalDiscipline: 92, // Strictly obeys coach
          teamwork: 88,
        ),
      );

      final context = MatchDecisionContext(
        actor: systemMidfielder,
        ballZone: PitchZone.finalThird, // Edge of box
        tactics: possessionTactics, // Coach says "Pass & Control"
        teammates: [systemMidfielder, nessTeammate],
        targetOpenness: 0.85,
      );

      final decision = PlayerBrain.decide(context);

      expect(decision.type, CandidateActionType.shortPass);
      expect(decision.target, nessTeammate);
    });

    test('Defensive panic: Player under pressure in own box chooses clearance', () {
      const defender = SquadPlayer(
        id: 'team-cb',
        name: 'Stopper CB',
        age: 27,
        nationality: Nationality.english,
        role: SquadRole.cb,
        rating: 75,
        value: 6000000,
        attributes: PlayerAttributes(
          age: 27,
          pace: 65,
          shot: 30,
          pass: 60,
          dribble: 50,
          defence: 82,
          physical: 84,
          ego: 30,
          tacticalDiscipline: 80,
        ),
      );

      final context = MatchDecisionContext(
        actor: defender,
        ballZone: PitchZone.ownBox,
        tactics: possessionTactics,
        defendersInWay: 3, // Pressured by 3 attackers
        teammates: [defender, nessTeammate],
      );

      final decision = PlayerBrain.decide(context);

      expect(decision.type, CandidateActionType.clear);
      expect(decision.name, 'Clear Ball Out of Danger');
    });

    test('Desperation Mode tactic boosts teamwide shooting scores', () {
      const balancedPlayer = SquadPlayer(
        id: 'team-w',
        name: 'Balanced Winger',
        age: 22,
        nationality: Nationality.french,
        role: SquadRole.w,
        rating: 76,
        value: 8000000,
        attributes: PlayerAttributes(
          age: 22,
          pace: 82,
          shot: 74,
          pass: 72,
          dribble: 76,
          defence: 40,
          physical: 65,
          ego: 55,
          tacticalDiscipline: 65,
        ),
      );

      final normalContext = MatchDecisionContext(
        actor: balancedPlayer,
        ballZone: PitchZone.finalThird,
        tactics: possessionTactics,
        teammates: [balancedPlayer, nessTeammate],
      );

      // Same context but coach switched to All-Out Chaos
      final chaosTactics = TacticalState.fromStyle(ClubStyle.possession)
        ..setDesperationMode(85);

      final chaosContext = MatchDecisionContext(
        actor: balancedPlayer,
        ballZone: PitchZone.finalThird,
        tactics: chaosTactics,
        teammates: [balancedPlayer, nessTeammate],
      );

      final normalCandidates = PlayerBrain.generateCandidates(normalContext);
      final chaosCandidates = PlayerBrain.generateCandidates(chaosContext);

      final normalShot = normalCandidates.firstWhere((c) => c.type == CandidateActionType.shoot);
      final chaosShot = chaosCandidates.firstWhere((c) => c.type == CandidateActionType.shoot);

      expect(chaosShot.score(chaosContext), greaterThan(normalShot.score(normalContext)));
    });
  });
}
