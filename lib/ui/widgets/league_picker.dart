import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Country chips over division tabs: picks one league division.
class LeaguePicker extends StatelessWidget {
  const LeaguePicker({
    super.key,
    required this.countries,
    required this.country,
    required this.division,
    required this.onCountry,
    required this.onDivision,
  });

  final List<LeagueCountry> countries;
  final LeagueCountry country;

  /// 0-based.
  final int division;
  final ValueChanged<LeagueCountry> onCountry;
  final ValueChanged<int> onDivision;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          children: [
            for (final c in countries) ...[
              CountryChip(
                label: c.label,
                selected: c == country,
                onTap: () => onCountry(c),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: DivisionTabs(
          country: country,
          selected: division,
          onSelect: onDivision,
        ),
      ),
    ],
  );
}

class CountryChip extends StatelessWidget {
  const CountryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : AppColors.softShadow,
        ),
        child: Material(
          color: selected ? AppColors.charcoal : AppColors.surface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  label,
                  style: AppText.inter(
                    14,
                    weight: 600,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DivisionTabs extends StatelessWidget {
  const DivisionTabs({
    super.key,
    required this.country,
    required this.selected,
    required this.onSelect,
  });

  final LeagueCountry country;
  final int selected;
  final ValueChanged<int> onSelect;

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
          for (var d = 0; d < League.divisionCount; d++)
            Expanded(
              child: Semantics(
                selected: d == selected,
                button: true,
                child: Material(
                  color: d == selected
                      ? AppColors.charcoal
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(d),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              League.shortNameOf(country, d + 1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.inter(
                                14,
                                weight: 600,
                                color: d == selected
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
              ),
            ),
        ],
      ),
    );
  }
}
