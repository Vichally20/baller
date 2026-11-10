/// How a career begins, from the talent tier, age and country.
/// See docs/career-design.md §5.
enum PathwayKind {
  /// Africa, rare/genius, under 17: European club academies.
  academyAbroad('academy_abroad', offers: true, abroad: true),

  /// Elsewhere, rare/genius, under 17: home academies compete to sign you.
  academyHome('academy_home', offers: true),

  /// Africa, rare/genius, 17+: European reserve and second-division sides.
  seniorAbroad('senior_abroad', offers: true, abroad: true),

  /// Elsewhere, rare/genius, 17+: senior or B-team contracts at home.
  seniorHome('senior_home', offers: true),

  /// Africa, average/poor: trials at foreign clubs' African academies.
  academyTrials('academy_trials', offers: false, abroad: true),

  /// Elsewhere, average/poor: open trials at lower-division clubs at home.
  homeTrials('home_trials', offers: false);

  const PathwayKind(this.id, {required this.offers, this.abroad = false});

  /// Used in saves and in chapter conditions.
  final String id;

  /// Clubs make offers; otherwise the player trials.
  final bool offers;

  /// The club is in another country.
  final bool abroad;

  bool get trials => !offers;

  /// Whether a chapter condition value ("offers", "trials" or a kind id)
  /// covers this pathway.
  bool matches(String condition) =>
      condition == id || condition == (offers ? 'offers' : 'trials');

  /// Every value a chapter's "pathway" condition accepts.
  static final Set<String> conditionValues = {
    'offers',
    'trials',
    for (final k in values) k.id,
  };

  static PathwayKind? byId(String id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// A playing contract: weekly wage in euros, and how many seasons it runs.
class Contract {
  const Contract({
    required this.weeklyWage,
    required this.years,
    required this.startSeason,
  });

  final int weeklyWage;
  final int years;

  /// The season (1-based) the contract starts in.
  final int startSeason;

  /// The last season it covers.
  int get endSeason => startSeason + years - 1;

  /// Paid on the last day of every month.
  int get monthlyWage => (weeklyWage * 52 / 12).round();

  Contract withWeeklyWage(int wage) =>
      Contract(weeklyWage: wage, years: years, startSeason: startSeason);

  Map<String, Object?> toJson() => {
    'wage': weeklyWage,
    'years': years,
    'start': startSeason,
  };

  /// Null when [json] is malformed.
  static Contract? fromJson(Object? json) {
    if (json
        case {
          'wage': final int wage,
          'years': final int years,
          'start': final int start,
        }
        when wage >= 0 && years >= 1 && start >= 1) {
      return Contract(weeklyWage: wage, years: years, startSeason: start);
    }
    return null;
  }
}

/// The club a career is attached to: signed, or on trial there.
class Placement {
  const Placement({
    required this.kind,
    required this.clubId,
    this.site,
    this.signed = false,
    this.contract,
  });

  final PathwayKind kind;
  final String clubId;

  /// City of the club's African academy, for academy trials ("Lagos").
  final String? site;

  /// False while the player is still on trial.
  final bool signed;

  /// Wage and length; null while on trial (and in saves from before
  /// contracts, which get one worked out when needed).
  final Contract? contract;

  /// After a successful trial: signed on [contract], and an African academy
  /// trialist moves to the parent club.
  Placement sign([Contract? contract]) => Placement(
    kind: kind,
    clubId: clubId,
    signed: true,
    contract: contract ?? this.contract,
  );

  Placement withContract(Contract contract) => Placement(
    kind: kind,
    clubId: clubId,
    site: site,
    signed: signed,
    contract: contract,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.id,
    'club': clubId,
    'site': ?site,
    'signed': signed,
    'contract': ?contract?.toJson(),
  };

  /// Null when [json] is malformed.
  static Placement? fromJson(Object? json) {
    if (json
        case {
          'kind': final String kindId,
          'club': final String clubId,
          'signed': final bool signed,
        }
        when clubId.isNotEmpty) {
      final kind = PathwayKind.byId(kindId);
      final site = json['site'];
      if (kind == null || (site != null && site is! String)) return null;
      Contract? contract;
      if (json['contract'] case final Object raw) {
        contract = Contract.fromJson(raw);
        if (contract == null) return null;
      }
      return Placement(
        kind: kind,
        clubId: clubId,
        site: site as String?,
        signed: signed,
        contract: contract,
      );
    }
    return null;
  }
}
