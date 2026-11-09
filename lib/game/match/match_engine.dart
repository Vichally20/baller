import 'dart:math';

import 'package:baller/game/match/ai/behavior_tree/coach_brain.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_factory.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_snapshot.dart';
import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/ai/utility_ai/player_brain.dart';
import 'package:baller/game/match/ai/utility_ai/utility_action.dart';
import 'package:baller/game/match/resolution/contest_outcome.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/match/resolution/stat_contest.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

/// PLACEHOLDER MECHANICS. The match screen's flow is decided (two moves per
/// chance, phase follows possession), but what each move does is not: the
/// outcome weights below are stand-ins until stat checks and talents are
/// designed.

/// Which control pad is showing.
enum MatchPhase {
  attack('Attack'),
  defend('Defend'),
  box('In box');

  const MatchPhase(this.label);

  final String label;
}

/// Who has the ball, or whose corner it is. Decides the [MatchPhase].
enum PlayState {
  /// Your team has the ball.
  attack(MatchPhase.attack),

  /// The opposition has the ball.
  defend(MatchPhase.defend),

  /// Corner to your team.
  cornerFor(MatchPhase.box),

  /// Corner to the opposition.
  cornerAgainst(MatchPhase.box);

  const PlayState(this.phase);

  final MatchPhase phase;
}

enum PadDirection { up, left, right, down }

enum MatchAction {
  run('Run'),
  pass('Pass'),
  shoot('Shoot'),
  dribble('Dribble'),
  mark('Mark'),
  slide('Slide'),
  shadow('Shadow'),
  tackle('Tackle'),
  nod('Nod');

  const MatchAction(this.label);

  final String label;
}

/// The four moves on each phase's pad.
const Map<MatchPhase, Map<PadDirection, MatchAction>> matchPads = {
  MatchPhase.attack: {
    PadDirection.up: MatchAction.run,
    PadDirection.left: MatchAction.pass,
    PadDirection.right: MatchAction.shoot,
    PadDirection.down: MatchAction.dribble,
  },
  MatchPhase.defend: {
    PadDirection.up: MatchAction.mark,
    PadDirection.left: MatchAction.slide,
    PadDirection.right: MatchAction.shadow,
    PadDirection.down: MatchAction.tackle,
  },
  MatchPhase.box: {
    PadDirection.up: MatchAction.nod,
    PadDirection.left: MatchAction.pass,
    PadDirection.right: MatchAction.shoot,
    PadDirection.down: MatchAction.mark,
  },
};

enum Side { home, away }

/// One possible result of a move. `{shirt}` in [text] is the player's
/// shirt name.
class MoveOutcome {
  const MoveOutcome(this.weight, this.text, this.next, {this.goal});

  final int weight;
  final String text;
  final PlayState next;
  final Side? goal;
}

const _a = PlayState.attack;
const _d = PlayState.defend;
const _cf = PlayState.cornerFor;
const _ca = PlayState.cornerAgainst;

