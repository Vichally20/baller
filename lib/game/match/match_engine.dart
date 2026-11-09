import 'dart:math';

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
  MatchSim({required this.shirtName, Random? random})
    : _rng = random ?? Random() {
    _minute = _nextGap();
    _feed.add(const CommentaryLine(0, 'Kick-off.'));
  }

  static const int movesPerChance = 2;
  static const int fullTime = 90;

  final String shirtName;
  final Random _rng;

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
    final outcome = _pick(options);
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
      _notice = [?notice, "Next chance $_minute'"].join(' · ');
    }
    return outcome;
  }

  MoveOutcome _pick(List<MoveOutcome> options) {
    final total = options.fold(0, (sum, o) => sum + o.weight);
    var roll = _rng.nextInt(total);
    for (final o in options) {
      if (roll < o.weight) return o;
      roll -= o.weight;
    }
    return options.last; // unreachable
  }
}
