import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/real_clubs.dart';
import 'package:baller/game/world/world_save_state.dart';

/// How a club plays. Clubs come for players whose best stats suit their style.
enum ClubStyle {
  possession('Possession', [Attribute.pass, Attribute.dribble]),
  highPress('High press', [
    Attribute.pace,
    Attribute.physical,
    Attribute.defence,
  ]),
  counterAttack('Counter-attack', [Attribute.pace, Attribute.shot]),
  direct('Direct', [Attribute.physical, Attribute.shot]),
  lowBlock('Low block', [Attribute.defence, Attribute.physical]);

  const ClubStyle(this.label, this.keyStats);

  final String label;

  /// Stats this style values most.
  final List<Attribute> keyStats;
}

/// A manager's football philosophy. See docs/career-design.md §7.
enum Philosophy {
  traditional(
    'Traditional',
    'Direct and compact. Trusts experience and plays you where you fit best, '
        'whatever you want.',
    preferenceTolerance: null,
    formations: ['4-4-2', '4-5-1'],
    youthTrust: (1, 3),
    styles: [ClubStyle.direct, ClubStyle.lowBlock, ClubStyle.counterAttack],
  ),
  modernProgressive(
    'Modern progressive',
    'Possession and pressing. Gives young players minutes and honours your '
        'preferred position if it is within 5 of your best.',
    preferenceTolerance: 5,
    formations: ['4-3-3', '4-2-3-1'],
    youthTrust: (3, 5),
    styles: [ClubStyle.possession, ClubStyle.highPress],
  ),
  newHybrid(
    'New hybrid',
    'Changes shape for every opponent and rotates a lot. Honours your '
        'preferred position if it is within 3 of your best.',
    preferenceTolerance: 3,
    formations: ['3-5-2', '4-2-3-1', '4-4-2'],
    youthTrust: (2, 4),
    styles: ClubStyle.values,
  );

  const Philosophy(
    this.label,
    this.description, {
    required this.preferenceTolerance,
    required this.formations,
    required this.youthTrust,
    required this.styles,
  });

  final String label;
  final String description;

  /// How close (in rating) the player's preferred position must be to their
  /// best for the manager to play them there. Null: always the best fit.
  final int? preferenceTolerance;
  final List<String> formations;

  /// Range of youth trust stars (1–5).
  final (int, int) youthTrust;

  /// Playing styles this kind of manager sets up.
  final List<ClubStyle> styles;
}

enum Temperament {
  calm('Calm'),
  demanding('Demanding'),
  volatile('Volatile');

  const Temperament(this.label);

  final String label;
}

class Manager {
  const Manager({
    required this.name,
    required this.age,
    required this.nationality,
    required this.philosophy,
    required this.formation,
    required this.youthTrust,
    required this.temperament,
  });

  final String name;
  final int age;
  final Nationality nationality;
  final Philosophy philosophy;
  final String formation;

  /// 1–5 stars.
  final int youthTrust;
  final Temperament temperament;

  String get initials => _initials(name);
}

/// A squad slot. Goalkeepers exist only as background squad members.
enum SquadRole {
  gk('GK', null),
  cb('CB', Position.cb),
  fb('FB', Position.fb),
  dm('DM', Position.dm),
  cm('CM', Position.cm),
  am('AM', Position.am),
  w('W', Position.w),
  st('ST', Position.st);

  const SquadRole(this.code, this.position);

  final String code;
  final Position? position;
}

class SquadPlayer {
  const SquadPlayer({
    required this.name,
    required this.age,
    required this.nationality,
    required this.role,
    required this.rating,
    required this.value,
    this.id = '',
    this.attributes = const PlayerAttributes(
      age: 20,
      pace: 50,
      shot: 50,
      pass: 50,
      dribble: 50,
      defence: 50,
      physical: 50,
    ),
    this.foot = Foot.right,
    this.innateTalent,
    this.logicTalents = const [],
    this.contractYears = 2,
    this.wage = 0,
    this.clubId = '',
    this.squadNumber = 0,
  });

  /// Unique identifier (e.g. "england-1-0-p3").
  final String id;
  final String name;
  final int age;
  final Nationality nationality;
  final SquadRole role;
  final int rating;

  /// Market value in euros.
  final int value;

  /// Full 6-stat + mental attributes, identical to user player make.
  final PlayerAttributes attributes;

  final Foot foot;
  final Talent? innateTalent;
  final List<Talent> logicTalents;

  /// Contract duration remaining in years.
  final int contractYears;

  /// Weekly wage in euros.
  final int wage;

