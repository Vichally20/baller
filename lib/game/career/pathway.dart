import 'dart:math';

import 'package:baller/game/career/position_decision.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

/// Players younger than this go to academies; older ones get senior offers.
const int academyAgeLimit = 17;

/// The oldest a player can be and still play youth (U18) football.
const int youthMaxAge = 18;

/// Whether a signed player plays youth football rather than for the
/// club's senior side: academy and trial signings do while they're
/// [youthMaxAge] or younger; senior contracts never do.
bool playsYouthFootball(Player player, Placement placement) =>
    placement.kind != PathwayKind.seniorHome &&
    placement.kind != PathwayKind.seniorAbroad &&
    player.attributes.age <= youthMaxAge;

/// Where African players' offers and academy trials come from.
const europeanLeagues = [
  LeagueCountry.england,
  LeagueCountry.spain,
  LeagueCountry.germany,
  LeagueCountry.france,
  LeagueCountry.italy,
];

/// Cities where foreign clubs run academies, per starting country.
const academySites = {
  'nigeria': ['Lagos', 'Ibadan', 'Abuja', 'Port Harcourt'],
  'ghana': ['Accra', 'Kumasi', 'Tema', 'Cape Coast'],
};

/// The pathway for this player: offers for rare and genius talents, trials
/// for everyone else; abroad from Africa, at home elsewhere.
PathwayKind pathwayKindFor(Player player) {
  final africa = player.location.region == Region.africa;
  final gifted =
      player.tier == TalentTier.rare || player.tier == TalentTier.genius;
  if (!gifted) {
    return africa ? PathwayKind.academyTrials : PathwayKind.homeTrials;
  }
  if (player.attributes.age < academyAgeLimit) {
    return africa ? PathwayKind.academyAbroad : PathwayKind.academyHome;
  }
  return africa ? PathwayKind.seniorAbroad : PathwayKind.seniorHome;
}

/// The league in the player's starting country (none in Nigeria or Ghana).
LeagueCountry? homeLeagueOf(Location location) {
  for (final country in LeagueCountry.values) {
    if (country.name == location.id) return country;
  }
  return null;
}

/// How well a club's style suits the player, 0–100: the player's average in
/// the stats the style values, against their single best skill.
int styleFit(PlayerAttributes stats, ClubStyle style) {
  final best = Attribute.values
      .where((a) => a.isSkill)
      .map((a) => stats[a])
      .reduce(max);
  final average =
      style.keyStats.fold(0, (sum, a) => sum + stats[a]) /
      style.keyStats.length;
  return (100 * average / best).round().clamp(0, 100);
}

/// Overall fit with a club, 0–100, shown on offers and trials: three parts
/// style fit, one part whether its manager would play the player where they
/// want (5 off per rating point their wish is below where they'd play).
int clubFit(Player player, Club club) {
  final decision = decidePosition(
    stats: player.attributes,
    wish: player.preferredPosition,
    philosophy: club.manager.philosophy,
  );
  final role = decision.honoured ? 100 : max(0, 100 - 5 * decision.gap);
  return ((3 * styleFit(player.attributes, club.style) + role) / 4).round();
}

/// An open trial's details.
class TrialInfo {
  const TrialInfo({
    required this.date,
    required this.trialists,
    required this.places,
  });

  /// Day of the month (the month starts on a Monday).
  final int date;
  final int trialists;
  final int places;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  String get day => _days[(date - 1) % 7];
}

/// One offer or trial on the pathway screen.
class Opportunity {
  const Opportunity({
    required this.club,
    required this.fit,
    required this.decision,
    required this.detail,
    this.site,
    this.trial,
  });

  final Club club;

  /// Style fit, 0–100.
  final int fit;

  /// Where this club's manager would play the player.
  final PositionDecision decision;

  /// What the offer includes, the manager's pitch, or the trial's size.
  final String detail;

  /// African academy city, for academy trials.
  final String? site;
  final TrialInfo? trial;

  String get name => academyName(club, site);
}

/// "Ashbury Rovers Academy Lagos", or just the club's name.
String academyName(Club club, String? site) =>
    site == null ? club.name : '${club.name} Academy $site';

class Pathway {
  const Pathway({required this.kind, required this.options});

  final PathwayKind kind;

  /// Best style fit first.
  final List<Opportunity> options;
}