/// Placeholder outcome table: every state × every move on its pad.
const Map<PlayState, Map<MatchAction, List<MoveOutcome>>> moveOutcomes = {
  PlayState.attack: {
    MatchAction.run: [
      MoveOutcome(6, '{shirt} spins in behind and is played through.', _a),
      MoveOutcome(4, '{shirt} goes too early. Flag up, offside.', _d),
    ],
    MatchAction.pass: [
      MoveOutcome(7, '{shirt} threads it into the channel. Still yours.', _a),
      MoveOutcome(3, 'Intercepted. They read the pass.', _d),
    ],
    MatchAction.dribble: [
      MoveOutcome(5, '{shirt} drops a shoulder and is past his man.', _a),
      MoveOutcome(
        2,
        '{shirt} beats one, the next blocks it behind. Corner.',
        _cf,
      ),
      MoveOutcome(3, 'Tackled. They break the other way.', _d),
    ],
    MatchAction.shoot: [
      MoveOutcome(3, '{shirt} lets fly… GOAL!', _d, goal: Side.home),
      MoveOutcome(4, 'Tipped round the post. Corner.', _cf),
      MoveOutcome(3, 'Wide. Goal kick.', _d),
    ],
  },
  PlayState.defend: {
    MatchAction.mark: [
      MoveOutcome(
        6,
        '{shirt} sticks tight. The pass goes astray and you pick it up.',
        _a,
      ),
      MoveOutcome(4, 'His man slips him. They keep it.', _d),
    ],
    MatchAction.slide: [
      MoveOutcome(5, 'Perfectly timed slide from {shirt}. Ball won.', _a),
      MoveOutcome(3, '{shirt} slides it out for a corner.', _ca),
      MoveOutcome(
        2,
        'Missed him. They are through… and score.',
        _a,
        goal: Side.away,
      ),
    ],
    MatchAction.shadow: [
      MoveOutcome(
        5,
        '{shirt} shows him outside and he runs it out. Your throw.',
        _a,
      ),
      MoveOutcome(3, 'He cuts back inside. They recycle it.', _d),
      MoveOutcome(2, 'The cross is blocked behind. Corner to them.', _ca),
    ],
    MatchAction.tackle: [
      MoveOutcome(6, 'Clean tackle. {shirt} comes away with it.', _a),
      MoveOutcome(2, 'Beaten. The shot deflects behind for a corner.', _ca),
      MoveOutcome(
        2,
        'Beaten, and they finish it. Goal for them.',
        _a,
        goal: Side.away,
      ),
    ],
  },
  PlayState.cornerFor: {
    MatchAction.nod: [
      MoveOutcome(3, '{shirt} rises highest… GOAL!', _d, goal: Side.home),
      MoveOutcome(4, 'Header over the bar. Goal kick.', _d),
      MoveOutcome(3, 'The keeper punches it out, back to your side.', _a),
    ],
    MatchAction.pass: [
      MoveOutcome(
        6,
        'Short corner. {shirt} works it back to the full-back.',
        _a,
      ),
      MoveOutcome(4, 'The short corner is read. They clear.', _d),
    ],
    MatchAction.shoot: [
      MoveOutcome(
        2,
        'It falls to {shirt} on the volley… GOAL!',
        _d,
        goal: Side.home,
      ),
      MoveOutcome(4, 'Volley blocked. Another corner.', _cf),
      MoveOutcome(4, 'Scuffed. They clear.', _d),
    ],
    MatchAction.mark: [
      MoveOutcome(
        6,
        '{shirt} hangs back and kills their counter before it starts.',
        _a,
      ),
      MoveOutcome(4, 'Corner cleared. They break.', _d),
    ],
  },
  PlayState.cornerAgainst: {
    MatchAction.nod: [
      MoveOutcome(6, '{shirt} heads it clear and you break.', _a),
      MoveOutcome(
        4,
        'The header only reaches the edge of the box. Theirs again.',
        _d,
      ),
    ],
    MatchAction.pass: [
      MoveOutcome(5, 'It drops to {shirt}, who finds a teammate.', _a),
      MoveOutcome(5, '{shirt} tries to play out and gives it back.', _d),
    ],
    MatchAction.shoot: [
      MoveOutcome(6, '{shirt} smashes it clear.', _a),
      MoveOutcome(4, 'The clearance skews off. Another corner.', _ca),
    ],
    MatchAction.mark: [
      MoveOutcome(6, '{shirt} marks his man out of it. The keeper claims.', _a),
      MoveOutcome(2, 'His man gets free… goal for them.', _a, goal: Side.away),
      MoveOutcome(2, 'Blocked behind. Another corner.', _ca),
    ],
  },
};

/// What the player sees before choosing a move, per state.
const Map<PlayState, List<String>> matchPrompts = {
  PlayState.attack: [
    "You have it on the left. The full-back steps up and there's grass "
        'behind him.',
    'The ball drops to you thirty yards out. Two of them close in.',
    'You collect in the middle with time to turn.',
  ],
  PlayState.defend: [
    'Their winger collects on the halfway line and runs straight at you.',
    'They work it into the box. Their striker is on your shoulder.',
    'A long ball over the top. You and their forward race for it.',
  ],
  PlayState.cornerFor: [
    'Corner to your side. You drift towards the penalty spot.',
    'Your corner. They pack the six-yard box.',
  ],
  PlayState.cornerAgainst: [
    'Corner to them. You pick up their tallest man.',
    'Their corner. The keeper is shouting at everyone.',
  ],
};

/// Shown when play switches pads (or someone scores).
String _switchNotice(PlayState next) => switch (next) {
  PlayState.attack => 'Ball won · Attack',
  PlayState.defend => 'Possession lost · Defend',
  PlayState.cornerFor => 'Corner to you · In box',
  PlayState.cornerAgainst => 'Corner to them · In box',
};

class CommentaryLine {
  const CommentaryLine(this.minute, this.text, {this.yourMove = false});

  final int minute;
  final String text;

  /// The result of one of the player's moves (shown bold).
  final bool yourMove;
}

