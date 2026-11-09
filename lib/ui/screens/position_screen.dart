import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/ui/screens/stat_roll_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// Character creation stage 3: where the player wants to play.
class PositionScreen extends StatefulWidget {
  const PositionScreen({
    super.key,
    required this.slot,
    required this.identity,
    required this.location,
  });

  final int slot;
  final PlayerIdentity identity;
  final Location location;

  @override
  State<PositionScreen> createState() => _PositionScreenState();
}

class _PositionScreenState extends State<PositionScreen> {
  Position? _picked;

  void _continue() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StatRollScreen(
        slot: widget.slot,
        identity: widget.identity,
        location: widget.location,
        position: _picked!,
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
          Text('STAGE 3 OF 6', style: AppText.caps()),
          const SizedBox(height: 4),
          Text(
            'Where do you want to play?',
            style: AppText.display(32, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          _Pitch(
            selected: picked,
            onSelect: (p) => setState(() => _picked = p),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: picked == null
                ? Text(
                    'Tap a position on the pitch.',
                    style: AppText.inter(14, color: AppColors.muted),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR PICK', style: AppText.caps()),
                      const SizedBox(height: 4),
                      Text(
                        picked.label,
                        style: AppText.display(28, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        picked.blurb,
                        style: AppText.inter(
                          14,
                          height: 1.43,
                          color: AppColors.mutedStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final stat in picked.keyStats)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chip,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                stat.label,
                                style: AppText.inter(12, weight: 600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Scouts will recommend where you fit best. Your manager has the '
              'final say.',
              style: AppText.inter(13, height: 1.4, color: AppColors.muted),
            ),
          ),
        ],
      ),
      bottom: PillButton(
        label: picked == null ? 'Pick a position' : 'Continue to stats',
        trailingArrow: picked != null,
        onPressed: picked == null ? null : _continue,
      ),
    );
  }
}

/// Half-pitch with a tappable dot per position (wide roles appear twice).
class _Pitch extends StatelessWidget {
  const _Pitch({required this.selected, required this.onSelect});

  final Position? selected;
  final ValueChanged<Position> onSelect;

  static const _dots = [
    (Position.st, 0.50, 0.13),
    (Position.w, 0.17, 0.24),
    (Position.w, 0.83, 0.24),
    (Position.am, 0.50, 0.33),
    (Position.cm, 0.50, 0.51),
    (Position.dm, 0.50, 0.68),
    (Position.fb, 0.15, 0.70),
    (Position.fb, 0.85, 0.70),
    (Position.cb, 0.50, 0.86),
  ];

  @override
  Widget build(BuildContext context) {
    final lines = Colors.white.withValues(alpha: 0.14);
    return AspectRatio(
      aspectRatio: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                  left: 14,
                  top: 14,
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: lines, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Positioned(
                  left: w / 2 - 60,
                  top: 14,
                  width: 120,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: lines, width: 1.5),
                        right: BorderSide(color: lines, width: 1.5),
                        bottom: BorderSide(color: lines, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: h / 2,
                  child: Container(height: 1.5, color: lines),
                ),
                Positioned(
                  left: w / 2 - 35,
                  top: h / 2 - 35,
                  width: 70,
                  height: 70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: lines, width: 1.5),
                    ),
                  ),
                ),
                for (final (position, x, y) in _dots)
                  Positioned(
                    left: x * w - 24,
                    top: y * h - 24,
                    child: _Dot(
                      position: position,
                      selected: position == selected,
                      onTap: () => onSelect(position),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final Position position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: position.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.mint : Colors.white,
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.mint.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: selected ? 0 : 14,
                spreadRadius: selected ? 6 : -4,
                offset: selected ? Offset.zero : const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            position.code,
            style: AppText.inter(12, weight: 700, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
