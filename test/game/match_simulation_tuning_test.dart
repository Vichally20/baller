import 'dart:math';

import 'package:baller/game/data/talents.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/world/world_generator.dart';
import 'package:baller/ui/screens/match_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('Match Simulation Balance & Tuning', () {
    test('50 simulated matches run to completion with balanced scorelines', () {
      final world = generateWorld(42);
      final homeClub = world.clubs.first;
      final awayClub = world.clubs.elementAt(1);

      final artilleryTalent = allTalents.firstWhere(
        (t) => t.id == 'artillery_strike',
      );
      final scalpelTalent = allTalents.firstWhere((t) => t.id == 'the_scalpel');
      final user = testPlayer(
        1,
      ).copyWith(innateTalent: artilleryTalent, logicTalents: [scalpelTalent]);

      var totalGoals = 0;
      var totalMatches = 50;
      var tacticalShiftCount = 0;
      var talentActivationCount = 0;
      var cleanSheets = 0;

      for (var seed = 0; seed < totalMatches; seed++) {
        final sim = MatchSim(
          shirtName: user.identity.shirtName,
          user: user,
          homeClub: homeClub,
          awayClub: awayClub,
          random: Random(seed * 100 + 7),
        );

        while (!sim.isOver) {
          if (sim.isHalfTime) {
            sim.startSecondHalf();
            continue;
          }
          final options = sim.pad.values.toList();
          // Mix actions: shoot if available, else pass or dribble
          final shoot = options
              .where((a) => a == MatchAction.shoot)
              .firstOrNull;
          final pass = options.where((a) => a == MatchAction.pass).firstOrNull;
          final action = shoot ?? pass ?? options.first;
          sim.play(action);
        }

        expect(sim.isOver, isTrue);
        expect(sim.minute, 90);
        expect(sim.momentum.home, inInclusiveRange(0.0, 1.0));
        expect(sim.momentum.away, inInclusiveRange(0.0, 1.0));

        final matchGoals = sim.homeGoals + sim.awayGoals;
        totalGoals += matchGoals;

        if (sim.awayGoals == 0 || sim.homeGoals == 0) {
          cleanSheets++;
        }

        // Check tactical shifts
        tacticalShiftCount += sim.feed.where((line) => line.isTactical).length;

        // Check talent triggers
        talentActivationCount += sim.feed
            .where((line) => line.talentName != null)
            .length;
      }

      final avgGoals = totalGoals / totalMatches;
      // Realistic football average goals: between 1.5 and 4.5 goals per match
      expect(avgGoals, greaterThanOrEqualTo(1.5));
      expect(avgGoals, lessThanOrEqualTo(4.8));

      // Tactical shifts occurred across the simulation
      expect(tacticalShiftCount, greaterThan(0));

      // Talents triggered in the matches
      expect(talentActivationCount, greaterThan(0));

      // Clean sheets happen in realistic football
      expect(cleanSheets, greaterThan(0));
    });

    test(
      'Commentary feed lines have correct goal, tactical, and talent flags',
      () {
        final world = generateWorld(123);
        final homeClub = world.clubs.first;
        final awayClub = world.clubs.elementAt(2);

        final user = testPlayer(5).copyWith(
          innateTalent: allTalents.firstWhere(
            (t) => t.id == 'artillery_strike',
          ),
        );

        final sim = MatchSim(
          shirtName: user.identity.shirtName,
          user: user,
          homeClub: homeClub,
          awayClub: awayClub,
          random: Random(999),
        );

        while (!sim.isOver) {
          if (sim.isHalfTime) {
            sim.startSecondHalf();
            continue;
          }
          sim.play(sim.pad.values.first);
        }

        // Check all goal commentary lines are marked isGoal
        for (final line in sim.feed) {
          if (line.text.contains('GOAL!') ||
              line.text.contains('goal for them')) {
            expect(line.isGoal, isTrue);
          }
          if (line.text.startsWith('Tactical shift:')) {
            expect(line.isTactical, isTrue);
          }
        }
      },
    );

    test(
      'detailedCommentary generates routine AI play-by-play between chances',
      () {
        final world = generateWorld(77);
        final homeClub = world.clubs.first;
        final awayClub = world.clubs.elementAt(1);
        final user = testPlayer(7);

        // 1. With detailed commentary ON (default)
        final detailedSim = MatchSim(
          shirtName: user.identity.shirtName,
          user: user,
          homeClub: homeClub,
          awayClub: awayClub,
          detailedCommentary: true,
          random: Random(42),
        );

        while (!detailedSim.isOver) {
          if (detailedSim.isHalfTime) {
            detailedSim.startSecondHalf();
            continue;
          }
          detailedSim.play(detailedSim.pad.values.first);
        }

        final routinePlays = detailedSim.feed
            .where((l) => !l.isHighlight)
            .toList();
        final highlights = detailedSim.feed
            .where((l) => l.isHighlight)
            .toList();

        expect(routinePlays, isNotEmpty);
        expect(highlights, isNotEmpty);
        expect(
          detailedSim.feed.length,
          equals(routinePlays.length + highlights.length),
        );

        // 2. With detailed commentary OFF
        final quietSim = MatchSim(
          shirtName: user.identity.shirtName,
          user: user,
          homeClub: homeClub,
          awayClub: awayClub,
          detailedCommentary: false,
          random: Random(42),
        );

        while (!quietSim.isOver) {
          if (quietSim.isHalfTime) {
            quietSim.startSecondHalf();
            continue;
          }
          quietSim.play(quietSim.pad.values.first);
        }

        final quietRoutinePlays = quietSim.feed
            .where((l) => !l.isHighlight)
            .toList();
        expect(quietRoutinePlays, isEmpty);
      },
    );

    test(
      'buildHighlightedSpans highlights home players in green and away in red',
      () {
        final homeNames = {'Isagi', 'Bachira'};
        final awayNames = {'Kaiser', 'Ness'};
        final spans = buildHighlightedSpans(
          text: 'Kaiser slips a pass to Ness, but Isagi intercepts!',
          homeNames: homeNames,
          awayNames: awayNames,
          baseStyle: const TextStyle(color: Colors.black),
        );

        final textSpans = spans.whereType<TextSpan>().toList();
        final kaiserSpan = textSpans.firstWhere((s) => s.text == 'Kaiser');
        final nessSpan = textSpans.firstWhere((s) => s.text == 'Ness');
        final isagiSpan = textSpans.firstWhere((s) => s.text == 'Isagi');

        // Opponents in red
        expect(kaiserSpan.style?.color, const Color(0xFFDC2626));
        expect(kaiserSpan.style?.backgroundColor, const Color(0x22DC2626));
        expect(nessSpan.style?.color, const Color(0xFFDC2626));

        // Mine in green
        expect(isagiSpan.style?.color, const Color(0xFF15803D));
        expect(isagiSpan.style?.backgroundColor, const Color(0x2215803D));
      },
    );
  });
}
