import 'package:baller/game/models/player.dart';
import 'package:baller/ui/screens/career_screen.dart';
import 'package:baller/ui/screens/identity_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

enum SlotsMode {
  /// Pick a saved career to continue.
  continueCareer,

  /// Every slot is full: pick one for the new career to replace.
  replace,
}

/// Shows every save slot. What tapping a slot does depends on [mode].
class SlotsScreen extends StatelessWidget {
  const SlotsScreen({super.key, required this.slots, required this.mode});

  /// One entry per slot; null = empty.
  final List<Player?> slots;
  final SlotsMode mode;

  bool get _replacing => mode == SlotsMode.replace;

  Future<void> _onTap(BuildContext context, int slot, Player player) async {
    final navigator = Navigator.of(context);
    if (!_replacing) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CareerScreen(player: player, slot: slot),
        ),
      );
      return;
    }
    if (!await _confirmReplace(context, slot, player)) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => IdentityScreen(slot: slot)),
    );
  }

  Future<bool> _confirmReplace(
    BuildContext context,
    int slot,
    Player player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Replace slot ${slot + 1}?',
          style: AppText.manrope(20, weight: 600),
        ),
        content: Text(
          "${player.identity.name}'s career (${player.location.city}, age "
          '${player.attributes.age}) will be replaced once the new career '
          'starts.',
          style: AppText.inter(14, height: 1.43, color: AppColors.mutedStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlabasterPage(
      title: _replacing ? 'Replace a career' : 'Your careers',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_replacing) ...[
            Text(
              'Both slots are full',
              style: AppText.display(28, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a career to replace. It is only overwritten once your new '
              'career starts.',
              style: AppText.inter(
                14,
                height: 1.43,
                color: AppColors.mutedStrong,
              ),
            ),
            const SizedBox(height: 20),
          ],
          for (var slot = 0; slot < slots.length; slot++) ...[
            if (slots[slot] case final player?)
              _FilledSlot(
                slot: slot,
                player: player,
                action: _replacing ? 'Replace' : 'Continue',
                onTap: () => _onTap(context, slot, player),
              )
            else
              _EmptySlot(slot: slot),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({
    required this.slot,
    required this.player,
    required this.action,
    required this.onTap,
  });

  final int slot;
  final Player player;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final innate = player.innateTalent;
    return Semantics(
      button: true,
      label: '$action slot ${slot + 1}',
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SLOT ${slot + 1}', style: AppText.caps()),
                  const SizedBox(height: 4),
                  Text(
                    player.identity.name,
                    style: AppText.display(26, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${player.location.city}, ${player.location.country} · '
                    'Age ${player.attributes.age}',
                    style: AppText.inter(13, color: AppColors.mutedStrong),
                  ),
                  Text(
                    innate == null ? 'No innate talent' : innate.name,
                    style: AppText.inter(13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: action == 'Replace'
                    ? AppColors.chip
                    : AppColors.charcoal,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                action,
                style: AppText.inter(
                  13,
                  weight: 600,
                  color: action == 'Replace' ? AppColors.ink : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SLOT ${slot + 1}', style: AppText.caps()),
          const SizedBox(height: 4),
          Text('Empty', style: AppText.inter(16, weight: 600)),
        ],
      ),
    );
  }
}
