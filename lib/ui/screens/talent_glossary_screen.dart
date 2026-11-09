import 'package:baller/game/data/talents.dart';
import 'package:baller/game/models/talent.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/talent_tile.dart';
import 'package:flutter/material.dart';

/// Every talent in the game, one archetype tab at a time.
class TalentGlossaryScreen extends StatefulWidget {
  const TalentGlossaryScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TalentGlossaryScreen());

  @override
  State<TalentGlossaryScreen> createState() => _TalentGlossaryScreenState();
}

class _TalentGlossaryScreenState extends State<TalentGlossaryScreen> {
  TalentArchetype _tab = TalentArchetype.innate;

  @override
  Widget build(BuildContext context) {
    final talents = talentsOf(_tab);
    return AlabasterPage(
      title: 'Talent glossary',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _ArchetypeTabs(
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _tab.description,
              style: AppText.inter(
                14,
                height: 1.43,
                color: AppColors.mutedStrong,
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final talent in talents)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                radius: 22,
                padding: EdgeInsets.zero,
                child: TalentTile(
                  talent: talent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill segmented control: Innate (n) | Logic (n).
class _ArchetypeTabs extends StatelessWidget {
  const _ArchetypeTabs({required this.selected, required this.onSelect});

  final TalentArchetype selected;
  final ValueChanged<TalentArchetype> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final archetype in TalentArchetype.values)
            Expanded(
              child: Semantics(
                selected: archetype == selected,
                button: true,
                child: Material(
                  color: archetype == selected
                      ? AppColors.charcoal
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(archetype),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          '${archetype.label} '
                          '(${talentsOf(archetype).length})',
                          style: AppText.inter(
                            14,
                            weight: 600,
                            color: archetype == selected
                                ? Colors.white
                                : AppColors.mutedStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
