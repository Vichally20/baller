import 'package:baller/game/career/growth.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/widgets/talent_tile.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// After full time: the score and who scored, what the player did, and
/// the XP each stat earned (with any +1s). The result is already saved;
/// Continue goes back to the hub.
class MatchReportScreen extends StatelessWidget {
  const MatchReportScreen({
    super.key,
    required this.player,
    required this.title,
    required this.homeName,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.goals,
    required this.growth,
    this.moments = const {},
    this.learned = const [],
    this.simulated = false,
  });

  /// The player as they were before the match.
  final Player player;
  final String title;
  final String homeName;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final List<MatchGoal> goals;
  final Growth growth;

  /// Goals, assists, tackles won and clearances (they earn extra XP).
  final Map<KeyMoment, int> moments;

  /// Logic talents learned because this match's growth crossed a
  /// milestone.
  final List<Talent> learned;

  /// The player's moves were picked for them.
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final tried = growth.breakdown.fold(0, (s, t) => s + t.attempts);
    final won = growth.breakdown.fold(0, (s, t) => s + t.successes);
    return AlabasterPage(
      title: 'Match report',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _ScoreCard(
            title: title,
            homeName: homeName,
            awayName: awayName,
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            goals: goals,
            simulated: simulated,
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR MATCH', style: AppText.caps()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Figure(
                      value: '${moments[KeyMoment.goal] ?? 0}',
                      label: 'Goals',
                    ),
                    _Figure(
                      value: '${moments[KeyMoment.assist] ?? 0}',
                      label: 'Assists',
                    ),
                    _Figure(value: '$won/$tried', label: 'Moves won'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Figure(
                      value: '${moments[KeyMoment.tackle] ?? 0}',
                      label: 'Tackles won',
                    ),
                    _Figure(
                      value: '${moments[KeyMoment.clearance] ?? 0}',
                      label: 'Clearances',
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          if (learned.isNotEmpty) ...[
            const SizedBox(height: 14),
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'NEW TALENT LEARNED',
                    style: AppText.caps(color: AppColors.onDarkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your game has grown enough to pick up something new.',
                    style: AppText.inter(14, color: AppColors.onDarkSoft),
                  ),
                  const SizedBox(height: 12),
                  for (final t in learned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TalentTile(talent: t),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _XpCard(player: player, growth: growth),
        ],
      ),
      bottom: PillButton(
        label: 'Continue',
        trailingArrow: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Charcoal card: the result, the score and the scorers on each side.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.title,
    required this.homeName,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.goals,
    required this.simulated,
  });

  final String title;
  final String homeName;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final List<MatchGoal> goals;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final result = homeGoals > awayGoals
        ? 'Win'
        : homeGoals == awayGoals
        ? 'Draw'
        : 'Defeat';
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'FULL TIME · ${title.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
              ),
              _DarkTag(simulated ? '$result · simulated' : result),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _SideName(homeName, align: TextAlign.start)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$homeGoals – $awayGoals',
                  semanticsLabel: '$homeGoals to $awayGoals',
                  style: AppText.display(44, color: Colors.white),
                ),
              ),
              Expanded(child: _SideName(awayName, align: TextAlign.end)),
            ],
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0x1FFFFFFF)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Scorers(goals, Side.home)),
                const SizedBox(width: 16),
                Expanded(child: _Scorers(goals, Side.away)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SideName extends StatelessWidget {
  const _SideName(this.name, {required this.align});

  final String name;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    name,
    textAlign: align,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppText.manrope(15, weight: 600, height: 1.25, color: Colors.white),
  );
}

/// One side's goals: "Surname 23'" with the assist under it.
class _Scorers extends StatelessWidget {
  const _Scorers(this.goals, this.side);

  final List<MatchGoal> goals;
  final Side side;

  static String _short(SquadPlayer p) => p.id == MatchSim.userId
      ? 'You'
      : p.name.trim().split(RegExp(r'\s+')).last;

