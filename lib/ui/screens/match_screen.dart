import 'dart:async';
import 'dart:math';

import 'package:baller/data/career_store.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/growth.dart';
import 'package:baller/game/career/life_actions.dart';
import 'package:baller/game/match/autopilot.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/matchup.dart';
import 'package:baller/game/models/match_progress.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/season_progress.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:baller/ui/screens/match_report_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// A match, played as a run of chances. Each chance gives two moves on a
/// line-cross pad; the pad follows the play (Attack with the ball, Defend
/// without it, In box at corners). Progress is saved at full time.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.player,
    required this.slot,
    required this.event,
    this.matchup,
    this.seed,
    this.simulate = false,
  });

  final Player player;
  final int slot;
  final MatchEvent event;

  /// The sides, as shown on the line-ups (worked out here if not given).
  final Matchup? matchup;

  /// Fixes the match's random seed (tests). Otherwise a new match gets a
  /// fresh seed, and a match left half-way keeps its saved one.
  final int? seed;

  /// Plays the whole match at once, picking the player's moves for them.
  final bool simulate;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  /// Your side and theirs, built from your club and the story's opponent.
  late final Matchup? _matchup =
      widget.matchup ??
      matchupFor(
        widget.player,
        WorldRepository.forSeed(widget.player.worldSeed),
        opponentName: widget.event.match.opponent,
        eventIndex: widget.player.status.eventIndex,
      );

  /// Saved after every move, so leaving and coming back carries on. A
  /// match left half-way is picked up from its seed and moves.
  late MatchProgress _progress = () {
    final key = matchKey(widget.player, widget.event);
    final saved = widget.player.match;
    return saved != null && saved.key == key
        ? saved
        : MatchProgress(
            key: key,
            seed: widget.seed ?? Random().nextInt(1 << 31),
          );
  }();

  /// The match engine only uses this seed, so replaying the saved moves
  /// rebuilds exactly the same match: score, commentary and all.
  late final MatchSim _sim = () {
    final sim = MatchSim(
      shirtName: widget.player.identity.shirtName,
      user: widget.player,
      homeClub: _matchup?.home,
      awayClub: _matchup?.away,
      userPosition: _matchup?.userPosition,
      random: Random(_progress.seed),
      creditSeed: _progress.seed,
    );
    for (final name in _progress.moves) {
      if (sim.isOver) break;
      if (sim.isHalfTime) sim.startSecondHalf();
      final action = MatchAction.values.byName(name);
      _training.play(sim, action);
    }
    if (_progress.secondHalf && sim.isHalfTime) sim.startSecondHalf();
    return sim;
  }();

  void _saveProgress() => unawaited(
    const CareerStore().save(
      widget.slot,
      widget.player.copyWith(match: _progress),
    ),
  );
  final _scroll = ScrollController();
  bool _saving = false;
  bool _showAllCommentary = true;

  late final Set<String> _homeNames = () {
    final names = <String>{
      if (_sim.shirtName.isNotEmpty) _sim.shirtName,
      if (widget.player.identity.name.isNotEmpty) widget.player.identity.name,
      for (final p in _sim.homeSquad) ...[
        p.name,
        if (p.name.split(' ').length > 1) p.name.split(' ').last,
      ],
    };
    return names;
  }();

  late final Set<String> _awayNames = () {
    final names = <String>{
      for (final p in _sim.awaySquad) ...[
        p.name,
        if (p.name.split(' ').length > 1) p.name.split(' ').last,
      ],
    };
    final duplicates = names.intersection(_homeNames);
    names.removeAll(duplicates);
    _homeNames.removeAll(duplicates);
    return names;
  }();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Your successful moves this match, which train your stats.
  final _training = MatchTraining();

  /// Stat gains from this match, worked out at full time.
  Growth get _growth => trainFromMatch(
    widget.player,
    _training.successes,
    attempts: _training.attempts,
    earned: _training.xp,
  );

  /// Whether any of the player's moves were picked for them.
  late bool _simulated = widget.simulate;

  @override
  void initState() {
    super.initState();
    if (widget.simulate) _simulateRest();
  }

  /// Plays out the rest of the match, half-time included, with
  /// [autoMove] picking the player's moves.
  void _simulateRest() {
    if (_sim.isOver) return;
    final rng = Random(_progress.seed ^ _progress.moves.length);
    final moves = <String>[];
    var secondHalf = _progress.secondHalf;
    while (!_sim.isOver) {
      if (_sim.isHalfTime) {
        _sim.startSecondHalf();
        secondHalf = true;
      }
      final action = autoMove(_sim, widget.player.attributes, rng);
      _training.play(_sim, action);
      moves.add(action.name);
    }
    _simulated = true;
    var progress = _progress;
    // Moves before the break, the break, then the rest, as if played.
    for (final name in moves) {
      progress = progress.withMove(name);
    }
    if (secondHalf && !progress.secondHalf) {
      progress = progress.startSecondHalf();
    }
    _progress = progress;
    _saveProgress();
  }

  Future<void> _confirmSimulate() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate the rest?'),
        content: const Text(
          'Your moves are picked for you, leaning on your best skills. '
          'Moves that come off still earn XP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simulate'),
          ),
        ],
      ),
    );
    if (go == true && mounted) setState(_simulateRest);
  }

  void _play(MatchAction action) {
    if (_sim.isOver || _sim.isHalfTime) return;
    setState(() {
      _training.play(_sim, action);
      _progress = _progress.withMove(action.name);
    });
    _saveProgress();
    // Keep the newest commentary in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final before = widget.player;
    final growth = _growth;
    // A league match records the result; a story match moves it on.
    var after = afterMatch(
      before.copyWith(clearMatch: true),
      widget.event,
      goalsFor: _sim.homeGoals,
      goalsAgainst: _sim.awayGoals,
      growth: growth,
      scorers: [
        for (final g in _sim.goals)
          RoundGoal(
            mine: g.side == Side.home,
            scorerId: g.scorer.id,
            assistId: g.assist?.id,
          ),
      ],
    );
    // League matchdays move the calendar on, and paydays pay.
    if (widget.event.isSeason) {
      after = payForMatchday(
        after,
        WorldRepository.forSeed(before.worldSeed),
        before.season.season,
        before.season.round,
      );
    }
    await const CareerStore().save(widget.slot, after);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchReportScreen(
          player: before,
          title: widget.event.match.title,
          homeName: _matchup?.home.name ?? 'Your side',
          awayName: widget.event.match.opponent,
          homeGoals: _sim.homeGoals,
          awayGoals: _sim.awayGoals,
          goals: _sim.goals,
          growth: growth,
          moments: Map.of(_training.moments),
          learned: [
            for (final t in after.logicTalents)
              if (!before.logicTalents.contains(t)) t,
          ],
          simulated: _simulated,
        ),
      ),
    );
    // True tells the line-ups screen the match was played to the end.
    if (mounted) Navigator.of(context).pop(true);
  }

  /// "The other trialists" → "TRI".
  static String _shortName(String name) {
    final word = name.trim().split(RegExp(r'\s+')).last.toUpperCase();
    return word.length > 3 ? word.substring(0, 3) : word;
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.event.match;
    return AlabasterPage(
      center: _ScorePill(
        home: 'YOU',
        away: _shortName(match.opponent),
        homeGoals: _sim.homeGoals,
        awayGoals: _sim.awayGoals,
        minute: _sim.minute,
      ),
      trailing: _sim.isOver
          ? null
          : CircleIconButton(
              icon: Icons.fast_forward_rounded,
              tooltip: 'Simulate the rest',
              onPressed: _confirmSimulate,
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Commentary(
                title: match.title,
                feed: _sim.feed,
                controller: _scroll,
                showAll: _showAllCommentary,
                onToggleShowAll: () =>
                    setState(() => _showAllCommentary = !_showAllCommentary),
                homeNames: _homeNames,
                awayNames: _awayNames,
              ),
            ),
            const SizedBox(height: 12),
            if (_sim.isOver)
              _FullTime(
                home: _sim.homeGoals,
                away: _sim.awayGoals,
                opponent: match.opponent,
                note: [
                  '+${_growth.totalXp} XP',
                  if (!_growth.isEmpty) _growth.describe(),
                  if (_simulated) 'simulated',
                ].join(' · '),
              )
            else if (_sim.isHalfTime)
              _FullTime(
                caps: 'HALF-TIME',
                home: _sim.homeGoals,
                away: _sim.awayGoals,
                opponent: match.opponent,
                note: 'They kick off the second half.',
              )
            else
              _MoveCard(sim: _sim, onPick: _play),
          ],
        ),
      ),
      bottom: _sim.isOver
          ? PillButton(
              label: 'Match report',
              trailingArrow: true,
              onPressed: _saving ? null : _finish,
            )
          : _sim.isHalfTime
          ? PillButton(
              label: 'Start second half',
              trailingArrow: true,
              onPressed: () {
                setState(() {
                  _sim.startSecondHalf();
                  _progress = _progress.startSecondHalf();
                });
                _saveProgress();
              },
            )
          : null,
    );
  }
}