/// The offers or trials open to [player] in [world]. The same player and
/// world always give the same list.
Pathway pathwayFor(Player player, World world) {
  final kind = pathwayKindFor(player);
  final tier = player.tier;
  final genius = tier == TalentTier.genius;
  final average = tier == TalentTier.average;
  final home = homeLeagueOf(player.location);
  final rng = Random(player.worldSeed ^ 0x2545F491);

  bool european(Club c) => europeanLeagues.contains(c.country);
  bool domestic(Club c) => c.country == home;
  final bool Function(Club) eligible = switch (kind) {
    PathwayKind.academyAbroad => (c) => european(c) && c.hasAcademy,
    PathwayKind.academyHome => (c) => domestic(c) && c.hasAcademy,
    // Genius: Div 1 reserve sides too. Rare: Div 2.
    PathwayKind.seniorAbroad => (
      c,
    ) => european(c) && (genius ? c.division <= 2 : c.division == 2),
    // Genius: Div 1. Rare: Div 1–2.
    PathwayKind.seniorHome => (
      c,
    ) => domestic(c) && (genius ? c.division == 1 : c.division <= 2),
    // Average: the bigger clubs' academies. Poor: the smaller clubs'.
    PathwayKind.academyTrials => (
      c,
    ) => european(c) && (average ? c.division <= 2 : c.division >= 2),
    PathwayKind.homeTrials => (
      c,
    ) => domestic(c) && (average ? c.division >= 2 : c.division == 3),
  };

  final count =
      (kind.offers ? (genius ? 4 : 3) : 3) +
      (player.location.perk == CountryPerk.wideNet ? 1 : 0);
  // Fit decides most; offers lean towards stronger clubs (genius most of
  // all), and a little chance keeps every career different.
  final starWeight = !kind.offers
      ? 0
      : genius
      ? 6
      : 3;
  final scored = [
    for (final club in world.clubs.where(eligible))
      () {
        final fit = clubFit(player, club);
        return (
          club: club,
          fit: fit,
          score: fit + club.stars * starWeight + rng.nextInt(13),
        );
      }(),
  ]..sort((a, b) => b.score.compareTo(a.score));

  // Abroad, offers come from different countries where possible.
  final picked = <({Club club, int fit, int score})>[];
  for (final relaxed in [false, true]) {
    for (final s in scored) {
      if (picked.length == count) break;
      if (picked.contains(s)) continue;
      if (kind.abroad &&
          !relaxed &&
          picked.any((p) => p.club.country == s.club.country)) {
        continue;
      }
      picked.add(s);
    }
  }
  picked.sort((a, b) {
    final byFit = b.fit.compareTo(a.fit);
    return byFit != 0 ? byFit : b.club.stars.compareTo(a.club.stars);
  });

  final dates = <int>{};
  while (dates.length < picked.length) {
    dates.add(3 + rng.nextInt(25));
  }
  final sortedDates = dates.toList()..sort();
  final sites = academySites[player.location.id];

  return Pathway(
    kind: kind,
    options: [
      for (final (i, p) in picked.indexed)
        () {
          final trial = kind.trials
              ? TrialInfo(
                  date: sortedDates[i],
                  // Bigger clubs draw bigger crowds of hopefuls.
                  trialists: 20 + p.club.stars * 15 + rng.nextInt(5) * 5,
                  places: 2 + rng.nextInt(4),
                )
              : null;
          return Opportunity(
            club: p.club,
            fit: p.fit,
            decision: decidePosition(
              stats: player.attributes,
              wish: player.preferredPosition,
              philosophy: p.club.manager.philosophy,
            ),
            site: kind == PathwayKind.academyTrials && sites != null
                ? sites[rng.nextInt(sites.length)]
                : null,
            trial: trial,
            detail: trial != null
                ? '${trial.trialists} trialists · ${trial.places} places'
                : _offerDetail(kind, p.club, genius: genius, rng: rng),
          );
        }(),
    ],
  );
}

String _offerDetail(
  PathwayKind kind,
  Club club, {
  required bool genius,
  required Random rng,
}) => switch (kind) {
  PathwayKind.academyAbroad => switch (club.country) {
    LeagueCountry.england => 'U18 academy · boarding house · school included',
    LeagueCountry.spain => 'U18 academy · host family · Spanish lessons',
    LeagueCountry.germany => 'U19 academy · club flat · clear B-team route',
    LeagueCountry.france => 'U19 academy · academy campus · French lessons',
    LeagueCountry.italy => 'U19 academy · club residence · Italian lessons',
    _ => 'Youth academy · club housing',
  },
  PathwayKind.academyHome => () {
    final pitches = _pitches[club.manager.philosophy]!;
    return pitches[rng.nextInt(pitches.length)];
  }(),
  PathwayKind.seniorAbroad =>
    club.division == 1
        ? 'Reserve side · trains with the first team'
        : 'First-team contract · 3 years',
  PathwayKind.seniorHome =>
    club.division == 1 && !genius
        ? 'B-team contract · first-team training'
        : club.division == 1
        ? 'First-team contract · 4 years'
        : 'First-team contract · 3 years',
  PathwayKind.academyTrials || PathwayKind.homeTrials => '',
};

/// What each kind of manager says when lobbying a young player.
const _pitches = {
  Philosophy.traditional: [
    '"We do not promise. We work."',
    '"Earn your place, and it stays yours."',
  ],
  Philosophy.modernProgressive: [
    '"You will train with the first team by 18."',
    '"Our best players came through this academy."',
  ],
  Philosophy.newHybrid: [
    '"Here you play. Every week."',
    '"We will find more than one way to use you."',
  ],
};

/// The club a career is attached to, and where its manager plays the player.
class CareerClub {
  const CareerClub({
    required this.club,
    required this.placement,
    required this.decision,
  });

  final Club club;
  final Placement placement;
  final PositionDecision decision;

  /// The academy's name while on trial there, otherwise the club's.
  String get name => academyName(club, placement.site);
}

/// Null before a pathway is chosen, or if the save's club is unknown.
CareerClub? careerClubOf(Player player, World world) {
  final placement = player.placement;
  if (placement == null) return null;
  final club = world.clubById(placement.clubId);
  if (club == null) return null;
  final decision = decidePosition(
    stats: player.attributes,
    wish: player.preferredPosition,
    philosophy: club.manager.philosophy,
  );
  return CareerClub(
    club: club,
    placement: placement,
    // The manager may have agreed to play the player where they want.
    decision: player.life.playWish && !decision.honoured
        ? decision.agreeToWish()
        : decision,
  );
}
