import 'package:baller/game/character_creation.dart';
import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/ui/screens/scout_report_screen.dart';
import 'package:baller/ui/screens/talent_glossary_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/talent_tile.dart';
import 'package:flutter/material.dart';

/// Character creation stage 2: one button draws the starting talents.
class TalentScreen extends StatefulWidget {
  const TalentScreen({super.key, required this.creation, required this.slot});

  final CharacterCreation creation;

  /// Save slot the finished career is written to.
  final int slot;

  @override
  State<TalentScreen> createState() => _TalentScreenState();
}

class _TalentScreenState extends State<TalentScreen> {
  // Kept when the player navigates back and returns.
  late StartingTalents? _drawn = widget.creation.startingTalents;

  void _draw() => setState(() => _drawn = widget.creation.drawTalents());

  void _continue() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ScoutReportScreen(creation: widget.creation, slot: widget.slot),
    ),
  );

  void _openGlossary() =>
      Navigator.of(context).push(TalentGlossaryScreen.route());

  @override
  Widget build(BuildContext context) {
    final drawn = _drawn;
    final innateOdds = (innateTalentChance * 100).round();

    return AlabasterPage(
      title: 'Your talents',
      trailing: CircleIconButton(
        icon: Icons.menu_book_outlined,
        tooltip: 'All talents',
        onPressed: _openGlossary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          _SlotLabel('INNATE · MAX $maxInnateTalents'),
          switch (drawn) {
            null => _EmptySlot(
              title: '—',
              body: '$innateOdds% of players are born with one.',
            ),
            StartingTalents(innate: final innate?) => _InnateCard(innate),
            _ => const _EmptySlot(
              title: 'No innate talent',
              body: "Most players don't have one.",
            ),
          },
          const SizedBox(height: 14),
          _SlotLabel('LOGIC · MAX $maxLogicTalents'),
          switch (drawn) {
            null => _EmptySlot(
              title: '—',
              body:
                  'How many depends on your talent: Poor 0, Average 1 '
                  '(maybe 2), Rare and Genius 2. Grow into the next level '
                  'and you may learn another; a third at $thirdLogicFrom+.',
            ),
            StartingTalents(logic: []) => const _EmptySlot(
              title: 'None yet',
              body: 'Reach Average level as you grow and you may learn one.',
            ),
            StartingTalents(:final logic) => SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [for (final t in logic) TalentTile(talent: t)],
              ),
            ),
          },
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _openGlossary,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('See all ${allTalents.length} talents'),
            ),
          ),
        ],
      ),
      bottom: drawn == null
          ? PillButton(
              label: 'Draw my talents',
              leading: Icons.shuffle,
              onPressed: _draw,
            )
          : PillButton(
              label: 'Continue',
              trailingArrow: true,
              onPressed: _continue,
            ),
    );
  }
}

class _SlotLabel extends StatelessWidget {
  const _SlotLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(text, style: AppText.caps()),
  );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: title == '—'
                ? AppText.display(30, color: AppColors.ink)
                : AppText.inter(16, weight: 600),
          ),
          const SizedBox(height: 4),
          Text(body, style: AppText.inter(14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Charcoal card for a drawn innate talent; opens its detail page.
class _InnateCard extends StatelessWidget {
  const _InnateCard(this.talent);

  final Talent talent;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      onTap: () => openTalent(context, talent),
      child: Row(
        children: [
          IconDisc(
            icon: talentIcon(talent.archetype),
            size: 44,
            background: AppColors.mint.withValues(alpha: 0.14),
            foreground: AppColors.mint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  talent.name,
                  style: AppText.display(26, color: Colors.white),
                ),
                if (talent.alias case final alias?)
                  Text(
                    alias,
                    style: AppText.inter(13, color: AppColors.onDarkSoft),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.onDarkMuted),
        ],
      ),
    );
  }
}
