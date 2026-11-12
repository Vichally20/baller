import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/position_decision.dart';
import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Location _at(String id) => startingLocations.firstWhere((l) => l.id == id);

/// Flat stats at [level] (age [age]), so the tier is easy to pick:
/// 70 → genius, 64 → rare, 54 → average, 44 → poor.
Player _player({
  required int level,
  required int age,
  String location = 'nigeria',
  Position wish = Position.w,
  PlayerAttributes? stats,
}) => Player(
  identity: testIdentity,
  attributes:
      stats ??
      PlayerAttributes(
        age: age,
        pace: level,
        shot: level,
        pass: level,
        dribble: level,
        defence: level,
        physical: level,
      ),
  location: _at(location),
  preferredPosition: wish,
  worldSeed: 2026,
);

void main() {
  final world = WorldRepository.forSeed(2026);

  group('which pathway', () {
    final cases = [
      // (level, age, location, expected)
      (66, 16, 'nigeria', PathwayKind.academyAbroad),
      (64, 15, 'ghana', PathwayKind.academyAbroad),
      (64, 16, 'spain', PathwayKind.academyHome),
      (66, 17, 'ghana', PathwayKind.seniorAbroad),
      (64, 22, 'japan', PathwayKind.seniorHome),
      (54, 16, 'nigeria', PathwayKind.academyTrials),
      (44, 25, 'ghana', PathwayKind.academyTrials),
      (54, 15, 'england', PathwayKind.homeTrials),
      (44, 19, 'brazil', PathwayKind.homeTrials),
    ];
    for (final (level, age, location, expected) in cases) {
      test('$level at $age in $location → ${expected.id}', () {
        expect(
          pathwayKindFor(_player(level: level, age: age, location: location)),
          expected,
        );
      });
    }
  });

  group('who comes for you', () {
    test('African prodigies: academies from different European countries', () {
      final pathway = pathwayFor(_player(level: 64, age: 16), world);
      expect(pathway.kind, PathwayKind.academyAbroad);
      expect(pathway.options, hasLength(3)); // rare: 3
      for (final o in pathway.options) {
        expect(o.club.hasAcademy, isTrue);
        expect(europeanLeagues, contains(o.club.country));
        expect(o.trial, isNull);
      }
      final countries = pathway.options.map((o) => o.club.country).toSet();
      expect(countries, hasLength(3));
    });

    test('genius gets four offers; France\'s wide net adds one', () {
      expect(pathwayFor(_player(level: 70, age: 16), world).options.length, 4);
      final paris = pathwayFor(
        _player(level: 70, age: 16, location: 'france'),
        world,
      );
      expect(paris.kind, PathwayKind.academyHome);
      expect(paris.options, hasLength(5));
      for (final o in paris.options) {
        expect(o.club.country, LeagueCountry.france);
        expect(o.club.hasAcademy, isTrue);
      }
    });

    test('senior offers: genius Div 1 at home, rare Div 2 abroad', () {
      final home = pathwayFor(
        _player(level: 70, age: 20, location: 'italy'),
        world,
      );
      expect(home.options.every((o) => o.club.division == 1), isTrue);
      expect(
        home.options.every((o) => o.club.country == LeagueCountry.italy),
        isTrue,
      );
      final abroad = pathwayFor(_player(level: 64, age: 20), world);
      expect(abroad.kind, PathwayKind.seniorAbroad);
      expect(abroad.options.every((o) => o.club.division == 2), isTrue);
    });

    test(
      'average trialists in Africa go to bigger clubs\' academies there',
      () {
        final pathway = pathwayFor(_player(level: 54, age: 18), world);
        expect(pathway.kind, PathwayKind.academyTrials);
        expect(pathway.options, hasLength(3));
        for (final o in pathway.options) {
          expect(o.club.division, lessThanOrEqualTo(2));
          expect(academySites['nigeria'], contains(o.site));
          expect(o.name, '${o.club.name} Academy ${o.site}');
          expect(o.trial, isNotNull);
        }
        final poor = pathwayFor(_player(level: 44, age: 18), world);
        expect(poor.options.every((o) => o.club.division >= 2), isTrue);
      },
    );

    test('trials at home: average Div 2–3, poor Div 3, dates in order', () {
      final average = pathwayFor(
        _player(level: 54, age: 18, location: 'england'),
        world,
      );
      expect(average.kind, PathwayKind.homeTrials);
      for (final o in average.options) {
        expect(o.club.country, LeagueCountry.england);
        expect(o.club.division, greaterThanOrEqualTo(2));
        expect(o.site, isNull);
      }
      final dates = [for (final o in average.options) o.trial!.date];
      expect(dates, [...dates]..sort());
      final poor = pathwayFor(
        _player(level: 44, age: 18, location: 'england'),
        world,
      );
      expect(poor.options.every((o) => o.club.division == 3), isTrue);
    });

    test('best fit first, and the same every time', () {
      final player = _player(
        level: 0,
        age: 16,
        stats: const PlayerAttributes(
          age: 16,
          pace: 50,
          shot: 45,
          pass: 75,
          dribble: 75,
          defence: 40,
          physical: 45,
        ),
      );
      expect(player.tier, TalentTier.average);
      final options = pathwayFor(player, world).options;
      final fits = [for (final o in options) o.fit];
      expect(fits, [...fits]..sort((a, b) => b.compareTo(a)));
      expect(
        [for (final o in pathwayFor(player, world).options) o.club.id],
        [for (final o in options) o.club.id],
      );
    });
  });

  test('style fit: key stats against the best skill', () {
    const playmaker = PlayerAttributes(
      age: 18,
      pace: 50,
      shot: 40,
      pass: 80,
      dribble: 70,
      defence: 40,
      physical: 40,
    );
    expect(styleFit(playmaker, ClubStyle.possession), 94); // 75 / 80
    expect(styleFit(playmaker, ClubStyle.direct), 50); // 40 / 80
  });

  test('club fit: style, plus whether the manager plays your wish', () {
    // A playmaker who wants to play centre-back: Traditional managers won't.
    final player = _player(
      level: 0,
      age: 18,
      wish: Position.cb,
      stats: const PlayerAttributes(
        age: 18,
        pace: 50,
        shot: 40,
        pass: 80,
        dribble: 70,
        defence: 40,
        physical: 40,
      ),
    );
    final club = world.clubs.firstWhere(
      (c) =>
          c.style == ClubStyle.direct &&
          c.manager.philosophy == Philosophy.traditional,
    );
    final gap =
        Position.ranked(player.attributes).first.$2 -
        Position.cb.rating(player.attributes);
    final role = (100 - 5 * gap).clamp(0, 100);
    expect(clubFit(player, club), ((3 * 50 + role) / 4).round());
  });

  group('the manager decides the position', () {
    // Winger 62, striker 60: the wish (ST) is 2 below the best.
    const stats = PlayerAttributes(
      age: 18,
      pace: 70,
      shot: 65,
      pass: 50,
      dribble: 65,
      defence: 30,
      physical: 50,
    );
    final best = Position.ranked(stats).first.$1;

    PositionDecision decide(Philosophy p, Position wish) =>
        decidePosition(stats: stats, wish: wish, philosophy: p);

    test('Traditional: always the best fit', () {
      final d = decide(Philosophy.traditional, Position.st);
      expect(d.position, best);
      expect(d.honoured, isFalse);
      expect(d.second, isNull);
      expect(d.reason, contains('whatever you want'));
    });

    test('Modern progressive: the wish within 5', () {
      expect(decide(Philosophy.modernProgressive, Position.st).honoured, true);
      final far = decide(Philosophy.modernProgressive, Position.cb);
      expect(far.gap, greaterThan(5));
      expect(far.position, best);
      expect(far.reason, contains('within 5'));
    });

    test('New hybrid: the wish within 3, plus a second position', () {
      final near = decide(Philosophy.newHybrid, Position.st);
      expect(near.position, Position.st);
      expect(near.second, best);
      final far = decide(Philosophy.newHybrid, Position.cb);
      expect(far.position, best);
      expect(far.second, Position.cb);
      expect(far.reason, contains('rotates'));
      final same = decide(Philosophy.newHybrid, best);
      expect(same.second, Position.ranked(stats)[1].$1);
    });
  });

  group('placement', () {
    test('saves and loads; signing a trial moves to the parent club', () {
      const trial = Placement(
        kind: PathwayKind.academyTrials,
        clubId: 'england-1-0',
        site: 'Lagos',
      );
      final back = Placement.fromJson(trial.toJson())!;
      expect(back.kind, trial.kind);
      expect(back.site, 'Lagos');
      expect(back.signed, isFalse);
      final signed = trial.sign();
      expect(signed.signed, isTrue);
      expect(signed.site, isNull);
      expect(signed.toJson().containsKey('site'), isFalse);
      expect(Placement.fromJson({'kind': 'fame', 'club': 'x'}), isNull);
    });

    test('careerClubOf names the academy while on trial there', () {
      final player = placedPlayer(offers: false);
      final playerWorld = WorldRepository.forSeed(player.worldSeed);
      final club = careerClubOf(player, playerWorld)!;
      expect(club.name, contains(' Academy '));
      final signed = player.withPlacement(player.placement!.sign());
      expect(careerClubOf(signed, playerWorld)!.name, club.club.name);
    });
  });
}
