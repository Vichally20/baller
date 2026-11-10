import 'dart:math';

import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/position_decision.dart';
import 'package:baller/game/models/life.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';

/// Contracts, wages and transfers (PROVISIONAL numbers, to tune).
///
/// - Under-18s at academies or after a trial sign a scholarship until 18:
///   (€120 + €60 per club star) a week, times the league's money factor.
/// - Everyone else earns a share of their market value a year (10% in
///   Division 1, 8% in 2, 6% in 3), at least €300 a week. First-team deals
///   run 4 years in Division 1 and 3 below; post-trial deals 2.
/// - An agent gets 25% more on every contract, finds a monthly sponsor
///   worth 0.2% of the player's value, and takes [agentCut] of the wages.

/// Share of market value paid in wages a year, by division index.
const List<double> wageShare = [0.10, 0.08, 0.06];

/// How much more an agent negotiates.
const double agentBonus = 1.25;

bool _youth(PathwayKind kind) =>
    kind != PathwayKind.seniorHome && kind != PathwayKind.seniorAbroad;

int _roundWage(num euros) => max(10, (euros / 10).round() * 10);

/// What [club] offers [player], starting in [startSeason].
Contract offerContract({
  required Player player,
  required Club club,
  required PathwayKind kind,
  required int startSeason,
  bool agent = false,
}) {
  final age = player.attributes.age;
  final double weekly;
  final int years;
  if (_youth(kind) && age < 18) {
    weekly = (120 + club.stars * 60) * club.country.valueMultiplier;
    years = (18 - age).clamp(1, 3);
  } else {
    final value = playerMarketValue(player, club: club);
    weekly = max(300, value * wageShare[club.division - 1] / 52);
    years = kind.trials ? 2 : (club.division == 1 ? 4 : 3);
  }
  return Contract(
    weeklyWage: _roundWage(agent ? weekly * agentBonus : weekly),
    years: years,
    startSeason: startSeason,
  );
}

/// The player's contract: the one they signed, or (for saves from before
/// contracts) the one their club would have offered. Null before signing.
Contract? contractOf(Player player, World world) {
  final career = careerClubOf(player, world);
  if (career == null || !career.placement.signed) return null;
  return career.placement.contract ??
      offerContract(
        player: player,
        club: career.club,
        kind: career.placement.kind,
        startSeason: 1,
      );
}

/// What lands in the account on each payday.
class MonthlyIncome {
  const MonthlyIncome({this.wage = 0, this.agentFee = 0, this.sponsorship = 0});

  static const none = MonthlyIncome();

  final int wage;
  final int agentFee;
  final int sponsorship;

  int get total => wage - agentFee + sponsorship;
}

/// A sponsor's monthly payment, found by an agent: 0.2% of market value,
/// between €200 and €50,000.
int sponsorshipFor(int marketValue) =>
    _roundWage((marketValue * 0.002).clamp(200, 50000));

MonthlyIncome monthlyIncome(Player player, World world) {
  final contract = contractOf(player, world);
  if (contract == null) return MonthlyIncome.none;
  final wage = contract.monthlyWage;
  if (!player.life.agent) return MonthlyIncome(wage: wage);
  final club = careerClubOf(player, world)!.club;
  return MonthlyIncome(
    wage: wage,
    agentFee: (wage * agentCut).round(),
    sponsorship: sponsorshipFor(playerMarketValue(player, club: club)),
  );
}

/// A club that wants to sign the player at the end of the season.
class TransferOffer {
  const TransferOffer({
    required this.club,
    required this.kind,
    required this.contract,
    required this.fit,
    required this.decision,
  });

  final Club club;
  final PathwayKind kind;
  final Contract contract;
  final int fit;
  final PositionDecision decision;
}

/// Up to three clubs about the player's level that would sign them for
/// next season. Without an agent they come from the same country; an
/// agent finds clubs abroad too.
List<TransferOffer> transferOffers(Player player, World world) {
  final career = careerClubOf(player, world);
  if (career == null) return const [];
  final current = career.club;
  final rating = Position.ranked(player.attributes).first.$2;
  final home = homeLeagueOf(player.location);
  final rng = Random(player.worldSeed ^ (player.season.season * 7349 + 11));

  List<Club> near(double range) => [
    for (final c in world.clubs)
      if (c.id != current.id &&
          (player.life.agent || c.country == current.country) &&
          (c.averageRating - rating).abs() <= range)
        c,
  ];
  var candidates = near(6);
  if (candidates.length < 3) candidates = near(12);
  if (candidates.length < 3) candidates = near(40);

  final scored =
      [
        for (final c in candidates)
          (club: c, fit: clubFit(player, c), roll: rng.nextInt(12)),
      ]..sort(
        (a, b) => (b.fit + b.club.stars * 2 + b.roll).compareTo(
          a.fit + a.club.stars * 2 + a.roll,
        ),
      );

  return [
    for (final s in scored.take(3))
      () {
        final kind = s.club.country == home
            ? PathwayKind.seniorHome
            : PathwayKind.seniorAbroad;
        return TransferOffer(
          club: s.club,
          kind: kind,
          fit: s.fit,
          contract: offerContract(
            player: player,
            club: s.club,
            kind: kind,
            startSeason: player.season.season + 1,
            agent: player.life.agent,
          ),
          decision: decidePosition(
            stats: player.attributes,
            wish: player.preferredPosition,
            philosophy: s.club.manager.philosophy,
          ),
        );
      }(),
  ];
}

/// "€450", "€12,500".
String formatWage(int euros) {
  final digits = euros.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '€$out';
}

/// "€450 a week · 3 years".
String contractSummary(Contract c) =>
    '${formatWage(c.weeklyWage)} a week · ${c.years} '
    '${c.years == 1 ? 'year' : 'years'}';