/// Compact charcoal score pill for the header: YOU 1 – 0 TRI 38'.
class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.minute,
  });

  final String home;
  final String away;
  final int homeGoals;
  final int awayGoals;
  final int minute;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$home $homeGoals, $away $awayGoals, minute $minute',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: const BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(home, style: _team(AppColors.mint)),
              const SizedBox(width: 10),
              Text(
                '$homeGoals – $awayGoals',
                style: AppText.manrope(
                  20,
                  weight: 300,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(away, style: _team(const Color(0xFFF87171))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.16),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  "$minute'",
                  style: AppText.inter(12, weight: 700, color: AppColors.mint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static TextStyle _team(Color color) =>
      AppText.inter(11, weight: 700, letterSpacing: 1, color: color);
}

class _Commentary extends StatelessWidget {
  const _Commentary({
    required this.title,
    required this.feed,
    required this.controller,
    required this.showAll,
    required this.onToggleShowAll,
    required this.homeNames,
    required this.awayNames,
  });

  final String title;
  final List<CommentaryLine> feed;
  final ScrollController controller;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final Set<String> homeNames;
  final Set<String> awayNames;

  @override
  Widget build(BuildContext context) {
    final displayedFeed = showAll
        ? feed
        : feed.where((line) => line.isHighlight).toList();

    return SoftCard(
      padding: EdgeInsets.zero,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${title.toUpperCase()} · COMMENTARY',
                  style: AppText.caps(),
                ),
              ),
              InkWell(
                onTap: onToggleShowAll,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: showAll ? AppColors.charcoal : AppColors.tile,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showAll ? Icons.sports_soccer : Icons.bolt,
                        size: 11,
                        color: showAll ? AppColors.mint : AppColors.mutedStrong,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showAll ? 'FULL FEED' : 'HIGHLIGHTS',
                        style: AppText.inter(
                          9,
                          weight: 700,
                          letterSpacing: 0.5,
                          color: showAll
                              ? AppColors.mint
                              : AppColors.mutedStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          for (final line in displayedFeed) ...[
            const SizedBox(height: 8),
            _CommentaryRow(
              line: line,
              homeNames: homeNames,
              awayNames: awayNames,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentaryRow extends StatelessWidget {
  const _CommentaryRow({
    required this.line,
    required this.homeNames,
    required this.awayNames,
  });

  final CommentaryLine line;
  final Set<String> homeNames;
  final Set<String> awayNames;

  @override
  Widget build(BuildContext context) {
    final isAway = line.actorSide == Side.away;
    final boltColor = isAway ? const Color(0xFFEF4444) : AppColors.mint;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              "${line.minute}'",
              style: AppText.inter(
                12,
                weight: 700,
                height: 1.67,
                color: line.isGoal
                    ? AppColors.ink
                    : (line.talentName != null
                          ? AppColors.charcoal
                          : AppColors.muted),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.talentName != null ||
                    line.isGoal ||
                    line.isTactical) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (line.isGoal)
                        Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mint.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GOAL',
                            style: AppText.inter(
                              9,
                              weight: 800,
                              letterSpacing: 0.6,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                      if (line.talentName != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 10, color: boltColor),
                              const SizedBox(width: 3),
                              Text(
                                line.talentName!.toUpperCase(),
                                style: AppText.inter(
                                  9,
                                  weight: 700,
                                  letterSpacing: 0.5,
                                  color: boltColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (line.isTactical)
                        Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tile,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TACTICAL SHIFT',
                            style: AppText.inter(
                              9,
                              weight: 700,
                              letterSpacing: 0.5,
                              color: AppColors.mutedStrong,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                Text.rich(
                  TextSpan(
                    children: buildHighlightedSpans(
                      text: line.text,
                      homeNames: homeNames,
                      awayNames: awayNames,
                      baseStyle: AppText.inter(
                        14,
                        weight: line.isGoal ? 700 : (line.yourMove ? 600 : 400),
                        height: 1.43,
                        color: line.isGoal
                            ? AppColors.ink
                            : (line.isTactical || !line.isHighlight
                                  ? AppColors.mutedStrong
                                  : AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<InlineSpan> buildHighlightedSpans({
  required String text,
  required Set<String> homeNames,
  required Set<String> awayNames,
  required TextStyle baseStyle,
}) {
  if (text.isEmpty) return const [];
  if (homeNames.isEmpty && awayNames.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final allEntries = <({String name, bool isHome})>[
    for (final n in homeNames) (name: n, isHome: true),
    for (final n in awayNames) (name: n, isHome: false),
  ]..sort((a, b) => b.name.length.compareTo(a.name.length));

  final matches = <({int start, int end, String text, bool isHome})>[];
  final occupied = List<bool>.filled(text.length, false);

  for (final entry in allEntries) {
    if (entry.name.isEmpty) continue;
    var searchStart = 0;
    while (searchStart < text.length) {
      final index = text.indexOf(entry.name, searchStart);
      if (index == -1) break;
      final endIndex = index + entry.name.length;

      final beforeOk = index == 0 || !_isWordChar(text.codeUnitAt(index - 1));
      final afterOk =
          endIndex == text.length || !_isWordChar(text.codeUnitAt(endIndex));

      final isFree = !occupied.sublist(index, endIndex).any((o) => o);

      if (beforeOk && afterOk && isFree) {
        matches.add((
          start: index,
          end: endIndex,
          text: text.substring(index, endIndex),
          isHome: entry.isHome,
        ));
        for (var i = index; i < endIndex; i++) {
          occupied[i] = true;
        }
      }
      searchStart = index + 1;
    }
  }

  if (matches.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  matches.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in matches) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }

    final isHome = match.isHome;
    // Green for home ("mine"), Red for away ("opponent")
    final color = isHome ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final bgColor = isHome ? const Color(0x2215803D) : const Color(0x22DC2626);

    spans.add(
      TextSpan(
        text: match.text,
        style: baseStyle.copyWith(
          color: color,
          backgroundColor: bgColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }

  return spans;
}

bool _isWordChar(int codeUnit) {
  return (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122) ||
      (codeUnit >= 48 && codeUnit <= 57) ||
      (codeUnit >= 192 && codeUnit <= 255);
}

/// The dark card: move count, phase chips, what's happening, and the pad.
class _MoveCard extends StatelessWidget {
  const _MoveCard({required this.sim, required this.onPick});

  final MatchSim sim;
  final ValueChanged<MatchAction> onPick;

  @override
  Widget build(BuildContext context) {
    final notice = sim.notice;
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MOVE ${sim.move + 1} OF ${MatchSim.movesPerChance}',
                style: AppText.caps(color: AppColors.onDarkMuted),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < MatchSim.movesPerChance; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= sim.move
                        ? AppColors.mint
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final phase in MatchPhase.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _PhaseChip(
                              phase: phase,
                              active: phase == sim.phase,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.16),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                notice,
                style: AppText.inter(12, weight: 600, color: AppColors.mint),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            sim.prompt,
            style: AppText.manrope(
              18,
              height: 1.39,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _ControlPad(phase: sim.phase, pad: sim.pad, onPick: onPick),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase, required this.active});

  final MatchPhase phase;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: active ? AppColors.mint : Colors.white.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    ),
    child: Text(
      phase.label.toUpperCase(),
      style: AppText.inter(
        10,
        weight: 700,
        letterSpacing: 0.6,
        color: active ? AppColors.ink : AppColors.onDarkMuted,
      ),
    ),
  );
}

/// The line cross from the sketch: the phase name in the middle, a line out
/// to each move with a T-cap before its label.
class _ControlPad extends StatelessWidget {
  const _ControlPad({
    required this.phase,
    required this.pad,
    required this.onPick,
  });

  final MatchPhase phase;
  final Map<PadDirection, MatchAction> pad;
  final ValueChanged<MatchAction> onPick;

  Widget _arm(PadDirection dir) {
    final action = pad[dir]!;
    return _PadArm(
      key: ValueKey('pad-${action.name}'),
      direction: dir,
      label: action.label,
      onTap: () => onPick(action),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _arm(PadDirection.up),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _arm(PadDirection.left),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                phase.label,
                style: AppText.manrope(
                  20,
                  weight: 600,
                  letterSpacing: -0.3,
                  color: phase == MatchPhase.box
                      ? AppColors.mint
                      : Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _arm(PadDirection.right),
                ),
              ),
            ),
          ],
        ),
        _arm(PadDirection.down),
      ],
    );
  }
}

class _PadArm extends StatelessWidget {
  const _PadArm({
    super.key,
    required this.direction,
    required this.label,
    required this.onTap,
  });

  final PadDirection direction;
  final String label;
  final VoidCallback onTap;

  static const _capColor = Colors.white;
  static final _stemColor = Colors.white.withValues(alpha: 0.45);

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: AppText.inter(15, weight: 600, color: Colors.white),
    );
    final vertical =
        direction == PadDirection.up || direction == PadDirection.down;
    final cap = vertical ? _line(30, 2, _capColor) : _line(2, 30, _capColor);
    final stem = vertical ? _line(2, 26, _stemColor) : _line(30, 2, _stemColor);

    final List<Widget> parts = switch (direction) {
      PadDirection.up => [text, const SizedBox(height: 6), cap, stem],
      PadDirection.down => [stem, cap, const SizedBox(height: 6), text],
      PadDirection.left => [text, const SizedBox(width: 8), cap, stem],
      PadDirection.right => [stem, cap, const SizedBox(width: 8), text],
    };
    final padding = switch (direction) {
      PadDirection.up => const EdgeInsets.fromLTRB(14, 4, 14, 0),
      PadDirection.down => const EdgeInsets.fromLTRB(14, 0, 14, 4),
      PadDirection.left => const EdgeInsets.fromLTRB(4, 12, 0, 12),
      PadDirection.right => const EdgeInsets.fromLTRB(0, 12, 4, 12),
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Padding(
          padding: padding,
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: parts)
              : Row(mainAxisSize: MainAxisSize.min, children: parts),
        ),
      ),
    );
  }

  static Widget _line(double w, double h, Color color) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(1)),
    ),
  );
}

/// The score at a break: full time, or half-time with [note].
class _FullTime extends StatelessWidget {
  const _FullTime({
    this.caps = 'FULL TIME',
    required this.home,
    required this.away,
    required this.opponent,
    this.note,
  });

  final String caps;
  final int home;
  final int away;
  final String opponent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caps, style: AppText.caps(color: AppColors.onDarkMuted)),
          const SizedBox(height: 8),
          Text(
            'You $home – $away $opponent',
            style: AppText.display(28, color: Colors.white),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: AppText.inter(14, color: AppColors.onDarkSoft)),
          ],
        ],
      ),
    );
  }
}