  /// Club ID this player is currently contracted to.
  final String clubId;

  /// Shirt number in the squad.
  final int squadNumber;

  Position? get position => role.position;

  double get talentScore =>
      TalentTier.score(attributes, hasInnate: innateTalent != null);

  TalentTier get tier => TalentTier.of(talentScore);

  SquadPlayer copyWith({
    String? id,
    String? name,
    int? age,
    Nationality? nationality,
    SquadRole? role,
    int? rating,
    int? value,
    PlayerAttributes? attributes,
    Foot? foot,
    Talent? innateTalent,
    List<Talent>? logicTalents,
    int? contractYears,
    int? wage,
    String? clubId,
    int? squadNumber,
  }) => SquadPlayer(
    id: id ?? this.id,
    name: name ?? this.name,
    age: age ?? this.age,
    nationality: nationality ?? this.nationality,
    role: role ?? this.role,
    rating: rating ?? this.rating,
    value: value ?? this.value,
    attributes: attributes ?? this.attributes,
    foot: foot ?? this.foot,
    innateTalent: innateTalent ?? this.innateTalent,
    logicTalents: logicTalents ?? this.logicTalents,
    contractYears: contractYears ?? this.contractYears,
    wage: wage ?? this.wage,
    clubId: clubId ?? this.clubId,
    squadNumber: squadNumber ?? this.squadNumber,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'nationality': nationality.name,
    'role': role.code,
    'rating': rating,
    'value': value,
    'attributes': {
      'age': attributes.age,
      'pace': attributes.pace,
      'shot': attributes.shot,
      'pass': attributes.pass,
      'dribble': attributes.dribble,
      'defence': attributes.defence,
      'physical': attributes.physical,
      'ego': attributes.ego,
      'tacticalDiscipline': attributes.tacticalDiscipline,
      'teamwork': attributes.teamwork,
      'composure': attributes.composure,
      'stamina': attributes.stamina,
    },
    'foot': foot.name,
    'innate': innateTalent?.id,
    'logic': [for (final t in logicTalents) t.id],
    'contractYears': contractYears,
    'wage': wage,
    'clubId': clubId,
    'squadNumber': squadNumber,
  };

  static SquadPlayer? fromJson(
    Object? json, {
    List<Talent> talents = allTalents,
  }) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'age': final int age,
      'nationality': final String natName,
      'role': final String roleCode,
      'rating': final int rating,
      'value': final int value,
      'attributes': final Map<String, Object?> attrMap,
      'foot': final String footName,
    }) {
      final nat = Nationality.values
          .where((n) => n.name == natName)
          .firstOrNull;
      if (nat == null) return null;
      final role = SquadRole.values
          .where((r) => r.code == roleCode)
          .firstOrNull;
      if (role == null) return null;
      final foot = Foot.values.where((f) => f.name == footName).firstOrNull;
      if (foot == null) return null;

      final pace = attrMap['pace'] as int? ?? rating;
      final shot = attrMap['shot'] as int? ?? rating;
      final pass = attrMap['pass'] as int? ?? rating;
      final dribble = attrMap['dribble'] as int? ?? rating;
      final defence = attrMap['defence'] as int? ?? rating;
      final physical = attrMap['physical'] as int? ?? rating;
      final ego = attrMap['ego'] as int? ?? 50;
      final discipline = attrMap['tacticalDiscipline'] as int? ?? 50;
      final teamwork = attrMap['teamwork'] as int? ?? 50;
      final composure = attrMap['composure'] as int? ?? 50;
      final stamina = attrMap['stamina'] as int? ?? 70;

      final attributes = PlayerAttributes(
        age: age,
        pace: pace,
        shot: shot,
        pass: pass,
        dribble: dribble,
        defence: defence,
        physical: physical,
        ego: ego,
        tacticalDiscipline: discipline,
        teamwork: teamwork,
        composure: composure,
        stamina: stamina,
      );

      Talent? innate;
      if (json['innate'] case final String innateId) {
        innate = talents.where((t) => t.id == innateId).firstOrNull;
      }

      final logic = <Talent>[];
      if (json['logic'] case final List<Object?> logicIds) {
        for (final lid in logicIds) {
          if (lid is String) {
            final t = talents.where((x) => x.id == lid).firstOrNull;
            if (t != null) logic.add(t);
          }
        }
      }

      final contractYears = json['contractYears'] as int? ?? 2;
      final wage = json['wage'] as int? ?? 0;
      final clubId = json['clubId'] as String? ?? '';
      final squadNumber = json['squadNumber'] as int? ?? 0;

      return SquadPlayer(
        id: id,
        name: name,
        age: age,
        nationality: nat,
        role: role,
        rating: rating,
        value: value,
        attributes: attributes,
        foot: foot,
        innateTalent: innate,
        logicTalents: List.unmodifiable(logic),
        contractYears: contractYears,
        wage: wage,
        clubId: clubId,
        squadNumber: squadNumber,
      );
    }
    return null;
  }
}

