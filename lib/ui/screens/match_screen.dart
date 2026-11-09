import 'dart:math';

import 'package:baller/data/career_store.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/story_engine.dart';
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
    this.random,
  });

  final Player player;
  final int slot;
  final MatchEvent event;

  /// Inject a seeded [Random] for deterministic tests.
  final Random? random;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late final MatchSim _sim = MatchSim(
    shirtName: widget.player.identity.shirtName,
    user: widget.player,
    random: widget.random,
  );
  final _scroll = ScrollController();
  bool _saving = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _play(MatchAction action) {
    if (_sim.isOver) return;
    setState(() => _sim.play(action));
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
    await const CareerStore().save(
      widget.slot,
      widget.player.withStatus(widget.player.status.advance()),
    );
    if (mounted) Navigator.of(context).pop();
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
              ),
            ),
            const SizedBox(height: 12),
            if (_sim.isOver)
              _FullTime(
                home: _sim.homeGoals,
                away: _sim.awayGoals,
                opponent: match.opponent,
              )
            else
              _MoveCard(sim: _sim, onPick: _play),
          ],
        ),
      ),
      bottom: _sim.isOver
          ? PillButton(
              label: 'Continue',
              trailingArrow: true,
              onPressed: _saving ? null : _finish,
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
            Text(home, style: _team(Colors.white)),
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
            Text(away, style: _team(AppColors.onDarkSoft)),
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
  });

  final String title;
  final List<CommentaryLine> feed;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Text('${title.toUpperCase()} · COMMENTARY', style: AppText.caps()),
          for (final line in feed) ...[
            const SizedBox(height: 10),
            Row(
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
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.text,
                    style: AppText.inter(
                      14,
                      weight: line.yourMove ? 600 : 400,
                      height: 1.43,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
              const Spacer(),
              for (final phase in MatchPhase.values)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _PhaseChip(phase: phase, active: phase == sim.phase),
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
                child: _arm(PadDirection.left),
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
                child: _arm(PadDirection.right),
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

class _FullTime extends StatelessWidget {
  const _FullTime({
    required this.home,
    required this.away,
    required this.opponent,
  });

  final int home;
  final int away;
  final String opponent;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FULL TIME', style: AppText.caps(color: AppColors.onDarkMuted)),
          const SizedBox(height: 8),
          Text(
            'You $home – $away $opponent',
            style: AppText.display(28, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
