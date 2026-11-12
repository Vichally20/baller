import 'dart:math';

import 'package:baller/game/match/ai/behavior_tree/coach_brain.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_factory.dart';
import 'package:baller/game/match/ai/behavior_tree/coach_snapshot.dart';
import 'package:baller/game/match/ai/behavior_tree/tactical_state.dart';
import 'package:baller/game/match/ai/utility_ai/match_decision_context.dart';
import 'package:baller/game/match/ai/utility_ai/pitch_zone.dart';
import 'package:baller/game/match/ai/utility_ai/player_brain.dart';
import 'package:baller/game/match/ai/utility_ai/utility_action.dart';
import 'package:baller/game/match/goal_credit.dart';
import 'package:baller/game/match/lineup.dart';
import 'package:baller/game/match/resolution/contest_outcome.dart';
import 'package:baller/game/match/resolution/momentum.dart';
import 'package:baller/game/match/resolution/stat_contest.dart';
import 'package:baller/game/match/resolution/talent_resolver.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/player_attributes.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';

/// PROVISIONAL NUMBERS. The match screen's flow is decided (two moves per
/// chance, phase follows possession). Moves are settled by stat contests
/// (resolution/stat_contest.dart) and talents (resolution/talent_resolver.dart),
/// but their odds (15–85% contests, foul and concede chances, the weights in
/// the outcome table below) have not been agreed with the designer yet.

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
  const MoveOutcome(
    this.weight,
    this.text,
    this.next, {
    this.goal,
    this.talentName,
  });

  final int weight;
  final String text;
  final PlayState next;
  final Side? goal;

  /// The talent that triggered on this move, if any.
  final String? talentName;
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

/// Position categories for role-specific pitch awareness and prompts.
enum PositionGroup { forward, midfield, defence, goalkeeper }

PositionGroup positionGroupOf(SquadRole role) => switch (role) {
  SquadRole.st || SquadRole.w => PositionGroup.forward,
  SquadRole.am || SquadRole.cm || SquadRole.dm => PositionGroup.midfield,
  SquadRole.cb || SquadRole.fb => PositionGroup.defence,
  SquadRole.gk => PositionGroup.goalkeeper,
};

