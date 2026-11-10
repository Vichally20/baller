import 'dart:math';

import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/npc_generator.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';

/// The two sides in one of the story's matches. The player plays for [home].
class Matchup {
  const Matchup({
    required this.home,
    required this.away,
    required this.userPosition,
  });

  final Club home;
  final Club away;

  /// Where the player's manager plays them.
  final Position userPosition;
}

/// Builds the sides for the story match at [eventIndex].
///
/// - Players signed on a senior pathway play for their club's real squad,
///   against a club from the same division.
/// - Academy players and trialists play youth or trial football: both
///   sides are generated around the player's own rating, coached by their
///   club's manager and the opponent club's. The opponent keeps the story's
///   name ([opponentName], e.g. "The other trialists").
///
/// In season mode [fixture] gives the opponent club.
///
/// The same player and match always give the same sides. Null before a
/// pathway is chosen.
Matchup? matchupFor(
  Player player,
  World world, {
  required String opponentName,
  required int eventIndex,
  Fixture? fixture,
}) {
  final career = careerClubOf(player, world);
  if (career == null) return null;
  final club = career.club;
  final rng = Random(player.worldSeed ^ (eventIndex * 7919 + 17));

  final rivals = [
    for (final c
        in world.leagues
            .firstWhere((l) => l.country == club.country)
            .divisions[club.division - 1])
      if (c.id != club.id) c,
  ];
  // A league fixture names the opponent; a story match draws one.
  final rival = fixture == null
      ? rivals[rng.nextInt(rivals.length)]
      : (fixture.home.id == club.id ? fixture.away : fixture.home);

  final placement = career.placement;
  final senior =
      placement.signed &&
      (placement.kind == PathwayKind.seniorHome ||
          placement.kind == PathwayKind.seniorAbroad);
  final position = career.decision.position;
  if (senior) {
    return Matchup(home: club, away: rival, userPosition: position);
  }

  // Youth or trial football, at the player's level.
  final level = Position.ranked(player.attributes).first.$2;
  final academy =
      placement.kind == PathwayKind.academyAbroad ||
      placement.kind == PathwayKind.academyHome ||
      placement.kind == PathwayKind.academyTrials;
  final local = placement.site != null
      ? (_african[player.location.id] ?? club.country.nationality)
      : club.country.nationality;

  Club side(Club basis, String id, String name) => Club(
    id: id,
    name: name,
    town: basis.town,
    country: basis.country,
    division: basis.division,
    stars: basis.stars,
    style: basis.style,
    hasAcademy: basis.hasAcademy,
    manager: basis.manager,
    squad: youthSquad(
      idPrefix: id,
      level: level,
      country: basis.country,
      nationality: local,
      minAge: academy ? 15 : 16,
      maxAge: academy ? 18 : 24,
      rng: rng,
    ),
  );

  return Matchup(
    home: side(club, '${club.id}-youth', career.name),
    away: side(rival, '${rival.id}-youth', opponentName),
    userPosition: position,
  );
}

const _african = {
  'nigeria': Nationality.nigerian,
  'ghana': Nationality.ghanaian,
};

/// One keeper short of a full squad: 2 GK, 3 CB, 3 FB, 1 DM, 2 CM, 1 AM,
/// 2 W, 2 ST.
const _youthShape = [
  (SquadRole.gk, 2),
  (SquadRole.cb, 3),
  (SquadRole.fb, 3),
  (SquadRole.dm, 1),
  (SquadRole.cm, 2),
  (SquadRole.am, 1),
  (SquadRole.w, 2),
  (SquadRole.st, 2),
];

/// A generated youth or trial squad rated around [level] (±3), mostly of
/// [nationality].
List<SquadPlayer> youthSquad({
  required String idPrefix,
  required int level,
  required LeagueCountry country,
  required Nationality nationality,
  required int minAge,
  required int maxAge,
  required Random rng,
}) {
  var n = 0;
  return [
    for (final (role, count) in _youthShape)
      for (var i = 0; i < count; i++)
        () {
          final rating = (level + rng.nextInt(7) - 3).clamp(30, 95);
          final age = minAge + rng.nextInt(maxAge - minAge + 1);
          final from = rng.nextDouble() < 0.8
              ? nationality
              : Nationality.values[rng.nextInt(Nationality.values.length)];
          final (innate, logic) = NpcGenerator.generateTalents(rating, rng);
          return SquadPlayer(
            id: '$idPrefix-p${n++}',
            name: from.randomName(rng),
            age: age,
            nationality: from,
            role: role,
            rating: rating,
            value: marketValue(
              rating: rating,
              age: age,
              leagueMultiplier: country.valueMultiplier,
              divisionMultiplier: 1,
            ),
            attributes: NpcGenerator.generateAttributes(
              role: role,
              rating: rating,
              age: age,
              rng: rng,
            ),
            foot: NpcGenerator.generateFoot(role, rng),
            innateTalent: innate,
            logicTalents: logic,
          );
        }(),
  ];
}
