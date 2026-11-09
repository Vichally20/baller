import 'package:baller/game/models/talent.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

class TalentDetailScreen extends StatelessWidget {
  const TalentDetailScreen({super.key, required this.talent});

  final Talent talent;

  @override
  Widget build(BuildContext context) {
    final archetype = talent.archetype;
    final innate = archetype == TalentArchetype.innate;
    final alias = talent.alias;

    final heroContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: innate
                ? AppColors.mint.withValues(alpha: 0.14)
                : AppColors.chip,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            archetype.label.toUpperCase(),
            style: AppText.caps(
              color: innate ? AppColors.mint : AppColors.mutedStrong,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          talent.name,
          style: AppText.display(
            34,
            color: innate ? Colors.white : AppColors.ink,
          ),
        ),
        if (alias != null) ...[
          const SizedBox(height: 4),
          Text(
            alias,
            style: AppText.inter(
              15,
              color: innate ? AppColors.onDarkSoft : AppColors.muted,
            ),
          ),
        ],
      ],
    );

    return AlabasterPage(
      title: '${archetype.label} talent',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (innate)
            HeroCard(padding: const EdgeInsets.all(24), child: heroContent)
          else
            SoftCard(padding: const EdgeInsets.all(24), child: heroContent),
          const SizedBox(height: 16),
          SoftCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IN A MATCH', style: AppText.caps()),
                const SizedBox(height: 8),
                Text(
                  talent.description,
                  style: AppText.inter(16, height: 1.5, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${archetype.label} talents',
                  style: AppText.inter(14, weight: 600),
                ),
                const SizedBox(height: 4),
                Text(
                  archetype.description,
                  style: AppText.inter(
                    14,
                    height: 1.43,
                    color: AppColors.mutedStrong,
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
