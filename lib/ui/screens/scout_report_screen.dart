import 'package:baller/game/character_creation.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/game/models/talent_tier.dart';
import 'package:baller/ui/screens/pathway_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// End of character creation: talent tier, where the player fits, and the
/// scout's verdict. The pathway comes next.
class ScoutReportScreen extends StatefulWidget {
  const ScoutReportScreen({
    super.key,
    required this.creation,
    required this.slot,
  });

  final CharacterCreation creation;
  final int slot;

  @override
  State<ScoutReportScreen> createState() => _ScoutReportScreenState();
}

class _ScoutReportScreenState extends State<ScoutReportScreen> {
  late final Player _player = widget.creation.build();

  void _next() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PathwayScreen(player: _player, slot: widget.slot),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return AlabasterPage(
      title: 'Scout report',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          _TierCard(player: player),
          const SizedBox(height: 14),
          _FitCard(player: player),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("SCOUT'S NOTE", style: AppText.caps()),
                const SizedBox(height: 8),
                Text(
                  player.tier.scoutNote,
                  style: AppText.manrope(18, height: 1.45, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PillButton(
        label: 'See your pathway',
        trailingArrow: true,
        onPressed: _next,
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.player});

  final Player player;

  /// Short label and score range per tier, lowest first.
  static const _scale = [
    (TalentTier.poor, 'Poor', 'under ${TalentTier.averageFrom}'),
    (
      TalentTier.average,
      'Average',
      '${TalentTier.averageFrom}–${TalentTier.rareFrom - 1}',
    ),
    (
      TalentTier.rare,
      'Rare',
      '${TalentTier.rareFrom}–${TalentTier.geniusFrom - 1}',
    ),
    (TalentTier.genius, 'Genius', '${TalentTier.geniusFrom}+'),
  ];

  @override
  Widget build(BuildContext context) {
    final tier = player.tier;
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${player.identity.name} · Age ${player.attributes.age} · '
                    '${player.location.city}'
                .toUpperCase(),
            style: AppText.caps(color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  tier.label,
                  style: AppText.display(38, color: Colors.white),
                ),
              ),
              Text(
                player.talentScore.toStringAsFixed(0),
                semanticsLabel:
                    'Talent score ${player.talentScore.toStringAsFixed(0)}',
                style: AppText.display(38, color: AppColors.mint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tier.summary,
            style: AppText.inter(14, height: 1.43, color: AppColors.onDarkSoft),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (i, (t, label, _)) in _scale.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: t == tier
                              ? AppColors.mint
                              : t.index < tier.index
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: AppText.inter(
                          11,
                          weight: 600,
                          color: t == tier
                              ? AppColors.mint
                              : AppColors.onDarkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Talent score: average of your six skills'
            '${player.innateTalent == null ? '' : ' +3 for your Innate talent'}'
            '. ${tier.label} is ${_scale[tier.index].$3}.',
            style: AppText.inter(12, height: 1.4, color: AppColors.onDarkMuted),
          ),
        ],
      ),
    );
  }
}

/// Top position ratings, the scout's pick and the player's wish.
class _FitCard extends StatelessWidget {
  const _FitCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final ranked = Position.ranked(player.attributes);
    final best = ranked.first.$1;
    final wish = player.preferredPosition;
    final shown = [
      ...ranked.take(3),
      if (!ranked.take(3).any((r) => r.$1 == wish))
        ranked.firstWhere((r) => r.$1 == wish),
    ];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Where you fit',
                  style: AppText.manrope(18, weight: 600),
                ),
              ),
              Text(
                'Rating by position',
                style: AppText.inter(12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (position, rating) in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      position.code,
                      style: AppText.inter(13, weight: 700),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: rating / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$rating',
                      textAlign: TextAlign.end,
                      style: AppText.inter(15, weight: 600),
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text(
                      position == best
                          ? 'SCOUT PICK'
                          : position == wish
                          ? 'YOUR WISH'
                          : '',
                      textAlign: TextAlign.end,
                      style: AppText.inter(
                        11,
                        weight: 700,
                        color: position == best
                            ? const Color(0xFF2E7D52)
                            : AppColors.mutedStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              wish == best
                  ? 'You want to play ${wish.label}, and the scout agrees.'
                  : 'You want to play ${wish.label}. The scout sees a '
                        '${best.label}. Your manager will decide.',
              style: AppText.inter(
                13,
                height: 1.45,
                color: AppColors.mutedStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
