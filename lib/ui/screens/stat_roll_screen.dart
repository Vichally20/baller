import 'dart:math';

import 'package:baller/game/character_creation.dart';
import 'package:baller/game/data/wheels.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/location.dart';
import 'package:baller/game/models/player_identity.dart';
import 'package:baller/game/models/position.dart';
import 'package:baller/ui/screens/talent_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/spin_wheel.dart';
import 'package:flutter/material.dart';

/// Character creation stage 4: spin one wheel per stat. The country bonus is
/// shown on top of the rolled value.
class StatRollScreen extends StatefulWidget {
  const StatRollScreen({
    super.key,
    required this.slot,
    required this.identity,
    required this.location,
    required this.position,
    this.random,
  });

  /// Save slot the finished career is written to.
  final int slot;

  /// Chosen on the earlier creation screens.
  final PlayerIdentity identity;
  final Location location;
  final Position position;

  /// Inject a seeded [Random] for deterministic tests.
  final Random? random;

  @override
  State<StatRollScreen> createState() => _StatRollScreenState();
}

class _StatRollScreenState extends State<StatRollScreen> {
  late final CharacterCreation _creation = CharacterCreation(
    identity: widget.identity,
    location: widget.location,
    preferredPosition: widget.position,
    rng: widget.random,
  );

  /// The spin currently animating; its value isn't revealed until it lands.
  SpinResult? _pending;
  late WheelSpec _shownWheel = _creation.currentWheel!;
  int _targetIndex = 0;
  int _spinId = 0;

  bool get _spinning => _pending != null;

  void _spin() {
    final result = _creation.spinStat();
    setState(() {
      _pending = result;
      _shownWheel = result.wheel;
      _targetIndex = result.index;
      _spinId++;
    });
  }

  void _onSpinEnd() {
    if (!mounted) return;
    setState(() {
      _pending = null;
      _shownWheel = _creation.currentWheel ?? _shownWheel;
    });
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TalentScreen(creation: _creation, slot: widget.slot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _creation.statsComplete && !_spinning;
    final revealed = Map.of(_creation.rolls)..remove(_pending?.wheel.attribute);
    final total = _creation.wheels.length;
    final step = _creation.wheels.indexOf(_shownWheel) + 1;

    return AlabasterPage(
      title: 'Roll your player',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              done
                  ? 'STAGE 4 OF 6 · ALL STATS ROLLED'
                  : 'STAGE 4 OF 6 · STAT $step OF $total',
              style: AppText.caps(),
            ),
            const SizedBox(height: 4),
            Text(
              done ? 'Stats rolled' : 'Spin for ${_shownWheel.attribute.label}',
              style: AppText.display(32, color: AppColors.ink),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SpinWheel(
                    labels: [for (final v in _shownWheel.segments) '$v'],
                    targetIndex: _targetIndex,
                    spinId: _spinId,
                    onSpinEnd: _onSpinEnd,
                  ),
                ),
              ),
            ),
            _RollSummary(
              rolls: revealed,
              bonusFor: _creation.bonusFor,
              active: done ? null : _shownWheel.attribute,
            ),
          ],
        ),
      ),
      bottom: done
          ? PillButton(
              label: 'Continue to talent',
              trailingArrow: true,
              onPressed: _continue,
            )
          : PillButton(
              label: _spinning ? 'Spinning…' : 'Spin',
              onPressed: _spinning ? null : _spin,
            ),
    );
  }
}

/// Grid of stat tiles; the stat being spun is highlighted.
class _RollSummary extends StatelessWidget {
  const _RollSummary({
    required this.rolls,
    required this.bonusFor,
    required this.active,
  });

  /// Raw wheel results.
  final Map<Attribute, int> rolls;

  /// Country bonus per attribute.
  final int Function(Attribute) bonusFor;
  final Attribute? active;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 64,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final attribute in Attribute.values)
            _StatTile(
              label: attribute.label.toUpperCase(),
              value: rolls[attribute],
              bonus: bonusFor(attribute),
              active: attribute == active,
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.bonus,
    required this.active,
  });

  final String label;

  /// Raw roll; [bonus] is added on display.
  final int? value;
  final int bonus;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: active ? AppColors.charcoal : AppColors.tile,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              label,
              style: AppText.inter(
                10,
                weight: 600,
                letterSpacing: 0.6,
                color: active ? AppColors.onDarkSoft : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value == null ? '—' : '${value + bonus}',
                  style: AppText.display(
                    24,
                    color: active
                        ? Colors.white
                        : (value == null ? AppColors.muted : AppColors.ink),
                  ),
                ),
                if (bonus > 0 && value != null)
                  Text(
                    ' +$bonus',
                    semanticsLabel: 'including country bonus of $bonus',
                    style: AppText.inter(
                      10,
                      weight: 700,
                      color: const Color(0xFF2E7D52),
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
