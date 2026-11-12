import 'dart:math';

import 'package:baller/app.dart';
import 'package:baller/data/career_store.dart';
import 'package:baller/data/story_repository.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/data/wheels.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/season_progress.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/ui/screens/career_screen.dart';
import 'package:baller/ui/screens/pathway_screen.dart';
import 'package:baller/ui/screens/signing_screen.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/league_picker.dart';
import 'package:baller/ui/screens/club_screen.dart';
import 'package:baller/ui/screens/leagues_screen.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/ui/screens/lineup_screen.dart';
import 'package:baller/ui/screens/league_stats_screen.dart';
import 'package:baller/ui/screens/season_awards_screen.dart';
import 'package:baller/ui/screens/season_screen.dart';
import 'package:baller/ui/screens/match_report_screen.dart';
import 'package:baller/ui/screens/match_screen.dart';
import 'package:baller/ui/screens/identity_screen.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/ui/screens/country_screen.dart';
import 'package:baller/ui/screens/position_screen.dart';
import 'package:baller/ui/screens/scout_report_screen.dart';
import 'package:baller/ui/screens/slots_screen.dart';
import 'package:baller/ui/screens/stat_roll_screen.dart';
import 'package:baller/ui/screens/talent_detail_screen.dart';
import 'package:baller/ui/screens/talent_glossary_screen.dart';
import 'package:baller/ui/screens/talent_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Run each test on a phone-sized screen (390×844 logical px).
void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Launches the app fresh, as after a restart, and waits for saves to load.
Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(const BallerApp());
  await tester.pumpAndSettle();
}

/// Fills in identity, country (Nigeria) and position (winger), ending on the
/// stat wheels.
Future<void> _fillIdentity(
  WidgetTester tester, {
  String name = 'Tunde Bakare',
}) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.tap(find.text('Right'));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Nigeria'));
  await tester.pump();
  await tester.tap(find.text('Start in Lagos'));
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsLabel('Winger').first);
  await tester.pump();
  await tester.tap(find.text('Continue to stats'));
  await tester.pumpAndSettle();
}

/// From the identity screen, plays through to the career screen.
Future<Player> _finishCreation(
  WidgetTester tester, {
  String name = 'Tunde Bakare',
}) async {
  await _fillIdentity(tester, name: name);
  for (var i = 0; i < defaultWheels.length; i++) {
    await tester.tap(find.text('Spin'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Continue to talent'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Draw my talents'));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.byType(ScoutReportScreen), findsOneWidget);
  await tester.tap(find.text('See your pathway'));
  await tester.pumpAndSettle();
  await _takeFirstOption(tester);
  return tester.widget<CareerScreen>(find.byType(CareerScreen)).player;
}

/// On the pathway screen: takes the first offer or trial, signs if it's an
/// offer, and lands on the hub.
Future<void> _takeFirstOption(WidgetTester tester) async {
  expect(find.byType(PathwayScreen), findsOneWidget);
  await tester.tap(find.byType(PillButton));
  await tester.pumpAndSettle();
  if (find.byType(SigningScreen).evaluate().isNotEmpty) {
    await tester.tap(find.text('Start career'));
    await tester.pumpAndSettle();
  }
  expect(find.byType(CareerScreen), findsOneWidget);
}

/// Saves [player] in slot 1 and opens it from the title screen.
Future<void> _continueWith(WidgetTester tester, Player player) async {
  await const CareerStore().save(0, player);
  await _launch(tester);
  await tester.tap(find.text('Continue career'));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String label) =>
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

void _expectSamePlayer(Player? actual, Player expected) {
  expect(actual, isNotNull);
  for (final a in Attribute.values) {
    expect(actual!.attributes[a], expected.attributes[a]);
  }
  expect(actual!.location, same(expected.location));
  expect(actual.innateTalent, same(expected.innateTalent));
  expect(actual.logicTalents, expected.logicTalents);
  expect(actual.identity.name, expected.identity.name);
  expect(actual.identity.shirtName, expected.identity.shirtName);
  expect(actual.identity.foot, expected.identity.foot);
}

