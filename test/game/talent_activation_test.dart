import 'dart:math';

import 'package:baller/game/data/talents.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/match/resolution/talent_resolver.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  const goalkeeper = SquadPlayer(
    id: 'gk',
    name: 'Goalkeeper',
    age: 25,
    nationality: Nationality.english,
    role: SquadRole.gk,
    rating: 70,
    value: 1000000,
    attributes: PlayerAttributes(
      age: 25,
      pace: 50,
      shot: 20,
      pass: 50,
      dribble: 30,
      defence: 70,
      physical: 75,
    ),
  );

  const defender = SquadPlayer(
    id: 'cb',
    name: 'Defender',
    age: 26,
    nationality: Nationality.english,
    role: SquadRole.cb,
    rating: 75,
    value: 4000000,
    attributes: PlayerAttributes(
      age: 26,
      pace: 70,
      shot: 30,
      pass: 60,
      dribble: 45,
      defence: 78,
      physical: 80,
    ),
  );

  group('Innate Talents Activation', () {
    final artilleryTalent = allTalents.firstWhere(
      (t) => t.id == 'artillery_strike',
    );
    final elFenomenoTalent = allTalents.firstWhere(
      (t) => t.id == 'el_fenomeno',
    );
    final apexBullyTalent = allTalents.firstWhere((t) => t.id == 'apex_bully');

    test(
      'Artillery Strike triggers on long range shot and bypasses defence',
      () {
        final shooter = SquadPlayer(
          id: 'artillery-player',
          name: 'Gerrard',
          age: 24,
          nationality: Nationality.english,
          role: SquadRole.cm,
          rating: 84,
          value: 20000000,
          innateTalent: artilleryTalent,
          attributes: const PlayerAttributes(
            age: 24,
            pace: 75,
            shot: 86,
            pass: 82,
            dribble: 75,
            defence: 70,
            physical: 80,
          ),
        );

        var triggered = false;
        for (var i = 0; i < 50; i++) {
          final result = TalentResolver.checkTalents(
            TalentActivationContext(
              actor: shooter,
              action: MatchAction.shoot,
              zone: PitchZone.finalThird,
              goalkeeper: goalkeeper,
              defender: defender,
              momentum: MatchMomentum(),
              rng: Random(i),
            ),
          );
          if (result != null && result.talent.id == 'artillery_strike') {
            triggered = true;
            expect(result.bypassDefence, isTrue);
            expect(
              result.boostedAttackStat,
              greaterThan(shooter.attributes.shot),
            );
            expect(result.announcement, contains('Artillery Strike'));
            break;
          }
        }
        expect(triggered, isTrue);
      },
    );

    test(
      'El Fenomeno triggers in opponent box and triggers automatic goal',
      () {
        final r9 = SquadPlayer(
          id: 'r9',
          name: 'Ronaldo R9',
          age: 21,
          nationality: Nationality.brazilian,
          role: SquadRole.st,
          rating: 90,
          value: 50000000,
          innateTalent: elFenomenoTalent,
          attributes: const PlayerAttributes(
            age: 21,
            pace: 92,
            shot: 90,
            pass: 75,
            dribble: 94,
            defence: 30,
            physical: 80,
          ),
        );

        var triggered = false;
        for (var i = 0; i < 50; i++) {
          final result = TalentResolver.checkTalents(
            TalentActivationContext(
              actor: r9,
              action: MatchAction.shoot,
              zone: PitchZone.opponentBox,
              goalkeeper: goalkeeper,
              defender: defender,
              momentum: MatchMomentum(),
              rng: Random(i),
            ),
          );
          if (result != null && result.talent.id == 'el_fenomeno') {
            triggered = true;
            expect(result.automaticGoal, isTrue);
            expect(result.bypassGoalkeeper, isTrue);
            expect(result.announcement, contains('El Fenómeno'));
            break;
          }
        }
        expect(triggered, isTrue);
      },
    );

    test(
      'Apex Bully triggers on aerial headers and suppresses defender physical',
      () {
        final targetMan = SquadPlayer(
          id: 'drogba',
          name: 'Drogba',
          age: 27,
          nationality: Nationality.english,
          role: SquadRole.st,
          rating: 86,
          value: 25000000,
          innateTalent: apexBullyTalent,
          attributes: const PlayerAttributes(
            age: 27,
            pace: 78,
            shot: 85,
            pass: 70,
            dribble: 75,
            defence: 45,
            physical: 92,
          ),
        );

        var triggered = false;
        for (var i = 0; i < 50; i++) {
          final result = TalentResolver.checkTalents(
            TalentActivationContext(
              actor: targetMan,
              action: MatchAction.nod,
              zone: PitchZone.opponentBox,
              goalkeeper: goalkeeper,
              defender: defender,
              momentum: MatchMomentum(),
              rng: Random(i),
            ),
          );
          if (result != null && result.talent.id == 'apex_bully') {
            triggered = true;
            expect(result.suppressedDefendStat, 0);
            expect(result.announcement, contains('Apex Bully'));
            break;
          }
        }
        expect(triggered, isTrue);
      },
    );
  });

  group('Logic Talents Activation', () {
    final scalpelTalent = allTalents.firstWhere((t) => t.id == 'the_scalpel');
    final tempoTalent = allTalents.firstWhere((t) => t.id == 'tempo_dictator');

    test('The Scalpel triggers on through pass and bypasses defence', () {
      final passer = SquadPlayer(
        id: 'kdb',
        name: 'De Bruyne',
        age: 28,
        nationality: Nationality.english,
        role: SquadRole.am,
        rating: 89,
        value: 40000000,
        logicTalents: [scalpelTalent],
        attributes: const PlayerAttributes(
          age: 28,
          pace: 75,
          shot: 84,
          pass: 94,
          dribble: 85,
          defence: 55,
          physical: 76,
        ),
      );

      var triggered = false;
      for (var i = 0; i < 50; i++) {
        final result = TalentResolver.checkTalents(
          TalentActivationContext(
            actor: passer,
            action: MatchAction.pass,
            zone: PitchZone.midfield,
            goalkeeper: goalkeeper,
            defender: defender,
            momentum: MatchMomentum(),
            rng: Random(i),
          ),
        );
        if (result != null && result.talent.id == 'the_scalpel') {
          triggered = true;
          expect(result.bypassDefence, isTrue);
          expect(result.boostedAttackStat, 98);
          expect(result.announcement, contains('The Scalpel'));
          break;
        }
      }
      expect(triggered, isTrue);
    });

    test('Tempo Dictator resets team momentum to neutral', () {
      final metronome = SquadPlayer(
        id: 'kroos',
        name: 'Toni Kroos',
        age: 29,
        nationality: Nationality.german,
        role: SquadRole.cm,
        rating: 87,
        value: 30000000,
        logicTalents: [tempoTalent],
        attributes: const PlayerAttributes(
          age: 29,
          pace: 60,
          shot: 78,
          pass: 93,
          dribble: 80,
          defence: 65,
          physical: 70,
        ),
      );

      final biasedMomentum = MatchMomentum(
        home: 0.15,
      ); // Heavily losing momentum

      var triggered = false;
      for (var i = 0; i < 50; i++) {
        final result = TalentResolver.checkTalents(
          TalentActivationContext(
            actor: metronome,
            action: MatchAction.pass,
            zone: PitchZone.midfield,
            goalkeeper: goalkeeper,
            defender: defender,
            momentum: biasedMomentum,
            rng: Random(i),
          ),
        );
        if (result != null && result.talent.id == 'tempo_dictator') {
          triggered = true;
          expect(biasedMomentum.home, 0.5); // Reset!
          expect(result.announcement, contains('Tempo Dictator'));
          break;
        }
      }
      expect(triggered, isTrue);
    });
  });

  group('In-Game MatchSim Talent Execution', () {
    test('user player talent triggers in live MatchSim feed', () {
      final artilleryTalent = allTalents.firstWhere(
        (t) => t.id == 'artillery_strike',
      );
      final playerWithTalent = testPlayer(1)
          .copyWith(innateTalent: artilleryTalent);

      var talentAppearedInFeed = false;
      for (var seed = 0; seed < 10; seed++) {
        final sim = MatchSim(
          shirtName: playerWithTalent.identity.shirtName,
          user: playerWithTalent,
          random: Random(seed),
        );

        while (!sim.isOver) {
          if (sim.isHalfTime) {
            sim.startSecondHalf();
            continue;
          }
          final options = sim.pad.values.toList();
          final shootOption = options
              .where((a) => a == MatchAction.shoot)
              .firstOrNull;
          sim.play(shootOption ?? options.first);
        }

        if (sim.feed.any((line) => line.text.contains('Artillery Strike'))) {
          talentAppearedInFeed = true;
          break;
        }
      }

      expect(talentAppearedInFeed, isTrue);
    });
  });
}