  @override
  Widget build(BuildContext context) {
    final end = side == Side.away;
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = end ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        for (final g in goals.where((g) => g.side == side))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: align,
              children: [
                Text(
                  "${_short(g.scorer)} ${g.minute}'",
                  textAlign: textAlign,
                  style: AppText.inter(
                    13,
                    weight: g.scorer.id == MatchSim.userId ? 700 : 500,
                    color: g.scorer.id == MatchSim.userId
                        ? AppColors.mint
                        : Colors.white,
                  ),
                ),
                if (g.assist case final a?)
                  Text(
                    'assist ${_short(a)}',
                    textAlign: textAlign,
                    style: AppText.inter(
                      11,
                      color: a.id == MatchSim.userId
                          ? AppColors.mint
                          : AppColors.onDarkMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: AppText.inter(11, weight: 600, color: Colors.white),
    ),
  );
}

/// A big number over a caps label.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.display(30)),
        Text(label.toUpperCase(), style: AppText.caps()),
      ],
    ),
  );
}

/// Total XP, what multiplied it, and one row per stat used.
class _XpCard extends StatelessWidget {
  const _XpCard({required this.player, required this.growth});

  final Player player;
  final Growth growth;

  @override
  Widget build(BuildContext context) {
    final age = player.attributes.age;
    final technical = player.location.perk == CountryPerk.technicalSchooling;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('XP EARNED', style: AppText.caps()),
                    const SizedBox(height: 2),
                    Text('+${growth.totalXp} XP', style: AppText.display(34)),
                  ],
                ),
              ),
              if (!growth.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LevelTag(switch (_levels(growth)) {
                    1 => 'Level up',
                    final n => '$n level ups',
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip('Age $age · ×${_rate(growth.learningRate)} learning'),
              for (final m in KeyMoment.values) _Chip('${m.label} ${m.xp}'),
              const _Chip('Other move won $xpPerSuccess'),
              if (technical)
                const _Chip('Technical schooling · Pass, Dribble ×1.5'),
            ],
          ),
          const SizedBox(height: 8),
          if (growth.breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No moves this match, so no XP.',
                style: AppText.inter(14, color: AppColors.muted),
              ),
            )
          else
            for (final t in growth.breakdown) _StatRow(t),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Every move that comes off earns XP for the stat it uses, '
              'and big moments earn more (before the age and country '
              'multipliers). Fill the bar and the stat goes up by 1; '
              'higher stats need more.',
              style: AppText.inter(12, height: 1.4, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  static int _levels(Growth g) => g.changes.values.fold(0, (s, v) => s + v);

  static String _rate(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : '$r';
}

/// One stat: moves won, XP gained, and its bar towards the next +1.
class _StatRow extends StatelessWidget {
  const _StatRow(this.t);

  final StatTraining t;

  @override
  Widget build(BuildContext context) {
    final levelled = t.levelsGained > 0;
    // Before a +1 the bar grows from the old XP; after one it starts
    // empty at the new level.
    final from = levelled ? 0.0 : t.xpBefore / t.xpNeeded;
    final to = t.xpAfter / t.xpNeeded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  t.stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(16, weight: 600),
                ),
              ),
              const SizedBox(width: 8),
              if (levelled)
                _LevelTag('${t.before} → ${t.after}')
              else
                Text(
                  '${t.after}',
                  style: AppText.inter(14, color: AppColors.muted),
                ),
              const Spacer(),
              Text(
                t.xpGained > 0 ? '+${t.xpGained} XP' : '0 XP',
                style: AppText.inter(
                  14,
                  weight: 700,
                  color: t.xpGained > 0 ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _XpBar(from: from.clamp(0, 1), to: to.clamp(0, 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.successes} of ${t.attempts} '
                  'move${t.attempts == 1 ? '' : 's'} won',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(12, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${t.xpAfter} / ${t.xpNeeded} to ${t.after + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppText.inter(12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banked XP in sand, this match's XP growing in charcoal.
class _XpBar extends StatelessWidget {
  const _XpBar({required this.from, required this.to});

  final double from;
  final double to;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: SizedBox(
      height: 8,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: from, end: to),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.chip)),
            FractionallySizedBox(
              widthFactor: value,
              child: const ColoredBox(color: AppColors.charcoal),
            ),
            FractionallySizedBox(
              widthFactor: from,
              child: const ColoredBox(color: AppColors.sandDeep),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: AppText.inter(12, weight: 500, color: AppColors.mutedStrong),
    ),
  );
}

/// Charcoal pill for a stat going up.
class _LevelTag extends StatelessWidget {
  const _LevelTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.charcoal,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.arrow_upward, size: 12, color: AppColors.mint),
        const SizedBox(width: 3),
        Text(text, style: AppText.inter(12, weight: 700, color: Colors.white)),
      ],
    ),
  );
}
