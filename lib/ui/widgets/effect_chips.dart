import 'package:baller/game/story/story_content.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// "+10 Morale", "−40 Money", "+ Second-hand boots" chips for an outcome.
class EffectChips extends StatelessWidget {
  const EffectChips({super.key, required this.effects, required this.items});

  final Effects effects;
  final Map<String, Item> items;

  static String _signed(int n) => n > 0 ? '+$n' : '−${n.abs()}';

  @override
  Widget build(BuildContext context) {
    final chips = <(String, bool)>[
      if (effects.money != 0)
        ('${_signed(effects.money)} Money', effects.money > 0),
      if (effects.morale != 0)
        ('${_signed(effects.morale)} Morale', effects.morale > 0),
      if (effects.coach != 0)
        ('${_signed(effects.coach)} Coach', effects.coach > 0),
      if (effects.teammates != 0)
        ('${_signed(effects.teammates)} Teammates', effects.teammates > 0),
      for (final id in effects.addItems) ('+ ${items[id]?.name ?? id}', true),
      for (final id in effects.removeItems)
        ('− ${items[id]?.name ?? id}', false),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, good) in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: good
                  ? AppColors.mint.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: AppText.inter(
                12,
                weight: 600,
                color: good ? AppColors.mint : AppColors.onDarkSoft,
              ),
            ),
          ),
      ],
    );
  }
}
