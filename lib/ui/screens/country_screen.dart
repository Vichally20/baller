import 'package:baller/game/data/locations.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/ui/screens/position_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// Character creation stage 2: choose a starting country. Each gives a stat
/// bonus and a perk.
class CountryScreen extends StatefulWidget {
  const CountryScreen({super.key, required this.slot, required this.identity});

  final int slot;
  final PlayerIdentity identity;

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  Location? _picked;

  void _continue() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PositionScreen(
        slot: widget.slot,
        identity: widget.identity,
        location: _picked!,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return AlabasterPage(
      title: 'Create your player',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Text('STAGE 2 OF 6', style: AppText.caps()),
          const SizedBox(height: 4),
          Text(
            'Where are you from?',
            style: AppText.display(32, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          if (picked == null)
            SoftCard(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Text(
                'Every country gives a stat boost and a perk that shapes your '
                'career. Pick one to see it.',
                style: AppText.inter(14, height: 1.43, color: AppColors.muted),
              ),
            )
          else
            _BenefitCard(location: picked),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final location in startingLocations)
                  _CountryRow(
                    location: location,
                    selected: identical(location, picked),
                    onTap: () => setState(() => _picked = location),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottom: PillButton(
        label: picked == null ? 'Pick a country' : 'Start in ${picked.city}',
        trailingArrow: picked != null,
        onPressed: picked == null ? null : _continue,
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.identity.toUpperCase(),
            style: AppText.caps(color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 4),
          Text(
            location.country,
            style: AppText.display(34, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: location.bonusLabel,
                background: AppColors.mint.withValues(alpha: 0.16),
                color: AppColors.mint,
              ),
              _Chip(
                label: location.perk.label,
                background: Colors.white.withValues(alpha: 0.10),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            location.perk.description,
            style: AppText.inter(14, height: 1.43, color: AppColors.onDarkSoft),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.color,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: AppText.inter(12, weight: 700, color: color)),
  );
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final Location location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.tile : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      location.country,
                      style: AppText.inter(15, weight: 600),
                    ),
                  ),
                  Text(
                    location.bonusLabel,
                    style: AppText.inter(
                      12,
                      weight: 600,
                      color: AppColors.mutedStrong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.charcoal
                            : const Color(0xFFC9C7C2),
                        width: selected ? 6 : 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
