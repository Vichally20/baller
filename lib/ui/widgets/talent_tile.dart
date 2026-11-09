import 'package:baller/game/models/talent.dart';
import 'package:baller/ui/screens/talent_detail_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

IconData talentIcon(TalentArchetype archetype) => switch (archetype) {
  TalentArchetype.innate => Icons.bolt,
  TalentArchetype.logic => Icons.track_changes,
};

void openTalent(BuildContext context, Talent talent) => Navigator.of(context)
    .push(
      MaterialPageRoute<void>(
        builder: (_) => TalentDetailScreen(talent: talent),
      ),
    );

/// A talent row (icon · name · alias · chevron) that opens its detail page.
/// Sits inside a [SoftCard] or other light container.
class TalentTile extends StatelessWidget {
  const TalentTile({
    super.key,
    required this.talent,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  final Talent talent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final innate = talent.archetype == TalentArchetype.innate;
    return InkWell(
      onTap: () => openTalent(context, talent),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            IconDisc(
              icon: talentIcon(talent.archetype),
              background: innate ? AppColors.charcoal : AppColors.chip,
              foreground: innate ? AppColors.mint : AppColors.ink,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(talent.name, style: AppText.inter(15, weight: 600)),
                  Text(
                    talent.alias ?? '${talent.archetype.label} talent',
                    style: AppText.inter(13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