void main() {
  // Every test starts with no saved careers.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryRepository.resetCache();
    WorldRepository.clearCache();
  });

  testWidgets('title screen starts a new career', (tester) async {
    _usePhone(tester);
    await _launch(tester);
    expect(find.text('BALLER'), findsOneWidget);
    expect(find.text('Continue career'), findsNothing);

    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityScreen), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
  });

  testWidgets('glossary lists every talent and opens details', (tester) async {
    _usePhone(tester);
    await _launch(tester);
    await tester.tap(find.text('Talent glossary'));
    await tester.pumpAndSettle();
    expect(find.byType(TalentGlossaryScreen), findsOneWidget);

    final innate = allTalents.first;
    await tester.tap(find.text(innate.name));
    await tester.pumpAndSettle();
    expect(find.byType(TalentDetailScreen), findsOneWidget);
    expect(find.text(innate.description), findsOneWidget);

    // Logic talents live on the second tab.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(allTalents.last.name), findsNothing);
    await tester.tap(find.text('Logic (12)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(allTalents.last.name), 300);
    expect(find.text(allTalents.last.name), findsOneWidget);
  });

  testWidgets('country and position must be chosen; country shows benefit', (
    tester,
  ) async {
    _usePhone(tester);
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ada Obi');
    await tester.tap(find.text('Left'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(CountryScreen), findsOneWidget);
    expect(_enabled(tester, 'Pick a country'), isFalse);
    await tester.scrollUntilVisible(find.text('Italy'), 200);
    await tester.tap(find.text('Italy'));
    await tester.pump();
    expect(find.text('Tactical brain'), findsOneWidget);
    expect(_enabled(tester, 'Start in Milan'), isTrue);
    await tester.tap(find.text('Start in Milan'));
    await tester.pumpAndSettle();

    expect(find.byType(PositionScreen), findsOneWidget);
    expect(_enabled(tester, 'Pick a position'), isFalse);
    await tester.tap(find.bySemanticsLabel('Striker'));
    await tester.pump();
    expect(find.text('Striker'), findsOneWidget);
    await tester.tap(find.text('Continue to stats'));
    await tester.pumpAndSettle();
    final stats = tester.widget<StatRollScreen>(find.byType(StatRollScreen));
    expect(stats.location.country, 'Italy');
    expect(stats.position, Position.st);
  });

  testWidgets('stats → talents → scout report → career', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: StatRollScreen(
          slot: 0,
          identity: testIdentity,
          location: startingLocations.first, // Nigeria: +5 Dribble
          position: Position.w,
          random: Random(42),
        ),
      ),
    );

    for (var i = 0; i < defaultWheels.length; i++) {
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Stats rolled'), findsOneWidget);
    expect(find.textContaining('—'), findsNothing); // every stat revealed
    expect(find.text(' +5'), findsOneWidget); // the country bonus

    await tester.tap(find.text('Continue to talent'));
    await tester.pumpAndSettle();
    expect(find.byType(TalentScreen), findsOneWidget);
    await tester.tap(find.text('Draw my talents'));
    await tester.pump();
    expect(find.text('Draw my talents'), findsNothing);

    // Going back and returning keeps the talents already drawn.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to talent'));
    await tester.pumpAndSettle();
    expect(find.text('Draw my talents'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final report = tester.widget<ScoutReportScreen>(
      find.byType(ScoutReportScreen),
    );
    final player = report.creation.build();
    expect(find.text(player.tier.label), findsWidgets); // headline (+ scale)
    expect(find.text('SCOUT PICK'), findsOneWidget);
    final note = find.text(player.tier.scoutNote);
    await tester.scrollUntilVisible(note, 200);
    expect(note, findsOneWidget);

    await tester.tap(find.text('See your pathway'));
    await tester.pumpAndSettle();
    await _takeFirstOption(tester);
    await tester.pumpAndSettle(); // story content loads
    final saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.placement, isNotNull);
    // Offers open with "First Days", trials with "The Trial".
    expect(
      find.text(saved.placement!.kind.offers ? 'Arrival' : 'The Scout'),
      findsOneWidget,
    );
    final talents = find.text('TALENTS');
    await tester.scrollUntilVisible(talents, 300);
    expect(talents, findsOneWidget);
  });

  testWidgets('a trial: 2 scenes, the match, then the verdict and signing', (
    tester,
  ) async {
    _usePhone(tester);
    final trialist = placedPlayer(offers: false); // an academy in Nigeria
    final club = careerClubOf(
      trialist,
      WorldRepository.forSeed(trialist.worldSeed),
    )!;
    await _continueWith(tester, trialist);

    expect(find.text('ON TRIAL AT'), findsOneWidget);
    expect(find.text(club.name), findsOneWidget);

    // Scene 1: choice A has a single outcome, +10 morale and +5 coach.
    expect(find.text('The Scout'), findsOneWidget);
    await tester.tap(find.text('Play scene'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test, yes?'), findsOneWidget); // {first}
    expect(find.textContaining('I scout for ${club.name}.'), findsOneWidget);
    final yes = find.textContaining("I'll be there");
    await tester.scrollUntilVisible(yes, 200);
    await tester.ensureVisible(yes);
    await tester.pumpAndSettle();
    await tester.tap(yes);
    await tester.pumpAndSettle();
    expect(find.text('WHAT HAPPENED'), findsOneWidget);
    expect(find.text('+10 Morale'), findsOneWidget);
    expect(find.text('+5 Coach'), findsOneWidget);
    await tester.tap(find.text('Back to hub'));
    await tester.pumpAndSettle();

    // Scene 2: "Introduce yourself" is single-outcome, +5 coach, -5 mates.
    expect(find.text('The Training Ground'), findsOneWidget);
    await tester.tap(find.text('Play scene'));
    await tester.pumpAndSettle();
    final introduce = find.text('Introduce yourself to the coach');
    await tester.scrollUntilVisible(introduce, 200);
    await tester.ensureVisible(introduce);
    await tester.pumpAndSettle();
    await tester.tap(introduce);
    await tester.pumpAndSettle();
    expect(find.text('−5 Teammates'), findsOneWidget);
    await tester.tap(find.text('Back to hub'));
    await tester.pumpAndSettle();

    var player = (await const CareerStore().loadSlots())[0]!;
    expect(player.status.morale, 60);
    expect(player.status.coach, 60);
    expect(player.status.teammates, 45);
    expect(player.status.eventIndex, 2);
    expect(find.text('Trial match'), findsOneWidget);

    // Full time, saved the way the match screen saves it.
    await _continueWith(tester, player.withStatus(player.status.advance()));
    expect(find.text('TRIAL VERDICT'), findsOneWidget);
    await tester.tap(find.text('Hear the verdict'));
    await tester.pumpAndSettle();
    expect(find.byType(SigningScreen), findsOneWidget);
    expect(find.text(club.club.name), findsOneWidget); // the parent club
    expect(find.text("THE MANAGER'S DECISION"), findsOneWidget);
    expect(find.text(club.decision.position.label), findsWidgets);
    await tester.tap(find.text('Sign the contract'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR CLUB'), findsOneWidget);
    // The story is played out, so the league season begins.
    expect(find.text('UP NEXT · SEASON 1'), findsOneWidget);
    player = (await const CareerStore().loadSlots())[0]!;
    expect(player.placement!.signed, isTrue);
    expect(player.placement!.site, isNull);
    expect(player.status.eventIndex, 3);
  });

  testWidgets('a match: line-ups, kick-off, half-time, full time', (
    tester,
  ) async {
    _usePhone(tester);
    final trialist = placedPlayer(offers: false);
    // Both trial scenes played: the trial match is next.
    final atMatch = trialist.withStatus(trialist.status.advance().advance());
    await _continueWith(tester, atMatch);
    expect(find.text('Trial match'), findsOneWidget);
    await tester.tap(find.text('Play match'));
    await tester.pumpAndSettle();

    // The line-ups: both teams, you in your manager's position.
    expect(find.byType(LineupScreen), findsOneWidget);
    expect(find.text('The other trialists'), findsOneWidget);
    expect(find.text(trialist.identity.shirtName), findsOneWidget);
    await tester.tap(find.text('Kick off'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);

    /// Taps whichever move the pad shows first.
    Future<void> playMove() async {
      for (final action in MatchAction.values) {
        final arm = find.byKey(ValueKey('pad-${action.name}'));
        if (arm.evaluate().isNotEmpty) {
          await tester.tap(arm);
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('No move on the pad');
    }

    var moves = 0;
    while (find.text('Start second half').evaluate().isEmpty) {
      await playMove();
      expect(++moves, lessThan(40));
    }
    expect(find.text('HALF-TIME'), findsOneWidget);
    expect(find.textContaining("45'"), findsWidgets);
    await tester.tap(find.text('Start second half'));
    await tester.pumpAndSettle();

    while (find.text('Match report').evaluate().isEmpty) {
      await playMove();
      expect(++moves, lessThan(80));
    }
    expect(find.text('FULL TIME'), findsOneWidget);
    await tester.tap(find.text('Match report'));
    await tester.pumpAndSettle();

    // The report: the score, your match and the XP each stat earned.
    expect(find.byType(MatchReportScreen), findsOneWidget);
    expect(find.text('YOUR MATCH'), findsOneWidget);
    expect(find.text('XP EARNED'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Straight back to the hub (not the line-ups), match saved.
    expect(find.byType(LineupScreen), findsNothing);
    expect(find.text('TRIAL VERDICT'), findsOneWidget);
    final saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.status.eventIndex, 3);
  });

  testWidgets('after the story: the league season, round by round', (
    tester,
  ) async {
    _usePhone(tester);
    final prodigy = placedPlayer(offers: true);
    // "First Days" played: two scenes and a match.
    final done = prodigy.withStatus(
      prodigy.status.advance().advance().advance(),
    );
    await _continueWith(tester, done);

    // No dead end: the season's first round is up next.
    expect(find.text('To be continued'), findsNothing);
    expect(find.text('UP NEXT · SEASON 1'), findsOneWidget);
    expect(find.text('Scene 1'), findsOneWidget);
    final table = find.text('Table');
    await tester.scrollUntilVisible(table, 200);
    expect(find.textContaining('not started'), findsOneWidget);

    // A scene moves the round on, not the story.
    await tester.scrollUntilVisible(find.text('Play scene'), -200);
    await tester.tap(find.text('Play scene'));
    await tester.pumpAndSettle();
    final a = find.text('A');
    await tester.scrollUntilVisible(a, 200);
    await tester.ensureVisible(a);
    await tester.pumpAndSettle();
    await tester.tap(a);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to hub'));
    await tester.pumpAndSettle();
    var saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.season.scenesPlayed, 1);
    expect(saved.status.eventIndex, done.status.eventIndex);
    expect(find.text('Scene 2'), findsOneWidget);

    // After a win, the table and your results show it.
    await _continueWith(tester, saved.withSeason(saved.season.record(2, 1)));
    await tester.scrollUntilVisible(find.text('Table'), 200);
    expect(find.textContaining('· 3 pts'), findsOneWidget);
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonScreen), findsOneWidget);
    final results = find.text('YOUR RESULTS');
    await tester.scrollUntilVisible(results, 300);
    // In yours, and in the round's results (home side first, so 1–2 if
    // you were away; other games may have the same score).
    expect(
      find.text('2–1').evaluate().length + find.text('1–2').evaluate().length,
      greaterThanOrEqualTo(2),
    );

    // A finished season offers the next one.
    var full = saved.season;
    for (var i = 0; i < 38; i++) {
      full = full.record(1, 0);
    }
    await _continueWith(tester, saved.withSeason(full));
    expect(find.text('SEASON 1 OVER'), findsOneWidget);
    expect(find.text('You finished 1st'), findsOneWidget);
    await tester.tap(find.text('See the awards'));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonAwardsScreen), findsOneWidget);
    expect(find.textContaining('CHAMPIONS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GOLDEN BOOT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start season 2'));
    await tester.pumpAndSettle();
    expect(find.text('UP NEXT · SEASON 2'), findsOneWidget);
    saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.season.season, 2);
  });

  testWidgets('league stats and awards for a senior player', (tester) async {
    _usePhone(tester);
    final base = placedPlayer(offers: false);
    final world = WorldRepository.forSeed(base.worldSeed);
    final club = world.clubs.firstWhere((c) => c.division == 1);
    var progress = SeasonProgress.first;
    for (var r = 0; r < 12; r++) {
      progress = progress.record(
        3,
        0,
        scorers: [
          for (var g = 0; g < 3; g++)
            const RoundGoal(mine: true, scorerId: MatchSim.userId),
        ],
      );
    }
    final player = base
        .withPlacement(
          Placement(
            kind: PathwayKind.seniorHome,
            clubId: club.id,
            signed: true,
          ),
        )
        .withSeason(progress);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LeagueStatsScreen(player: player, initialCountry: club.country),
      ),
    );
    await tester.pumpAndSettle();
    // 36 goals in 12 games: you lead the Golden Boot race.
    expect(find.text('GOLDEN BOOT RACE · ROUND 12 OF 38'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('36'), findsWidgets);
    await tester.tap(find.text('Assists'));
    await tester.pumpAndSettle();
    expect(find.text('MOST ASSISTS · ROUND 12 OF 38'), findsOneWidget);
    await tester.tap(find.text('Clean sheets'));
    await tester.pumpAndSettle();
    expect(find.text('GOLDEN GLOVE RACE · ROUND 12 OF 38'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SeasonAwardsScreen(player: player),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('if it ended today'), findsOneWidget);
    expect(find.text('YOUR SEASON'), findsOneWidget);
    expect(find.text('Golden Boot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('YOUNG PLAYER OF THE SEASON'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('simulating a match plays it all and shows the report', (
    tester,
  ) async {
    _usePhone(tester);
    final trialist = placedPlayer(offers: false);
    await _continueWith(
      tester,
      trialist.withStatus(trialist.status.advance().advance()),
    );
    await tester.tap(find.text('Play match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate'));
    await tester.pumpAndSettle();

    // Straight to full time, with the moves saved as if played.
    expect(find.text('FULL TIME'), findsOneWidget);
    var saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.match!.moves, isNotEmpty);
    await tester.tap(find.text('Match report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('simulated'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.match, isNull);
    expect(saved.status.eventIndex, 3);
  });

  testWidgets('leaving a match half-way and coming back resumes it', (
    tester,
  ) async {
    _usePhone(tester);
    final trialist = placedPlayer(offers: false);
    await _continueWith(
      tester,
      trialist.withStatus(trialist.status.advance().advance()),
    );
    await tester.tap(find.text('Play match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kick off'));
    await tester.pumpAndSettle();

    Future<void> playMove() async {
      for (final action in MatchAction.values) {
        final arm = find.byKey(ValueKey('pad-${action.name}'));
        if (arm.evaluate().isNotEmpty) {
          await tester.tap(arm);
          await tester.pumpAndSettle();
          return;
        }
      }
    }

    for (var i = 0; i < 5; i++) {
      await playMove();
    }
    String scoreLabel() => tester
        .getSemantics(find.bySemanticsLabel(RegExp('minute')).first)
        .label;
    final before = scoreLabel();
    var saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.match!.moves, hasLength(5));

    // Leave: back to the line-ups, back to the hub.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Resume match'), findsOneWidget);

    // Come back, even after a restart: the same minute and score.
    await _continueWith(tester, saved);
    await tester.tap(find.text('Resume match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(scoreLabel(), before);

    // Finishing the match clears it.
    while (find.text('Match report').evaluate().isEmpty) {
      if (find.text('Start second half').evaluate().isNotEmpty) {
        await tester.tap(find.text('Start second half'));
        await tester.pumpAndSettle();
      }
      await playMove();
    }
    await tester.tap(find.text('Match report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.match, isNull);
    expect(saved.status.eventIndex, 3);
  });

  testWidgets('offers: pick a club, the manager decides, First Days begins', (
    tester,
  ) async {
    _usePhone(tester);
    final prodigy = pathwayPlayer(offers: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PathwayScreen(player: prodigy, slot: 0),
      ),
    );
    await tester.pumpAndSettle();
    final pathway = pathwayFor(
      prodigy,
      WorldRepository.forSeed(prodigy.worldSeed),
    );
    expect(find.textContaining('BEST FIT FIRST'), findsOneWidget);

    // Pick the second offer.
    final second = pathway.options[1];
    await tester.ensureVisible(find.text(second.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text(second.name));
    await tester.pump();
    await tester.tap(find.text('Join ${second.name}'));
    await tester.pumpAndSettle();

    expect(find.byType(SigningScreen), findsOneWidget);
    expect(find.text('WELCOME TO'), findsOneWidget);
    expect(find.text(second.decision.position.label), findsWidgets);
    expect(find.text(second.decision.reason), findsOneWidget);
    await tester.tap(find.text('Start career'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(); // story content loads

    expect(find.byType(CareerScreen), findsOneWidget);
    expect(find.text('YOUR CLUB'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    final saved = (await const CareerStore().loadSlots())[0]!;
    expect(saved.placement!.clubId, second.club.id);
    expect(saved.placement!.signed, isTrue);
  });

  testWidgets('a career from before pathways is asked to choose one', (
    tester,
  ) async {
    _usePhone(tester);
    await _continueWith(tester, _seedPlayer());
    expect(find.text('Choose your path'), findsOneWidget);
    await tester.tap(find.text('See your pathway'));
    await tester.pumpAndSettle();
    await _takeFirstOption(tester);
    expect(find.text('Choose your path'), findsNothing);
    expect((await const CareerStore().loadSlots())[0]!.placement, isNotNull);
  });

  testWidgets('identity screen: name and foot required, shirt auto-fills', (
    tester,
  ) async {
    _usePhone(tester);
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();

    bool canContinue() =>
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Continue'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed !=
        null;

    expect(canContinue(), isFalse);
    final nameField = find.byType(TextField).first;
    final shirtField = find.byType(TextField).last;

    // Name alone isn't enough; the shirt name follows the surname.
    await tester.enterText(nameField, 'Ada  Obi-Nwosu ');
    await tester.pump();
    expect(find.text('OBI-NWOSU'), findsWidgets);
    expect(canContinue(), isFalse);

    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(canContinue(), isTrue);
    expect(find.text('Left-footed'), findsOneWidget);

    // An invalid name blocks Continue and explains why.
    await tester.enterText(nameField, 'A');
    await tester.pump();
    expect(find.text('Enter at least 2 letters.'), findsOneWidget);
    expect(canContinue(), isFalse);

    // A custom shirt name sticks even when the name changes.
    await tester.enterText(nameField, 'Ada Obi');
    await tester.enterText(shirtField, 'Ada');
    await tester.pump();
    await tester.enterText(nameField, 'Ada Obiora');
    await tester.pump();
    expect(find.text('ADA'), findsOneWidget); // preview

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final country = tester.widget<CountryScreen>(find.byType(CountryScreen));
    expect(country.identity.name, 'Ada Obiora');
    expect(country.identity.shirtName, 'ADA');
    expect(country.identity.foot, Foot.left);
  });

  testWidgets('hub → leagues → club shows the manager and squad', (
    tester,
  ) async {
    _usePhone(tester);
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await _finishCreation(tester); // Nigeria: no league of its own
    await tester.pumpAndSettle();

    final leagues = find.text('Leagues');
    await tester.scrollUntilVisible(leagues, 200);
    await tester.ensureVisible(leagues);
    await tester.pumpAndSettle();
    expect(find.textContaining('your value €'), findsOneWidget);
    await tester.tap(leagues);
    await tester.pumpAndSettle();
    expect(find.byType(LeaguesScreen), findsOneWidget);
    expect(find.byType(DivisionTabs), findsOneWidget);

    // Switch to Spain's second division, and open the top club.
    await tester.tap(find.text('Spain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segunda'));
    await tester.pumpAndSettle();
    final screen = tester.widget<LeaguesScreen>(find.byType(LeaguesScreen));
    final spain = screen.world.leagues.firstWhere(
      (l) => l.country == LeagueCountry.spain,
    );
    final top = [...spain.divisions[1]]
      ..sort(
        (a, b) => b.stars != a.stars
            ? b.stars.compareTo(a.stars)
            : b.averageRating.compareTo(a.averageRating),
      );
    await tester.tap(find.text(top.first.name));
    await tester.pumpAndSettle();

    expect(find.byType(ClubScreen), findsOneWidget);
    expect(find.text('Spain · Segunda División'), findsOneWidget);
    expect(find.text('MANAGER'), findsOneWidget);
    final managerCard = find.ancestor(
      of: find.text('MANAGER'),
      matching: find.byType(SoftCard),
    );
    expect(
      find.descendant(
        of: managerCard,
        matching: find.text(top.first.manager.name),
      ),
      findsOneWidget,
    );
    final squad = find.textContaining('22 / 22');
    await tester.scrollUntilVisible(squad, 200);
    expect(squad, findsOneWidget);
  });

  testWidgets('one saved career: Continue opens it directly', (tester) async {
    _usePhone(tester);
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    final player = await _finishCreation(tester);

    await _launch(tester);
    expect(find.text('Continue career'), findsOneWidget);
    await tester.tap(find.text('Continue career'));
    await tester.pumpAndSettle();
    expect(find.byType(SlotsScreen), findsNothing);
    final career = tester.widget<CareerScreen>(find.byType(CareerScreen));
    expect(career.slot, 0);
    _expectSamePlayer(career.player, player);
    expect(find.text('Tunde Bakare'), findsOneWidget);
  });

  testWidgets('second career fills slot 2; a third asks which to replace', (
    tester,
  ) async {
    _usePhone(tester);
    const store = CareerStore();

    // Career 1 → slot 1, career 2 → slot 2, no questions asked.
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    final first = await _finishCreation(tester);
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityScreen), findsOneWidget);
    final second = await _finishCreation(tester);
    expect(tester.widget<CareerScreen>(find.byType(CareerScreen)).slot, 1);

    var slots = await store.loadSlots();
    _expectSamePlayer(slots[0], first);
    _expectSamePlayer(slots[1], second);

    // Continue with two careers → pick one.
    await _launch(tester);
    await tester.tap(find.text('Continue career'));
    await tester.pumpAndSettle();
    expect(find.text('Your careers'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Continue slot 2')));
    await tester.pumpAndSettle();
    expect(tester.widget<CareerScreen>(find.byType(CareerScreen)).slot, 1);

    // A third career: both full → slot picker. Cancel keeps everything.
    await _launch(tester);
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    expect(find.text('Replace a career'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Replace slot 1')));
    await tester.pumpAndSettle();
    expect(find.text('Replace slot 1?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityScreen), findsNothing);

    // Confirm, but back out of creation: nothing is overwritten yet.
    await tester.tap(find.bySemanticsLabel(RegExp('^Replace slot 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    slots = await store.loadSlots();
    _expectSamePlayer(slots[0], first);

    // Confirm and finish: slot 1 is replaced, slot 2 untouched.
    await tester.tap(find.bySemanticsLabel(RegExp('^Replace slot 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Replace'));
    await tester.pumpAndSettle();
    final third = await _finishCreation(tester);
    expect(tester.widget<CareerScreen>(find.byType(CareerScreen)).slot, 0);
    slots = await store.loadSlots();
    _expectSamePlayer(slots[0], third);
    _expectSamePlayer(slots[1], second);
  });

  testWidgets('a career saved before slots existed lands in slot 1', (
    tester,
  ) async {
    // Write a save under the old single-slot key.
    const store = CareerStore();
    await store.save(0, _seedPlayer());
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('career.slot.0')!;
    SharedPreferences.setMockInitialValues({'career.player': raw});

    final slots = await store.loadSlots();
    expect(slots[0], isNotNull);
    expect(slots[1], isNull);
    final migrated = await SharedPreferences.getInstance();
    expect(migrated.getString('career.player'), isNull);
  });
}

/// A fixed, valid player built from the real game data, without the UI.
Player _seedPlayer() => testPlayer(11);