/// One match, played as a series of chances. Each chance gives the player
/// [movesPerChance] moves; each move resolves at once and can change who
/// has the ball, which changes the pad.
class MatchSim {
  MatchSim({
    required this.shirtName,
    this.user,
    this.homeClub,
    this.awayClub,
    Random? random,
  }) : _rng = random ?? Random() {
    _minute = _nextGap();
    _feed.add(const CommentaryLine(0, 'Kick-off.'));

    // 1. Initialize user footballer
    _userPlayer = user != null ? _userToSquadPlayer(user!) : _defaultUser();

    // 2. Initialize squads
    homeSquad = homeClub != null
        ? List.of(homeClub!.squad)
        : _defaultSquad('Home', star: _userPlayer);
    awaySquad = awayClub != null
        ? List.of(awayClub!.squad)
        : _defaultSquad('Away');

    // 3. Initialize Coach Behavior Trees & Tactics
    homeCoach = homeClub != null
        ? CoachFactory.createForManager(homeClub!.manager)
        : CoachBrain(coachName: 'Home Coach');
    awayCoach = awayClub != null
        ? CoachFactory.createForManager(awayClub!.manager)
        : CoachBrain(coachName: 'Away Coach');

    homeTactics = homeClub != null
        ? TacticalState.fromStyle(homeClub!.style)
        : TacticalState.fromStyle(ClubStyle.possession);
    awayTactics = awayClub != null
        ? TacticalState.fromStyle(awayClub!.style)
        : TacticalState.fromStyle(ClubStyle.counterAttack);
  }

  static const int movesPerChance = 2;
  static const int fullTime = 90;

  final String shirtName;
  final Player? user;
  final Club? homeClub;
  final Club? awayClub;
  final Random _rng;

  late final SquadPlayer _userPlayer;
  late final List<SquadPlayer> homeSquad;
  late final List<SquadPlayer> awaySquad;

  late final CoachBrain homeCoach;
  late final CoachBrain awayCoach;
  late final TacticalState homeTactics;
  late final TacticalState awayTactics;
  final MatchMomentum momentum = MatchMomentum();

  int _minute = 0;
  PlayState _state = PlayState.attack;
  int _move = 0;
  int _home = 0;
  int _away = 0;
  String? _notice;
  bool _over = false;
  final List<CommentaryLine> _feed = [];

  int get minute => _minute;
  PlayState get state => _state;
  MatchPhase get phase => _state.phase;

  /// 0-based move within the current chance.
  int get move => _move;
  int get homeGoals => _home;
  int get awayGoals => _away;

  /// Why the pad just changed, a goal, or the next chance's minute.
  String? get notice => _notice;
  bool get isOver => _over;
  List<CommentaryLine> get feed => List.unmodifiable(_feed);

  Map<PadDirection, MatchAction> get pad => matchPads[phase]!;

  String get prompt {
    final prompts = matchPrompts[_state]!;
    return prompts[(_minute + _move) % prompts.length];
  }

  int _nextGap() => 6 + _rng.nextInt(8);

  /// Plays one move from the current [pad].
  MoveOutcome play(MatchAction action) {
    if (_over) throw StateError('The match is over.');
    final options = moveOutcomes[_state]![action];
    if (options == null || !pad.containsValue(action)) {
      throw ArgumentError('${action.label} is not on the ${phase.label} pad.');
    }

    // 1. MACRO: Coach Behavior Trees evaluate
    _evaluateCoaches();

    // 2. MICRO: Resolve the action via stat contest
    final outcome = _resolvePlayerMove(action, options);

    _feed.add(
      CommentaryLine(
        _minute,
        outcome.text.replaceAll('{shirt}', shirtName),
        yourMove: true,
      ),
    );

    final goal = outcome.goal;
    if (goal == Side.home) _home++;
    if (goal == Side.away) _away++;
    final changed = outcome.next != _state;
    _state = outcome.next;

    String? notice;
    if (goal != null) {
      notice = '${goal == Side.home ? 'GOAL' : 'Conceded'} · $_home–$_away';
    } else if (changed) {
      notice = _switchNotice(_state);
    }

    final chanceOver = goal != null || _move == movesPerChance - 1;
    if (!chanceOver) {
      _move++;
      _notice = notice;
      return outcome;
    }

    _move = 0;
    final next = _minute + _nextGap();
    if (next >= fullTime) {
      _minute = fullTime;
      _over = true;
      _notice = null;
      _feed.add(const CommentaryLine(fullTime, 'Full time.'));
    } else {
      _minute = next;
      _simulateNpcPhase();
      _notice = [?notice, "Next chance $_minute'"].join(' · ');
    }
    return outcome;
  }

