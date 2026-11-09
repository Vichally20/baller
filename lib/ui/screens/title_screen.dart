import 'package:baller/data/career_store.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/ui/screens/career_screen.dart';
import 'package:baller/ui/screens/slots_screen.dart';
import 'package:baller/ui/screens/identity_screen.dart';
import 'package:baller/ui/screens/talent_glossary_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  static const _store = CareerStore();

  late Future<List<Player?>> _slots = _store.loadSlots();

  /// Re-reads the slots after returning from another screen.
  void _reload() {
    if (!mounted) return;
    setState(() {
      _slots = _store.loadSlots();
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    _reload();
  }

  /// First empty slot; when every slot is full, ask which to replace.
  void _newCareer(List<Player?> slots) {
    final empty = CareerStore.firstEmpty(slots);
    _open(
      empty != null
          ? IdentityScreen(slot: empty)
          : SlotsScreen(slots: slots, mode: SlotsMode.replace),
    );
  }

  /// Straight into the only saved career, or pick between several.
  void _continue(List<Player?> slots) {
    final filled = [
      for (var i = 0; i < slots.length; i++)
        if (slots[i] != null) i,
    ];
    _open(
      filled.length == 1
          ? CareerScreen(player: slots[filled.single]!, slot: filled.single)
          : SlotsScreen(slots: slots, mode: SlotsMode.continueCareer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlabasterPage(
      showBack: false,
      background: const DecorOvals(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: Center(child: _Wordmark())),
            Text(
              'From nobody\nto legend.',
              style: AppText.display(40, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Text(
              'Spin your stats, draw your talents, and build a career one '
              'decision at a time.',
              style: AppText.inter(
                16,
                height: 1.5,
                color: AppColors.mutedStrong,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottom: FutureBuilder<List<Player?>>(
        future: _slots,
        builder: (context, snapshot) {
          final slots = snapshot.data;
          if (slots == null) {
            return const SizedBox(height: 124); // keeps layout steady
          }
          final saved = slots.whereType<Player>().length;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButton(
                label: 'New career',
                trailingArrow: true,
                onPressed: () => _newCareer(slots),
              ),
              const SizedBox(height: 12),
              if (saved > 0) ...[
                PillButton(
                  label: 'Continue career',
                  secondary: true,
                  onPressed: () => _continue(slots),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(TalentGlossaryScreen.route()),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Talent glossary'),
                ),
              ] else
                PillButton(
                  label: 'Talent glossary',
                  leading: Icons.menu_book_outlined,
                  secondary: true,
                  onPressed: () =>
                      Navigator.of(context).push(TalentGlossaryScreen.route()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Metallic "BALLER" wordmark.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final style = AppText.manrope(52, weight: 800, letterSpacing: 12);
    return Semantics(
      label: 'Baller',
      excludeSemantics: true,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment(-1, -0.2),
          end: Alignment(1, 0.2),
          colors: [
            Color(0xFF0E0E0E),
            Color(0xFF2C2D30),
            Color(0xFF1A1B1C),
            Color(0xFF4A4C50),
            Color(0xFF0E0E0E),
          ],
          stops: [0, 0.35, 0.55, 0.72, 1],
        ).createShader(bounds),
        child: Text('BALLER', style: style),
      ),
    );
  }
}
