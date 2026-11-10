import 'dart:convert';
import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/calendar.dart';
import 'package:baller/game/career/contracts.dart';
import 'package:baller/game/career/life_actions.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/life.dart';
import 'package:baller/game/models/match_progress.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/season_progress.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// A senior player signed to a Division 1 club, on that club's contract.
Player _senior({int coach = 50, bool agent = false}) {
  final base = pathwayPlayer(offers: true);
  final world = WorldRepository.forSeed(base.worldSeed);
  final club = world.clubs.firstWhere((c) => c.division == 1);
  final contract = offerContract(
    player: base,
    club: club,
    kind: PathwayKind.seniorHome,
    startSeason: 1,
  );
  return base.copyWith(
    placement: Placement(
      kind: PathwayKind.seniorHome,
      clubId: club.id,
      signed: true,
      contract: contract,
    ),
    status: CareerStatus.initial.apply(
      Effects(coach: coach - CareerStatus.initial.coach),
    ),
    life: Life(agent: agent),
  );
}

void main() {
  group('calendar', () {
    test('matchdays are Saturdays a week apart from early August', () {
      final start = seasonStart(1);
      expect(start.weekday, DateTime.saturday);
      expect(start.month, 8);
      expect(start.day, inInclusiveRange(8, 14));
      for (var r = 0; r < 38; r++) {
        expect(roundDate(1, r).weekday, DateTime.saturday);
      }
      expect(roundDate(1, 1).difference(roundDate(1, 0)).inDays, 7);
      // Season 2 starts the next summer.
      expect(seasonStart(2).year, seasonStart(1).year + 1);
      expect(seasonLabel(1), '2026/27');
    });

    test('paydays are the month ends in between', () {
      expect(paydaysBetween(DateTime(2026, 7), DateTime(2026, 8, 8)), 1);
      expect(paydaysBetween(DateTime(2026, 8, 8), DateTime(2026, 8, 15)), 0);
      expect(paydaysBetween(DateTime(2027, 5, 8), DateTime(2027, 7)), 2);
      expect(payday(DateTime(2026, 2, 3)), DateTime(2026, 2, 28));
      expect(formatDate(DateTime(2026, 8, 8)), 'Sat 8 Aug 2026');
    });
  });

  group('contracts', () {
    test('under-18s at an academy sign a scholarship until 18', () {
      final player = placedPlayer(offers: true); // academy or senior
      final world = WorldRepository.forSeed(player.worldSeed);
      final club = careerClubOf(player, world)!.club;
      final young = player.copyWith(
        attributes: player.attributes.copyWith(age: 16),
      );
      final c = offerContract(
        player: young,
        club: club,
        kind: PathwayKind.academyHome,
        startSeason: 1,
      );
      expect(c.years, 2);
      expect(c.weeklyWage, lessThan(1500));
    });

    test('senior wages follow value; an agent gets 25% more', () {
      final player = _senior();
      final world = WorldRepository.forSeed(player.worldSeed);
      final club = careerClubOf(player, world)!.club;
      final plain = offerContract(
        player: player,
        club: club,
        kind: PathwayKind.seniorHome,
        startSeason: 1,
      );
      final agent = offerContract(
        player: player,
        club: club,
        kind: PathwayKind.seniorHome,
        startSeason: 1,
        agent: true,
      );
      expect(plain.years, 4); // Division 1
      expect(plain.weeklyWage, greaterThanOrEqualTo(300));
      expect(agent.weeklyWage / plain.weeklyWage, closeTo(1.25, 0.02));
    });

    test('an agent takes 15% and finds a sponsor', () {
      final world = WorldRepository.forSeed(_senior().worldSeed);
      final without = monthlyIncome(_senior(), world);
      final withAgent = monthlyIncome(_senior(agent: true), world);
      expect(without.agentFee, 0);
      expect(without.sponsorship, 0);
      expect(withAgent.agentFee, (withAgent.wage * 0.15).round());
      expect(withAgent.sponsorship, greaterThanOrEqualTo(200));
      expect(
        withAgent.total,
        withAgent.wage - withAgent.agentFee + withAgent.sponsorship,
      );
    });
  });

  group('pay', () {
    test('the first matchday pays July; then once a month', () {
      final player = _senior();
      final world = WorldRepository.forSeed(player.worldSeed);
      final income = monthlyIncome(player, world).total;
      final first = payForMatchday(player, world, 1, 0);
      expect(first.status.money, player.status.money + income);
      // Rounds 1 to 3 are all in August: no payday.
      expect(
        payForMatchday(player, world, 1, 2).status.money,
        player.status.money,
      );
      // Over a whole season: July to May, 11 paydays (more with the summer).
      var paid = player;
      for (var r = 0; r < 38; r++) {
        paid = payForMatchday(paid, world, 1, r);
      }
      final months = (paid.status.money - player.status.money) ~/ income;
      expect(months, inInclusiveRange(9, 11));
    });

    test('the summer pays, ages the player and starts a new season', () {
      var player = _senior();
      var progress = SeasonProgress.first;
      for (var i = 0; i < 38; i++) {
        progress = progress.record(1, 0);
      }
      player = player.withSeason(progress);
      final world = WorldRepository.forSeed(player.worldSeed);
      final summer = endOfSeason(player, world);
      expect(summer.player.season.season, 2);
      expect(summer.player.attributes.age, player.attributes.age + 1);
      expect(summer.player.status.money, greaterThan(player.status.money));
      expect(summer.newClub, isNull);
    });
  });

  group('the manager', () {
    test('one talk a week', () {
      final player = _senior();
      const week = 'S1R0';
      final talked = askFeedback(player, week);
      expect(talked.player.life.lastTalk, week);
      expect(canTalk(talked.player, week), isFalse);
      expect(canTalk(talked.player, 'S1R1'), isTrue);
      expect((talked.player.status.coach - player.status.coach).abs(), 5);
    });

    test('requests need a strong relationship', () {
      final weak = _senior(coach: 40);
      final world = WorldRepository.forSeed(weak.worldSeed);
      final raise = askForRaise(weak, world, 'S1R0');
      expect(raise.good, isFalse);
      expect(raise.player.status.coach, 30);
      expect(
        contractOf(raise.player, world)!.weeklyWage,
        contractOf(weak, world)!.weeklyWage,
      );

      final strong = _senior(coach: 80);
      final granted = askForRaise(strong, world, 'S1R0');
      expect(granted.good, isTrue);
      final before = contractOf(strong, world)!.weeklyWage;
      final after = contractOf(granted.player, world)!.weeklyWage;
      expect(after / before, inInclusiveRange(1.09, 1.21));
    });

    test('playing your position: honoured from then on when agreed', () {
      final world = WorldRepository.forSeed(_senior().worldSeed);
      // Find a week where the manager agrees.
      for (var r = 0; r < 20; r++) {
        final player = _senior(coach: 90);
        final career = careerClubOf(player, world)!;
        if (career.decision.honoured) return; // nothing to ask for
        final result = askForPosition(player, world, 'S1R$r');
        if (!result.good) continue;
        final now = careerClubOf(result.player, world)!.decision;
        expect(now.position, player.preferredPosition);
        expect(now.agreed, isTrue);
        return;
      }
      fail('The manager never agreed in 20 weeks');
    });

    test('an agreed move happens at the end of the season', () {
      final player = _senior(coach: 60);
      final world = WorldRepository.forSeed(player.worldSeed);
      final offers = transferOffers(player, world);
      expect(offers, isNotEmpty);
      final current = careerClubOf(player, world)!.club;
      for (final o in offers) {
        expect(o.club.id, isNot(current.id));
        expect(o.club.country, current.country); // no agent: home only
        expect(o.contract.startSeason, 2);
      }
      final agreed = agreeTransfer(player, offers.first, 'S1R3');
      expect(agreed.status.coach, 50);
      expect(agreed.life.transfer!.clubId, offers.first.club.id);

      final done = endOfSeason(agreed, world);
      expect(done.newClub!.id, offers.first.club.id);
      expect(done.player.placement!.clubId, offers.first.club.id);
      expect(
        done.player.placement!.contract!.weeklyWage,
        offers.first.contract.weeklyWage,
      );
      expect(done.player.life.transfer, isNull);
    });
  });

  test('a match left half-way replays exactly', () {
    final player = _senior();
    MatchSim build() =>
        MatchSim(shirtName: 'ME', user: player, random: Random(42));
    final first = build();
    final moves = <String>[];
    final pick = Random(1);
    for (var i = 0; i < 9 && !first.isHalfTime; i++) {
      final pad = first.pad.values.toList();
      final a = pad[pick.nextInt(pad.length)];
      moves.add(a.name);
      first.play(a);
    }
    final again = build();
    for (final m in moves) {
      again.play(MatchAction.values.byName(m));
    }
    expect(again.minute, first.minute);
    expect(
      [again.homeGoals, again.awayGoals],
      [first.homeGoals, first.awayGoals],
    );
    expect(
      again.feed.map((l) => l.text).toList(),
      first.feed.map((l) => l.text).toList(),
    );
  });

  test('contract, life and a match in progress survive saving', () {
    final player = _senior(agent: true).copyWith(
      life: const Life(agent: true, playWish: true, lastTalk: 'S1R2'),
      match: const MatchProgress(
        key: 'season:1:2',
        seed: 99,
        moves: ['shoot', 'pass'],
        secondHalf: true,
      ),
    );
    const codec = PlayerCodec();
    final back = codec.fromJson(jsonDecode(jsonEncode(codec.toJson(player))))!;
    expect(
      back.placement!.contract!.weeklyWage,
      player.placement!.contract!.weeklyWage,
    );
    expect(back.life.agent, isTrue);
    expect(back.life.playWish, isTrue);
    expect(back.life.lastTalk, 'S1R2');
    expect(back.match!.moves, ['shoot', 'pass']);
    expect(back.match!.secondHalf, isTrue);
    final cleared = back.copyWith(clearMatch: true);
    expect(cleared.match, isNull);
  });
}