  void _evaluateCoaches() {
    final prevHomeTactic = homeTactics.tacticName;
    final prevAwayTactic = awayTactics.tacticName;

    homeCoach.evaluate(
      CoachSnapshot(
        minute: _minute,
        goalDifference: _home - _away,
        possessionPercentage: 50.0 + (momentum.home - 0.5) * 20.0,
        tactics: homeTactics,
      ),
    );

    awayCoach.evaluate(
      CoachSnapshot(
        minute: _minute,
        goalDifference: _away - _home,
        possessionPercentage: 50.0 + (momentum.away - 0.5) * 20.0,
        tactics: awayTactics,
      ),
    );

    if (homeTactics.tacticName != prevHomeTactic && homeTactics.lastAdjustmentReason != null) {
      _feed.add(
        CommentaryLine(
          _minute,
          'Tactical shift: ${homeTactics.lastAdjustmentReason} (${homeTactics.tacticName})',
        ),
      );
    }
  }

  MoveOutcome _resolvePlayerMove(MatchAction action, List<MoveOutcome> fallbacks) {
    final awayGk = awaySquad.where((p) => p.role == SquadRole.gk).firstOrNull ?? awaySquad.first;
    final awayDef = awaySquad.where((p) => p.role == SquadRole.cb || p.role == SquadRole.fb).firstOrNull ?? awaySquad.first;
    final awayAttacker = awaySquad.where((p) => p.role == SquadRole.st || p.role == SquadRole.w).firstOrNull ?? awaySquad.last;

    final zone = switch (_state) {
      PlayState.attack => PitchZone.finalThird,
      PlayState.cornerFor => PitchZone.opponentBox,
      PlayState.cornerAgainst => PitchZone.ownBox,
      PlayState.defend => PitchZone.ownHalf,
    };

    switch (action) {
      case MatchAction.shoot:
        final outcome = StatContestResolver.resolveShot(
          shooter: _userPlayer,
          goalkeeper: awayGk,
          zone: zone,
          attackingSide: Side.home,
          momentum: momentum,
          rng: _rng,
          isUser: true,
        );
        return MoveOutcome(
          1,
          outcome.text,
          outcome.nextState,
          goal: outcome.scoringSide,
        );

      case MatchAction.pass:
        final openTeammate = homeSquad
            .where((p) => p.id != _userPlayer.id && p.role != SquadRole.gk)
            .firstOrNull ?? _userPlayer;
        final outcome = StatContestResolver.resolvePass(
          passer: _userPlayer,
          receiver: openTeammate,
          defender: awayDef,
          attackingSide: Side.home,
          momentum: momentum,
          rng: _rng,
          isUser: true,
        );
        return MoveOutcome(
          1,
          outcome.text,
          outcome.nextState,
          goal: outcome.scoringSide,
        );

      case MatchAction.dribble:
        final outcome = StatContestResolver.resolveDribble(
          dribbler: _userPlayer,
          defender: awayDef,
          attackingSide: Side.home,
          momentum: momentum,
          rng: _rng,
          isUser: true,
        );
        return MoveOutcome(
          1,
          outcome.text,
          outcome.nextState,
          goal: outcome.scoringSide,
        );

      case MatchAction.tackle:
      case MatchAction.slide:
        final outcome = StatContestResolver.resolveTackle(
          defender: _userPlayer,
          attacker: awayAttacker,
          defendingSide: Side.home,
          momentum: momentum,
          rng: _rng,
          isSlide: action == MatchAction.slide,
          isUser: true,
        );
        return MoveOutcome(
          1,
          outcome.text,
          outcome.nextState,
          goal: outcome.scoringSide,
        );

      case MatchAction.run:
      case MatchAction.mark:
      case MatchAction.shadow:
      case MatchAction.nod:
        return _pickStatWeighted(fallbacks, action, awayDef, awayAttacker);
    }
  }

  MoveOutcome _pickStatWeighted(
    List<MoveOutcome> options,
    MatchAction action,
    SquadPlayer defender,
    SquadPlayer attacker,
  ) {
    final bool rollSuccess;
    switch (action) {
      case MatchAction.run:
        rollSuccess = StatContestResolver.rollContest(
          attackStat: _userPlayer.attributes.pace,
          defendStat: defender.attributes.pace,
          rng: _rng,
        );
        break;
      case MatchAction.nod:
        rollSuccess = StatContestResolver.rollContest(
          attackStat: _userPlayer.attributes.physical,
          defendStat: defender.attributes.physical,
          rng: _rng,
        );
        break;
      case MatchAction.mark:
      case MatchAction.shadow:
        rollSuccess = StatContestResolver.rollContest(
          attackStat: (_userPlayer.attributes.defence * 0.7 + _userPlayer.attributes.physical * 0.3).round(),
          defendStat: attacker.attributes.pace,
          rng: _rng,
        );
        break;
      default:
        rollSuccess = _rng.nextBool();
    }

    if (rollSuccess) {
      // Pick first positive outcome (retains possession or goal)
      final favorable = options.where((o) => o.next == PlayState.attack || o.goal != null).toList();
      if (favorable.isNotEmpty) return favorable.first;
    } else {
      // Pick turnover outcome
      final unfavorable = options.where((o) => o.next == PlayState.defend || o.goal == Side.away).toList();
      if (unfavorable.isNotEmpty) return unfavorable.first;
    }
    return options.first;
  }

