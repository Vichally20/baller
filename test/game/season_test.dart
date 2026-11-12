import 'dart:convert';
import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Map<String, Object?> _scenario(String id) => {
  'id': id,
  'title': id,
  'text': 'Before {opponent}',
  'choices': [
    for (final c in ['A', 'B'])
      {
        'text': c,
        'outcomes': [
          {'text': 'ok'},
        ],
      },
  ],
};

/// A story chapter for everyone plus a pool of [poolSize] scenes.
StoryContent _content(int poolSize) => StoryContent.fromJson(
  itemsJson: <String, Object?>{},
  chapterJson: [
    (
      'story.json',
      {
        'id': 'story',
        'title': 'Story',
        'scenarios': [_scenario('s1')],
      },
    ),
    if (poolSize > 0)
      (
        'pool.json',
        {
          'id': 'pool',
          'title': 'Matchweek',
          'pool': true,
          'scenarios': [for (var i = 0; i < poolSize; i++) _scenario('p$i')],
        },
      ),
  ],
);

/// A signed player: senior (real squads) or academy (youth).
Player _signed({required bool senior}) {
  final player = placedPlayer(offers: !senior);
  if (!senior) return player.withPlacement(player.placement!.sign());
  final world = WorldRepository.forSeed(player.worldSeed);
  final club = world.clubs.firstWhere((c) => c.division == 2);
  return player.withPlacement(
    Placement(kind: PathwayKind.seniorHome, clubId: club.id, signed: true),
  );
}

