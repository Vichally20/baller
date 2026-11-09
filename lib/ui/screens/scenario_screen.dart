import 'dart:math';

import 'package:baller/data/career_store.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/effect_chips.dart';
import 'package:flutter/material.dart';

/// One scenario: story text and choices; picking one reveals the outcome,
/// applies its effects and saves straight away (no take-backs).
class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({
    super.key,
    required this.player,
    required this.slot,
    required this.event,
    required this.items,
    this.random,
  });

  final Player player;
  final int slot;
  final ScenarioEvent event;
  final Map<String, Item> items;

  /// Inject a seeded [Random] for deterministic tests.
  final Random? random;

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  late final Random _rng = widget.random ?? Random();
  final _scroll = ScrollController();
  int? _picked;
  Outcome? _outcome;
  bool _saving = false;

  Scenario get _scenario => widget.event.scenario;

  /// For {club}, {manager} and {position} in the text.
  late final CareerClub? _club = careerClubOf(
    widget.player,
    WorldRepository.forSeed(widget.player.worldSeed),
  );

  String _fill(String text) => fillText(text, widget.player, club: _club);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choose(int index) async {
    if (_picked != null || _saving) return;
    setState(() {
      _picked = index;
      _saving = true;
    });
    final outcome = resolveChoice(_scenario.choices[index], _rng);
    final status = widget.player.status.apply(outcome.effects).advance();
    await const CareerStore().save(
      widget.slot,
      widget.player.withStatus(status),
    );
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _saving = false;
    });
    // The outcome appears under the choices: bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return AlabasterPage(
      title: widget.event.chapter.title,
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('SCENE ${widget.event.number}', style: AppText.caps()),
          const SizedBox(height: 4),
          Text(
            _scenario.title,
            style: AppText.display(32, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          Text(
            _fill(_scenario.text),
            style: AppText.inter(16, height: 1.6, color: AppColors.ink),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _scenario.choices.length; i++) ...[
            _ChoiceCard(
              letter: String.fromCharCode(65 + i),
              text: _fill(_scenario.choices[i].text),
              state: _picked == null
                  ? _ChoiceState.open
                  : (_picked == i ? _ChoiceState.picked : _ChoiceState.faded),
              onTap: () => _choose(i),
            ),
            const SizedBox(height: 8),
          ],
          if (outcome != null) ...[
            const SizedBox(height: 8),
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHAT HAPPENED',
                    style: AppText.caps(color: AppColors.onDarkMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fill(outcome.text),
                    style: AppText.inter(16, height: 1.55, color: Colors.white),
                  ),
                  if (!outcome.effects.isEmpty) ...[
                    const SizedBox(height: 14),
                    EffectChips(effects: outcome.effects, items: widget.items),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottom: outcome == null
          ? null
          : PillButton(
              label: 'Back to hub',
              trailingArrow: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
    );
  }
}

enum _ChoiceState { open, picked, faded }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = state == _ChoiceState.picked;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: picked ? Colors.white : AppColors.chip,
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: AppText.inter(13, weight: 700, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: AppText.inter(
                15,
                weight: 500,
                height: 1.45,
                color: picked ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
    const padding = EdgeInsets.fromLTRB(14, 14, 16, 14);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: state == _ChoiceState.faded ? 0.45 : 1,
      child: Semantics(
        button: state == _ChoiceState.open,
        selected: picked,
        child: picked
            ? HeroCard(padding: padding, child: content)
            : SoftCard(
                radius: 22,
                padding: padding,
                onTap: state == _ChoiceState.open ? onTap : null,
                child: content,
              ),
      ),
    );
  }
}