  void _simulateNpcPhase() {
    // Teammate or opponent decision
    final activeSquad = _state == PlayState.attack ? homeSquad : awaySquad;
    final opposingSquad = _state == PlayState.attack ? awaySquad : homeSquad;
    final activeTactics = _state == PlayState.attack ? homeTactics : awayTactics;

    final ballCarrier = activeSquad
        .where((p) => p.id != _userPlayer.id && p.role != SquadRole.gk)
        .firstOrNull;

    if (ballCarrier != null) {
      final context = MatchDecisionContext(
        actor: ballCarrier,
        ballZone: _state == PlayState.attack ? PitchZone.midfield : PitchZone.attackingThird,
        tactics: activeTactics,
        teammates: activeSquad,
        opponents: opposingSquad,
      );

      final decision = PlayerBrain.decide(context);
      if (decision.type == CandidateActionType.shoot) {
        final gk = opposingSquad.where((p) => p.role == SquadRole.gk).firstOrNull ?? opposingSquad.first;
        final outcome = StatContestResolver.resolveShot(
          shooter: ballCarrier,
          goalkeeper: gk,
          zone: PitchZone.attackingThird,
          attackingSide: _state == PlayState.attack ? Side.home : Side.away,
          momentum: momentum,
          rng: _rng,
        );
        if (outcome.isGoal) {
          if (outcome.scoringSide == Side.home) {
            _home++;
            _feed.add(CommentaryLine(_minute, outcome.text));
          } else {
            _away++;
            _feed.add(CommentaryLine(_minute, outcome.text));
          }
        }
      }
    }
  }

  SquadPlayer _defaultUser() => SquadPlayer(
    id: 'user-player',
    name: shirtName.isNotEmpty ? shirtName : 'Player',
    age: 20,
    nationality: Nationality.english,
    role: SquadRole.st,
    rating: 70,
    value: 1000000,
    attributes: const PlayerAttributes(
      age: 20,
      pace: 72,
      shot: 74,
      pass: 68,
      dribble: 70,
      defence: 45,
      physical: 70,
      ego: 65,
      tacticalDiscipline: 60,
    ),
  );

  static SquadPlayer _userToSquadPlayer(Player user) => SquadPlayer(
    id: 'user-player',
    name: user.identity.shirtName.isNotEmpty ? user.identity.shirtName : user.identity.name,
    age: user.attributes.age,
    nationality: Nationality.values
            .where((n) =>
                n.label.toLowerCase() == user.location.country.toLowerCase())
            .firstOrNull ??
        Nationality.english,
    role: SquadRole.values.where((r) => r.position == user.preferredPosition).firstOrNull ?? SquadRole.st,
    rating: Position.ranked(user.attributes).first.$2,
    value: 1000000,
    attributes: user.attributes,
    foot: user.identity.foot,
    innateTalent: user.innateTalent,
    logicTalents: user.logicTalents,
  );

  static List<SquadPlayer> _defaultSquad(String prefix, {SquadPlayer? star}) {
    const roles = [
      SquadRole.gk,
      SquadRole.cb,
      SquadRole.cb,
      SquadRole.fb,
      SquadRole.fb,
      SquadRole.dm,
      SquadRole.cm,
      SquadRole.am,
      SquadRole.w,
      SquadRole.w,
      SquadRole.st,
    ];
    return [
      for (final (i, role) in roles.indexed)
        if (i == 10 && star != null)
          star
        else
          SquadPlayer(
            id: '$prefix-p$i',
            name: '$prefix Player ${i + 1}',
            age: 23,
            nationality: Nationality.english,
            role: role,
            rating: 68,
            value: 800000,
            attributes: PlayerAttributes(
              age: 23,
              pace: 68,
              shot: 68,
              pass: 68,
              dribble: 68,
              defence: 68,
              physical: 68,
            ),
          ),
    ];
  }
}