void main() {
  group('fixtures', () {
    final clubs = WorldRepository.forSeed(2026).leagues.first.divisions[0];
    final rounds = buildFixtures(clubs, Random(1));

    test('38 rounds; everyone plays once a round', () {
      expect(rounds, hasLength(38));
      for (final round in rounds) {
        expect(round, hasLength(10));
        final ids = [
          for (final f in round) ...[f.home.id, f.away.id],
        ];
        expect(ids.toSet(), hasLength(20));
      }
    });

    test('every pair meets twice, once at each ground', () {
      final meetings = <String>{};
      for (final round in rounds) {
        for (final f in round) {
          expect(meetings.add('${f.home.id}>${f.away.id}'), isTrue);
        }
      }
      expect(meetings, hasLength(20 * 19));
      for (final c in clubs) {
        final home = rounds.expand((r) => r).where((f) => f.home.id == c.id);
        expect(home, hasLength(19));
      }
    });
  });

  group('the season', () {
    test('only for signed players', () {
      final trialist = youthTrialist(); // not signed yet
      final world = WorldRepository.forSeed(trialist.worldSeed);
      expect(seasonFor(trialist, world, SeasonProgress.first), isNull);
      final signed = trialist.withPlacement(trialist.placement!.sign());
      final season = seasonFor(signed, world, SeasonProgress.first)!;
      expect(season.youth, isTrue);
      expect(season.leagueName, endsWith('U18 League'));
      expect(season.sideName(season.club), endsWith(' U18'));
      final senior = seasonFor(
        _signed(senior: true),
        WorldRepository.forSeed(_signed(senior: true).worldSeed),
        SeasonProgress.first,
      )!;
      expect(senior.youth, isFalse);
      expect(senior.leagueName, League.nameOf(senior.club.country, 2));
    });

    test('the table counts your results and simulates the rest', () {
      final player = _signed(senior: true);
      final world = WorldRepository.forSeed(player.worldSeed);
      var progress = SeasonProgress.first;
      for (final r in [(3, 0), (1, 1), (0, 2)]) {
        progress = progress.record(r.$1, r.$2);
      }
      final season = seasonFor(player, world, progress)!;
      final mine = season.table.firstWhere((r) => r.club.id == season.club.id);
      expect([mine.played, mine.won, mine.drawn, mine.lost], [3, 1, 1, 1]);
      expect([mine.goalsFor, mine.goalsAgainst, mine.points], [4, 3, 4]);
      expect(season.table.every((r) => r.played == 3), isTrue);
      // Goals scored and conceded balance across the league.
      final scored = season.table.fold(0, (s, r) => s + r.goalsFor);
      final conceded = season.table.fold(0, (s, r) => s + r.goalsAgainst);
      expect(scored, conceded);
      // The same every time.
      final again = seasonFor(player, world, progress)!;
      expect(
        [for (final r in again.table) r.club.id],
        [for (final r in season.table) r.club.id],
      );
    });

    test('simulated scores look like football', () {
      final clubs = WorldRepository.forSeed(7).leagues.first.divisions[0];
      final rng = Random(3);
      var goals = 0;
      var games = 0;
      for (final round in buildFixtures(clubs, Random(2))) {
        for (final f in round) {
          final (h, a) = simulateScore(f, rng);
          goals += h + a;
          games++;
        }
      }
      expect(goals / games, inInclusiveRange(2.0, 3.5));
    });

    test('38 results end the season; the next starts fresh', () {
      final player = _signed(senior: false);
      final world = WorldRepository.forSeed(player.worldSeed);
      var progress = SeasonProgress.first;
      for (var i = 0; i < 38; i++) {
        progress = progress.record(1, 0);
      }
      final season = seasonFor(player, world, progress)!;
      expect(season.isOver, isTrue);
      expect(season.nextFixture, isNull);
      expect(season.position, 1); // won every game
      final next = progress.nextSeason();
      expect([next.season, next.round, next.scenesPlayed], [2, 0, 0]);
    });
  });

  group('rounds', () {
    final player = _signed(senior: true);
    final world = WorldRepository.forSeed(player.worldSeed);

    test('two pool scenes, then the match against the next opponent', () {
      final season = seasonFor(player, world, SeasonProgress.first)!;
      final round = seasonRound(_content(5), player, season);
      expect(round, hasLength(3));
      expect(round[0], isA<ScenarioEvent>());
      expect(round[1], isA<ScenarioEvent>());
      final match = round[2] as MatchEvent;
      expect(match.fixture, same(season.nextFixture));
      expect(match.match.title, startsWith('Round 1 · '));
      expect(round.every((e) => e.isSeason), isTrue);
      expect(
        fillText('{opponent}', player, opponent: round[0].opponent),
        match.match.opponent,
      );
      // Story chapters never include pool scenes.
      expect(
        buildSchedule(_content(5), player).map((e) => e.chapter.id).toSet(),
        {'story'},
      );
    });

    test('scenes only repeat once the whole pool has been seen', () {
      final seen = <String>[];
      var progress = SeasonProgress.first;
      for (var r = 0; r < 3; r++) {
        final season = seasonFor(player, world, progress)!;
        final round = seasonRound(_content(6), player, season);
        seen.addAll(round.whereType<ScenarioEvent>().map((e) => e.scenario.id));
        progress = progress.record(0, 0);
      }
      expect(seen.toSet(), hasLength(6));
    });

    test('no pool: straight to the match', () {
      final season = seasonFor(player, world, SeasonProgress.first)!;
      expect(
        seasonRound(_content(0), player, season).single,
        isA<MatchEvent>(),
      );
    });

    test('a season scene or match moves the season, not the story', () {
      final season = seasonFor(player, world, SeasonProgress.first)!;
      final round = seasonRound(_content(4), player, season);
      final afterOne = afterScene(player, round[0], const Effects(morale: 10));
      expect(afterOne.season.scenesPlayed, 1);
      expect(afterOne.status.eventIndex, player.status.eventIndex);
      expect(afterOne.status.morale, player.status.morale + 10);
      final played = afterMatch(
        afterOne,
        round[2],
        goalsFor: 2,
        goalsAgainst: 1,
      );
      expect(played.season.results, [(2, 1)]);
      expect(played.season.scenesPlayed, 0);
      expect(played.status.eventIndex, player.status.eventIndex);

      // Story events still move the story on.
      final story = buildSchedule(_content(4), player);
      expect(
        afterScene(player, story[0], Effects.none).status.eventIndex,
        player.status.eventIndex + 1,
      );
    });
  });

  test('season progress survives saving', () {
    final player = _signed(senior: true).withSeason(
      const SeasonProgress(
        season: 2,
        results: [(1, 0), (2, 2)],
        scenesPlayed: 1,
      ),
    );
    const codec = PlayerCodec();
    final back = codec.fromJson(jsonDecode(jsonEncode(codec.toJson(player))))!;
    expect(back.season.season, 2);
    expect(back.season.results, [(1, 0), (2, 2)]);
    expect(back.season.scenesPlayed, 1);
    final legacy = codec.toJson(player)..remove('season');
    expect(codec.fromJson(legacy)!.season.round, 0);
  });

  test('only players 18 or under play youth football', () {
    final base = placedPlayer(offers: true);
    final world = WorldRepository.forSeed(base.worldSeed);
    final club = world.clubs.firstWhere((c) => c.hasAcademy);
    final academy = base.withPlacement(
      Placement(kind: PathwayKind.academyHome, clubId: club.id, signed: true),
    );
    PlayerAttributes aged(int age) => academy.attributes.copyWith(age: age);

    // An academy player at 18 is in the U18 league; at 19 they move up.
    final at18 = academy.copyWith(attributes: aged(18));
    expect(seasonFor(at18, world, at18.season)!.youth, isTrue);
    final at19 = academy.copyWith(attributes: aged(19));
    final senior = seasonFor(at19, world, at19.season)!;
    expect(senior.youth, isFalse);
    expect(senior.leagueName, League.nameOf(club.country, club.division));

    // A 25-year-old who signed after a trial plays senior football.
    final trialist = placedPlayer(offers: false);
    final signed = trialist
        .withPlacement(trialist.placement!.sign())
        .copyWith(attributes: trialist.attributes.copyWith(age: 25));
    expect(signed.placement!.kind.offers, isFalse);
    expect(seasonFor(signed, world, signed.season)!.youth, isFalse);
  });
}