/// Position-aware scenario prompts seen by the user before choosing a move.
const Map<PositionGroup, Map<PlayState, List<String>>> positionPrompts = {
  PositionGroup.forward: {
    PlayState.attack: [
      'You peel off their centre-back and call for the ball in behind.',
      'The ball drops to you twenty-five yards out with space to turn.',
      'You hold your run on their defensive shoulder, watching the line.',
      'You collect on the edge of the box with defenders closing in.',
    ],
    PlayState.defend: [
      'Their centre-back hesitates on the ball. You step up to press and win it high.',
      'They try to play out from the back. You move to cut off the passing lane.',
      'Their keeper receives a bouncing backpass under pressure. You sprint to close him down.',
      'Their defender looks up to clear. You step up to block the line of the pass.',
    ],
    PlayState.cornerFor: [
      'Corner to your side. You drift towards the penalty spot to challenge.',
      'Your corner. You position yourself in the six-yard box for the delivery.',
      'Corner swung in. You pull off your marker at the back post.',
    ],
    PlayState.cornerAgainst: [
      'Corner to them. You wait on the halfway line, ready to lead the counter-attack.',
      'Their corner. You drop to the near post to help clear the first ball.',
    ],
  },
  PositionGroup.midfield: {
    PlayState.attack: [
      'You collect in the centre circle and scan the pitch for runners.',
      'A pocket of space opens thirty yards out. You drive into it with the ball.',
      'You receive on the half-turn with time to thread a pass into the channel.',
    ],
    PlayState.defend: [
      'Their midfielder receives on the turn. You step up to challenge the passing lane.',
      'They work the ball through the midfield pocket. You track the runner into the channel.',
      'A loose ball breaks in the centre circle. You dive in for the 50-50 challenge.',
    ],
    PlayState.cornerFor: [
      'Corner to your side. You lurk on the edge of the D for the loose clearance.',
      'Your corner. You offer a short option on the angle.',
    ],
    PlayState.cornerAgainst: [
      'Corner to them. You pick up their second-ball runner on the edge of the box.',
      'Their corner. You track their playmaker to deny the cutback.',
    ],
  },
  PositionGroup.defence: {
    PlayState.attack: [
      'You step into midfield with the ball, looking for an opening in their shape.',
      'You switch play with a raking diagonal pass into the opposite flank.',
      'You recycle possession calmly across the backline.',
    ],
    PlayState.defend: [
      'Their winger collects on the halfway line and runs straight at you.',
      'A dangerous cross whips into the box. Their striker is on your shoulder.',
      'A long ball over the top. You and their forward sprint in a pure footrace.',
      'They work it to the edge of your box. You square up to block the shot.',
    ],
    PlayState.cornerFor: [
      'Corner to your side. You bring your height into their six-yard box for the header.',
      'Your corner. You stay back to guard against their breakaway.',
    ],
    PlayState.cornerAgainst: [
      'Corner to them. You grapple with their target man in the six-yard box.',
      'Their corner. You position yourself to attack the near-post delivery.',
    ],
  },
  PositionGroup.goalkeeper: {
    PlayState.attack: [
      'You set the ball down for a goal kick and scan your outfield options.',
      'The ball is played back to your feet. You look for a safe outlet.',
    ],
    PlayState.defend: [
      'Their striker breaks free on goal. You narrow the angle for the 1-on-1.',
      'A looping cross enters your six-yard box. You call for it.',
    ],
    PlayState.cornerFor: [
      'Your corner. You stand on your halfway line, directing the shape.',
    ],
    PlayState.cornerAgainst: [
      'Corner to them. You organize your wall and shout instructions.',
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

/// One goal: who scored it and who set it up. The user is
/// [MatchSim.userId] on the home side.
class MatchGoal {
  const MatchGoal({
    required this.side,
    required this.minute,
    required this.scorer,
    this.assist,
  });

  final Side side;
  final int minute;
  final SquadPlayer scorer;
  final SquadPlayer? assist;
}

class CommentaryLine {
  const CommentaryLine(
    this.minute,
    this.text, {
    this.yourMove = false,
    this.talentName,
    this.isGoal = false,
    this.isTactical = false,
    this.isHighlight = true,
    this.actorSide,
  });

  final int minute;
  final String text;

  /// The result of one of the player's moves (shown bold).
  final bool yourMove;

  /// Non-null if this move triggered a talent.
  final String? talentName;

  /// Whether a goal was scored on this line.
  final bool isGoal;

  /// Whether this was a coach tactical adjustment.
  final bool isTactical;

  /// Major moments (user actions, goals, talents, tactical shifts) are highlights.
  /// Routine AI passes, dribbles, and tackles between chances have isHighlight = false.
  final bool isHighlight;

  /// The side that initiated this action, if known.
  final Side? actorSide;
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
    this.detailedCommentary = true,
    Position? userPosition,
    Random? random,
    int creditSeed = 0,
  }) : _rng = random ?? Random(),
       _credit = Random(creditSeed) {
    _minute = _nextGap();
    _feed.add(const CommentaryLine(0, 'Kick-off.'));

    // 1. The user's footballer.
    final position = userPosition ?? user?.preferredPosition ?? Position.st;
    _userPlayer = user != null
        ? _userToSquadPlayer(user!, position)
        : _defaultUser();

    // 2. Squads, and the eleven who actually play.
    homeSquad = homeClub != null
        ? List.of(homeClub!.squad)
        : _defaultSquad('Home', star: _userPlayer);
    awaySquad = awayClub != null
        ? List.of(awayClub!.squad)
        : _defaultSquad('Away');
    // Each side lines up in its manager's formation; the user takes the
    // slot for their position and their teammates are the other ten.
    homeEleven = pickLineup(
      homeSquad,
      homeClub?.manager.formation ?? defaultFormation,
      userPosition: position,
      userId: _userPlayer.id,
    );
    awayEleven = pickLineup(
      awaySquad,
      awayClub?.manager.formation ?? defaultFormation,
    );
    homeLineup = homeEleven.players;
    awayLineup = awayEleven.players;

    // 3. Coach behaviour trees and tactics.
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
  static const int halfTime = 45;
  static const int fullTime = 90;

  static const _defenders = {SquadRole.cb, SquadRole.fb, SquadRole.dm};
  static const _attackers = {SquadRole.st, SquadRole.w, SquadRole.am};
  static const _midfielders = {SquadRole.cm, SquadRole.am, SquadRole.dm};
  static const _builders = {
    SquadRole.cm,
    SquadRole.am,
    SquadRole.w,
    SquadRole.st,
  };
  static const _outfield = {
    SquadRole.cb,
    SquadRole.fb,
    SquadRole.dm,
    SquadRole.cm,
    SquadRole.am,
    SquadRole.w,
    SquadRole.st,
  };

  final String shirtName;
  final Player? user;
  final Club? homeClub;
  final Club? awayClub;
  final bool detailedCommentary;
  final Random _rng;

  /// Picks who gets credit for goals. Kept apart from [_rng] so crediting
  /// never changes how a match plays out.
  final Random _credit;

  /// The user's id in the lineups and in [goals].
  static const String userId = 'user-player';

  late final SquadPlayer _userPlayer;
  late final List<SquadPlayer> homeSquad;
  late final List<SquadPlayer> awaySquad;

  /// The starting elevens in their formations (the user is a spot in
  /// [homeEleven]).
  late final Lineup homeEleven;
  late final Lineup awayEleven;

  /// The players on the pitch (the home ones without the user).
  late final List<SquadPlayer> homeLineup;
  late final List<SquadPlayer> awayLineup;

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
  bool _atHalfTime = false;

  /// Successful build-up moves (Run, Dribble, Pass) in this attack. Each
  /// takes the ball one zone closer to goal for the next shot.
  int _buildUp = 0;
  bool _secondHalf = false;

  /// The user's last move was a pass that kept the ball: a goal by their
  /// side in the play straight after is their assist.
  bool _userSetUp = false;

  /// When the first chance after the break falls (the clock keeps the
  /// rhythm it had, so half-time costs no chances).
  int _resumeAt = halfTime + 1;
  final List<CommentaryLine> _feed = [];
  final List<MatchGoal> _goals = [];

  /// Every goal so far, in order, with scorer and assist.
  List<MatchGoal> get goals => List.unmodifiable(_goals);

  /// The user in this match (their side is always home).
  SquadPlayer get userPlayer => _userPlayer;

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

  /// Play is stopped for half-time; call [startSecondHalf] to go on.
  bool get isHalfTime => _atHalfTime;
  List<CommentaryLine> get feed => List.unmodifiable(_feed);

  Map<PadDirection, MatchAction> get pad => matchPads[phase]!;

  /// Test helper to evaluate specific state transitions.
  void forceStateForTest(PlayState state) => _state = state;

  String get prompt {
    final group = positionGroupOf(_userPlayer.role);
    final prompts = positionPrompts[group]?[_state] ?? matchPrompts[_state]!;
    return prompts[(_minute + _move) % prompts.length];
  }

  int _nextGap() => 6 + _rng.nextInt(8);

  /// A random player from [lineup] in one of [roles] (any outfield player
  /// if none fits), so different players get involved.
  SquadPlayer _pick(
    List<SquadPlayer> lineup,
    Set<SquadRole> roles, {
    SquadPlayer? except,
  }) {
    final fits = [
      for (final p in lineup)
        if (roles.contains(p.role) && p != except) p,
    ];
    final pool = fits.isNotEmpty
        ? fits
        : [
            for (final p in lineup)
              if (p.role != SquadRole.gk && p != except) p,
          ];
    if (pool.isEmpty) return lineup.isNotEmpty ? lineup.first : _userPlayer;
    return pool[_rng.nextInt(pool.length)];
  }

  /// The side's goalkeeper (the same one all match).
  static SquadPlayer _keeper(List<SquadPlayer> lineup) =>
      lineup.where((p) => p.role == SquadRole.gk).firstOrNull ?? lineup.first;

  /// Plays one move from the current [pad].
  MoveOutcome play(MatchAction action) {
    if (_over) throw StateError('The match is over.');
    if (_atHalfTime) throw StateError('It is half-time.');
    final options = moveOutcomes[_state]![action];
    if (options == null || !pad.containsValue(action)) {
      throw ArgumentError('${action.label} is not on the ${phase.label} pad.');
    }

    // 1. MACRO: coach behaviour trees evaluate.
    _evaluateCoaches();

    // 2. MICRO: resolve the move by stat contest.
    final outcome = _resolvePlayerMove(action, options);

    final goal = outcome.goal;
    if (goal == Side.home) _home++;
    if (goal == Side.away) _away++;
    if (goal == Side.home) {
      // Only Shoot and Nod score for you; a teammate may have set it up.
      _goals.add(
        MatchGoal(
          side: Side.home,
          minute: _minute,
          scorer: _userPlayer,
          assist: _credit.nextDouble() < 0.65
              ? _creditPick(homeLineup, assistWeight)
              : null,
        ),
      );
    } else if (goal == Side.away) {
      _creditGoal(Side.away, awayLineup);
    }
    final changed = outcome.next != _state;
    // Build-up that keeps the ball moves the attack closer to goal; losing
    // it, or any other move, starts again.
    final buildUp = {MatchAction.run, MatchAction.dribble, MatchAction.pass};
    _buildUp =
        _state == PlayState.attack &&
            buildUp.contains(action) &&
            outcome.goal == null &&
            outcome.next == PlayState.attack
        ? _buildUp + 1
        : 0;
    _state = outcome.next;

    _feed.add(
      CommentaryLine(
        _minute,
        outcome.text.replaceAll('{shirt}', shirtName),
        yourMove: true,
        isGoal: goal != null,
        talentName: outcome.talentName,
        actorSide: Side.home,
      ),
    );

    String? notice;
    if (goal != null) {
      notice = _goalNotice(goal);
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
    _buildUp = 0;
    momentum.decay();
    final next = _minute + _nextGap();
    if (!_secondHalf && next >= halfTime) {
      _minute = halfTime;
      _resumeAt = max(next, halfTime + 1);
      _atHalfTime = true;
      _notice = null;
      _feed.add(const CommentaryLine(halfTime, 'Half-time.'));
    } else if (next >= fullTime) {
      _minute = fullTime;
      _over = true;
      _notice = null;
      _feed.add(const CommentaryLine(fullTime, 'Full time.'));
    } else {
      _minute = next;
      _userSetUp =
          action == MatchAction.pass &&
          goal == null &&
          (outcome.next == PlayState.attack ||
              outcome.next == PlayState.cornerFor);
      final npcNotice = _simulateNpcPhase();
      _userSetUp = false;
      _notice = [?notice, ?npcNotice, "Next chance $_minute'"].join(' · ');
    }
    return outcome;
  }

  /// Restarts play after the break. The other side kicks off the second
  /// half (you kicked off the first).
  void startSecondHalf() {
    if (!_atHalfTime) throw StateError('It is not half-time.');
    _atHalfTime = false;
    _secondHalf = true;
    _move = 0;
    _state = PlayState.defend;
    _feed.add(const CommentaryLine(halfTime, 'Second half under way.'));
    _minute = _resumeAt;
    final npcNotice = _simulateNpcPhase();
    _notice = ['Second half', ?npcNotice, "Next chance $_minute'"].join(' · ');
  }

  /// [base] moved one zone towards goal per build-up move, up to the box.
  PitchZone _advanced(PitchZone base) =>
      PitchZone.values[min(base.index + _buildUp, PitchZone.opponentBox.index)];

  String _goalNotice(Side scorer) =>
      '${scorer == Side.home ? 'GOAL' : 'Conceded'} · $_home–$_away';

  /// A goal by [side] that the commentary doesn't pin on anyone: scorer
  /// and assist drawn from [lineup] by role and skill.
  void _creditGoal(Side side, List<SquadPlayer> lineup) {
    final scorer = _creditPick(lineup, scorerWeight);
    if (scorer == null) return;
    _goals.add(
      MatchGoal(
        side: side,
        minute: _minute,
        scorer: scorer,
        assist: _credit.nextDouble() < 0.7
            ? _creditPick(lineup, assistWeight, except: scorer)
            : null,
      ),
    );
  }

  SquadPlayer? _creditPick(
    List<SquadPlayer> lineup,
    double Function(SquadPlayer) weight, {
    SquadPlayer? except,
  }) => weightedPick(
    [
      for (final p in lineup)
        if (p != except && p.id != userId) p,
    ],
    weight,
    _credit,
  );

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

    void report(TacticalState tactics, String before, String who) {
      final reason = tactics.lastAdjustmentReason;
      if (tactics.tacticName == before || reason == null) return;
      _feed.add(
        CommentaryLine(
          _minute,
          'Tactical shift: $reason (${tactics.tacticName}, $who)',
          isTactical: true,
        ),
      );
    }

    report(homeTactics, prevHomeTactic, 'your coach');
    report(awayTactics, prevAwayTactic, 'their coach');
  }

  static MoveOutcome _fromContest(ContestOutcome o) => MoveOutcome(
    1,
    o.text,
    o.nextState,
    goal: o.scoringSide,
    talentName: o.talentName,
  );

  MoveOutcome _resolvePlayerMove(
    MatchAction action,
    List<MoveOutcome> fallbacks,
  ) {
    final keeper = _keeper(awayLineup);
    final defender = _pick(awayLineup, _defenders);
    final attacker = _pick(awayLineup, _attackers);

    final isForward =
        positionGroupOf(_userPlayer.role) == PositionGroup.forward;
    final isMidfielder =
        positionGroupOf(_userPlayer.role) == PositionGroup.midfield;

    // Who the user faces depends on where they play:
    // Forwards face their defenders/GK when pressing or attacking.
    // Midfielders face their central midfielders / pivots.
    // Defenders face their attackers (wingers / strikers).
    final targetOpponent = isForward
        ? defender
        : (isMidfielder ? _pick(awayLineup, _midfielders) : attacker);

    // Defending your own box at their corner: every move is about clearing
    // it (Shoot is a clearance, not a shot at their goal).
    if (_state == PlayState.cornerAgainst) {
      return _pickStatWeighted(fallbacks, action, defender, attacker);
    }

    final zone = switch (_state) {
      PlayState.attack => _advanced(
        isForward
            ? PitchZone.finalThird
            : (isMidfielder ? PitchZone.attackingThird : PitchZone.midfield),
      ),
      PlayState.cornerFor => PitchZone.opponentBox,
      PlayState.cornerAgainst => PitchZone.ownBox,
      PlayState.defend =>
        isForward
            ? PitchZone.attackingThird
            : (isMidfielder ? PitchZone.midfield : PitchZone.ownHalf),
    };

    switch (action) {
      case MatchAction.shoot:
        return _fromContest(
          StatContestResolver.resolveShot(
            shooter: _userPlayer,
            goalkeeper: keeper,
            zone: zone,
            attackingSide: Side.home,
            momentum: momentum,
            rng: _rng,
            isUser: true,
          ),
        );

      case MatchAction.pass:
        return _fromContest(
          StatContestResolver.resolvePass(
            passer: _userPlayer,
            receiver: _pick(homeLineup, _outfield),
            defender: defender,
            attackingSide: Side.home,
            momentum: momentum,
            rng: _rng,
            isUser: true,
          ),
        );

      case MatchAction.dribble:
        return _fromContest(
          StatContestResolver.resolveDribble(
            dribbler: _userPlayer,
            defender: defender,
            attackingSide: Side.home,
            momentum: momentum,
            rng: _rng,
            isUser: true,
          ),
        );

      case MatchAction.tackle:
      case MatchAction.slide:
        return _fromContest(
          StatContestResolver.resolveTackle(
            defender: _userPlayer,
            attacker: targetOpponent,
            defendingSide: Side.home,
            momentum: momentum,
            rng: _rng,
            isSlide: action == MatchAction.slide,
            isHighPress: isForward,
            isUser: true,
          ),
        );

      case MatchAction.run:
      case MatchAction.mark:
      case MatchAction.shadow:
      case MatchAction.nod:
        return _pickStatWeighted(fallbacks, action, defender, attacker);
    }
  }

  /// Settles a move from the outcome table: a stat contest (or a talent)
  /// decides whether it goes well, then one of the good or bad outcomes is
  /// picked by its weight.
  MoveOutcome _pickStatWeighted(
    List<MoveOutcome> options,
    MatchAction action,
    SquadPlayer defender,
    SquadPlayer attacker,
  ) {
    final ownBox = _state == PlayState.cornerAgainst;
    final isForward =
        positionGroupOf(_userPlayer.role) == PositionGroup.forward;

    final talentTrigger = TalentResolver.checkTalents(
      TalentActivationContext(
        actor: _userPlayer,
        action: action,
        zone: switch (_state) {
          PlayState.cornerFor => PitchZone.opponentBox,
          PlayState.cornerAgainst => PitchZone.ownBox,
          PlayState.defend =>
            isForward ? PitchZone.attackingThird : PitchZone.ownHalf,
          _ => PitchZone.attackingThird,
        },
        goalkeeper: defender,
        defender: defender,
        momentum: momentum,
        rng: _rng,
      ),
    );

    final me = _userPlayer.attributes;
    bool contest(int mine, int theirs) => StatContestResolver.rollContest(
      attackStat: mine,
      defendStat: theirs,
      momentumMultiplier: momentum.multiplierFor(Side.home),
      rng: _rng,
    );

    final bool success;
    if (talentTrigger != null) {
      success = true;
    } else {
      success = switch (action) {
        MatchAction.run => contest(me.pace, defender.attributes.pace),
        // Attacking header against a defender; defensive one against their
        // forward.
        MatchAction.nod => contest(
          me.physical,
          (ownBox ? attacker : defender).attributes.physical,
        ),
        MatchAction.mark || MatchAction.shadow => contest(
          (me.defence * 0.7 + me.physical * 0.3).round(),
          attacker.attributes.pace,
        ),
        // Only reached in your own box: a clearance.
        MatchAction.shoot => contest(me.physical, attacker.attributes.physical),
        // Playing out of your own box under pressure.
        MatchAction.pass => contest(me.pass, attacker.attributes.defence),
        _ => _rng.nextBool(),
      };
    }

    // Good for you: you score, keep the ball, win it, or win a corner.
    bool good(MoveOutcome o) =>
        o.goal == Side.home ||
        (o.goal == null &&
            (o.next == PlayState.attack || o.next == PlayState.cornerFor));
    final goodOnes = options.where(good).toList();
    final badOnes = options.where((o) => !good(o)).toList();

    // A forward pressing high in PlayState.defend doesn't concede immediate goals on a missed mark/shadow
    final filteredBadOnes = (isForward && _state == PlayState.defend)
        ? badOnes.where((o) => o.goal != Side.away).toList()
        : badOnes;
    final effectiveBadOnes = filteredBadOnes.isNotEmpty
        ? filteredBadOnes
        : badOnes;

    final pool = success
        ? (goodOnes.isNotEmpty ? goodOnes : effectiveBadOnes)
        : (effectiveBadOnes.isNotEmpty ? effectiveBadOnes : goodOnes);

    final total = pool.fold(0, (sum, o) => sum + o.weight);
    var roll = _rng.nextInt(total);
    var chosen = pool.last;
    for (final o in pool) {
      if (roll < o.weight) {
        chosen = o;
        break;
      }
      roll -= o.weight;
    }

    final prefix = talentTrigger != null && success
        ? '${talentTrigger.announcement} '
        : '';
    return MoveOutcome(
      chosen.weight,
      '$prefix${chosen.text}',
      chosen.next,
      goal: chosen.goal,
      talentName: talentTrigger?.talent.name,
    );
  }

  /// The other 21 players between the user's chances: one decision by
  /// whoever has the ball. Returns a notice if it changes the score.
  String? _simulateNpcPhase() {
    // Your corner counts as your side attacking.
    final homeAttacking =
        _state == PlayState.attack || _state == PlayState.cornerFor;
    final lineup = homeAttacking ? homeLineup : awayLineup;
    final opposing = homeAttacking ? awayLineup : homeLineup;
    final tactics = homeAttacking ? homeTactics : awayTactics;
    final side = homeAttacking ? Side.home : Side.away;
    if (lineup.isEmpty || opposing.isEmpty) return null;

    final carrier = _pick(lineup, _builders);
    final decision = PlayerBrain.decide(
      MatchDecisionContext(
        actor: carrier,
        ballZone: homeAttacking ? PitchZone.midfield : PitchZone.attackingThird,
        tactics: tactics,
        teammates: lineup,
        opponents: opposing,
      ),
    );

    void recordNpcOutcome(ContestOutcome outcome) {
      if (outcome.talentName != null) {
        _feed.add(
          CommentaryLine(
            _minute,
            outcome.text,
            talentName: outcome.talentName,
            isHighlight: true,
            actorSide: side,
          ),
        );
      } else if (detailedCommentary) {
        _feed.add(
          CommentaryLine(
            _minute,
            outcome.text,
            isHighlight: false,
            actorSide: side,
          ),
        );
      }
    }

    /// A shot by [shooter]: a goal changes the score and restarts play.
    String? shot(SquadPlayer shooter, PitchZone zone, {SquadPlayer? setUp}) {
      final outcome = StatContestResolver.resolveShot(
        shooter: shooter,
        goalkeeper: _keeper(opposing),
        zone: zone,
        attackingSide: side,
        momentum: momentum,
        rng: _rng,
      );
      final scorer = outcome.scoringSide;
      if (scorer == null) {
        recordNpcOutcome(outcome);
        return null;
      }
      if (scorer == Side.home) {
        _home++;
      } else {
        _away++;
      }
      _goals.add(
        MatchGoal(
          side: scorer,
          minute: _minute,
          scorer: shooter,
          assist: scorer == Side.home && _userSetUp
              ? _userPlayer
              : (setUp == shooter ? null : setUp),
        ),
      );
      _feed.add(
        CommentaryLine(
          _minute,
          outcome.text,
          isGoal: true,
          talentName: outcome.talentName,
          isHighlight: true,
          actorSide: side,
        ),
      );
      // The side that conceded kicks off.
      _state = scorer == Side.home ? PlayState.defend : PlayState.attack;
      return _goalNotice(scorer);
    }

    /// A move that comes off can end in a chance for one of the forwards:
    /// more often for the stronger side.
    String? maybeChance(ContestOutcome build, {SquadPlayer? passer}) {
      final cameOff =
          build.result == ContestResult.passCompleted ||
          build.result == ContestResult.dribbleSuccess;
      if (!cameOff) return null;
      if (_rng.nextDouble() >= _chanceRate(lineup, opposing)) return null;
      return shot(
        _pick(lineup, _attackers),
        PitchZone.opponentBox,
        setUp: passer,
      );
    }

    switch (decision.type) {
      case CandidateActionType.shoot:
        return shot(carrier, PitchZone.attackingThird);

      case CandidateActionType.throughBall:
      case CandidateActionType.shortPass:
        final pass = StatContestResolver.resolvePass(
          passer: carrier,
          receiver:
              decision.target ?? _pick(lineup, _outfield, except: carrier),
          defender: _pick(opposing, {SquadRole.cb, SquadRole.dm}),
          attackingSide: side,
          momentum: momentum,
          rng: _rng,
        );
        recordNpcOutcome(pass);
        return maybeChance(pass, passer: carrier);

      case CandidateActionType.dribble:
        final dribble = StatContestResolver.resolveDribble(
          dribbler: carrier,
          defender: _pick(opposing, {SquadRole.fb, SquadRole.cb}),
          attackingSide: side,
          momentum: momentum,
          rng: _rng,
        );
        recordNpcOutcome(dribble);
        return maybeChance(dribble);

      default:
        return null;
    }
  }

  /// How often a team's move between your chances turns into a shot:
  /// [baseChanceRate] for evenly matched elevens, ±4% per rating point of
  /// difference, between 15% and 80%.
  static const double baseChanceRate = 0.5;

  static double _chanceRate(
    List<SquadPlayer> attacking,
    List<SquadPlayer> defending,
  ) {
    double average(List<SquadPlayer> xi) =>
        xi.fold(0, (s, p) => s + p.rating) / max(1, xi.length);
    final gap = average(attacking) - average(defending);
    return (baseChanceRate * pow(1.04, gap)).clamp(0.15, 0.8).toDouble();
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

  static SquadPlayer _userToSquadPlayer(Player user, Position position) =>
      SquadPlayer(
        id: 'user-player',
        name: user.identity.shirtName.isNotEmpty
            ? user.identity.shirtName
            : user.identity.name,
        age: user.attributes.age,
        nationality:
            Nationality.values
                .where(
                  (n) =>
                      n.label.toLowerCase() ==
                      user.location.country.toLowerCase(),
                )
                .firstOrNull ??
            Nationality.english,
        role:
            SquadRole.values.where((r) => r.position == position).firstOrNull ??
            SquadRole.st,
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