class Club {
  Club({
    required this.id,
    required this.name,
    required this.town,
    required this.country,
    required this.division,
    required this.stars,
    required this.style,
    required this.hasAcademy,
    required this.manager,
    required List<SquadPlayer> squad,
  }) : _squad = List.of(squad);

  final String id;
  final String name;

  /// The fictional town in the club's name, e.g. "Ashbury".
  final String town;
  final LeagueCountry country;

  /// 1, 2 or 3.
  final int division;

  /// Strength, 1–5.
  final int stars;
  final ClubStyle style;
  final bool hasAcademy;
  final Manager manager;

  final List<SquadPlayer> _squad;

  /// Active squad members.
  List<SquadPlayer> get squad => List.unmodifiable(_squad);

  void addPlayer(SquadPlayer player) {
    _squad.add(player);
  }

  bool removePlayer(String playerId) {
    final before = _squad.length;
    _squad.removeWhere((p) => p.id == playerId);
    return _squad.length < before;
  }

  void updatePlayer(SquadPlayer updated) {
    final idx = _squad.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _squad[idx] = updated;
    }
  }

  static const int maxSquadSize = 22;

  String get initials => _initials(name);

  double get averageRating => _squad.isEmpty
      ? 0.0
      : _squad.fold<int>(0, (s, p) => s + p.rating) / _squad.length;

  int get squadValue => _squad.fold<int>(0, (s, p) => s + p.value);
}

class League {
  const League({required this.country, required this.divisions});

  final LeagueCountry country;

  /// Index 0 is Division 1. Each holds [clubsPerDivision] clubs, strongest
  /// first.
  final List<List<Club>> divisions;

  static const int divisionCount = 3;
  static const int clubsPerDivision = 20;

  /// "Premier League" for England's division 1 (1-based [division]).
  static String nameOf(LeagueCountry country, int division) =>
      divisionNames(country)[division - 1].$1;

  /// A short name for tabs ("Segunda").
  static String shortNameOf(LeagueCountry country, int division) =>
      divisionNames(country)[division - 1].$2;

  /// Home and away against every other club.
  static const int matchesPerSeason = (clubsPerDivision - 1) * 2;
  static const int promotionPlaces = 3;
}

/// Every league, generated from one seed.
class World {
  World({required this.seed, required this.leagues});

  final int seed;
  final List<League> leagues;

  late final Map<String, Club> _byId = {
    for (final league in leagues)
      for (final division in league.divisions)
        for (final club in division) club.id: club,
  };

  Club? clubById(String id) => _byId[id];

  Iterable<Club> get clubs => _byId.values;

  /// Looks up any player in the world across all 480 clubs by their unique ID.
  SquadPlayer? playerById(String id) {
    for (final club in clubs) {
      for (final p in club.squad) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  /// Transfers a player from their current club to [toClubId].
  bool transferPlayer({required String playerId, required String toClubId}) {
    final targetClub = clubById(toClubId);
    if (targetClub == null) return false;

    SquadPlayer? player;
    for (final club in clubs) {
      final found = club.squad.where((p) => p.id == playerId).firstOrNull;
      if (found != null) {
        club.removePlayer(playerId);
        player = found;
        break;
      }
    }

    if (player == null) return false;
    final transferred = player.copyWith(
      clubId: toClubId,
      squadNumber: targetClub.squad.length + 1,
    );
    targetClub.addPlayer(transferred);
    return true;
  }

  /// Applies saved transfers and player modifications to this world.
  void applySaveState(WorldSaveState state) {
    for (final modified in state.modifiedPlayers.values) {
      final club = clubById(modified.clubId);
      if (club != null) {
        final existing = club.squad
            .where((p) => p.id == modified.id)
            .firstOrNull;
        if (existing != null) {
          club.updatePlayer(modified);
        } else {
          for (final c in clubs) {
            c.removePlayer(modified.id);
          }
          club.addPlayer(modified);
        }
      }
    }
  }
}

String _initials(String name) {
  final words = name
      .split(' ')
      .where(
        (w) => w.isNotEmpty && RegExp(r'^\p{L}', unicode: true).hasMatch(w),
      )
      .toList();
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
