import 'package:baller/data/career_store.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/contracts.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/ui/screens/career_screen.dart';
import 'package:baller/ui/screens/signing_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/club_crest.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:flutter/material.dart';

/// The clubs that want the player (offers) or will look at them (trials).
/// Joining an offer goes to the signing; picking a trial starts the career
/// on trial there.
class PathwayScreen extends StatefulWidget {
  const PathwayScreen({super.key, required this.player, required this.slot});

  /// A player with no placement yet.
  final Player player;
  final int slot;

  @override
  State<PathwayScreen> createState() => _PathwayScreenState();
}

class _PathwayScreenState extends State<PathwayScreen> {
  late final Pathway _pathway = pathwayFor(
    widget.player,
    WorldRepository.forSeed(widget.player.worldSeed),
  );
  int _picked = 0;
  bool _busy = false;

  Opportunity get _chosen => _pathway.options[_picked];

  /// The player attached to the chosen club, story from the start.
  /// What [option]'s club offers (offers only; trials sign after the
  /// verdict).
  Contract _contractFor(Opportunity option) => offerContract(
    player: widget.player,
    club: option.club,
    kind: _pathway.kind,
    startSeason: widget.player.season.season,
    agent: widget.player.life.agent,
  );

  Player _placed({required bool signed}) => widget.player
      .withStatus(widget.player.status.restart())
      .withPlacement(
        Placement(
          kind: _pathway.kind,
          clubId: _chosen.club.id,
          site: _chosen.site,
          signed: signed,
          contract: signed ? _contractFor(_chosen) : null,
        ),
      );

  Future<void> _continue() async {
    if (_pathway.kind.offers) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SigningScreen(
            player: _placed(signed: true),
            slot: widget.slot,
            reason: SigningReason.offer,
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final player = _placed(signed: false);
    // Replaces whatever career was in this slot.
    await const CareerStore().save(widget.slot, player);
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      CareerScreen.route(player, widget.slot),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _pathway.kind;
    final options = _pathway.options;
    return AlabasterPage(
      title: 'Your pathway',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          _Intro(player: widget.player, kind: kind, count: options.length),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(_listCaps(kind), style: AppText.caps()),
          ),
          const SizedBox(height: 10),
          for (final (i, option) in options.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            kind.offers
                ? _OfferCard(
                    option: option,
                    contract: _contractFor(option),
                    selected: i == _picked,
                    onTap: () => setState(() => _picked = i),
                  )
                : _TrialCard(
                    option: option,
                    selected: i == _picked,
                    onTap: () => setState(() => _picked = i),
                  ),
          ],
          if (kind.trials) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                kind.abroad
                    ? 'Shine at an academy trial and the parent club can '
                          'bring you to Europe.'
                    : 'Impress at the trial and the club offers you a '
                          'contract.',
                style: AppText.inter(13, height: 1.4, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
      bottom: PillButton(
        label: kind.offers
            ? 'Join ${_chosen.name}'
            : 'Go to the ${_chosen.club.town} trial',
        trailingArrow: true,
        onPressed: _busy ? null : _continue,
      ),
    );
  }

  static String _listCaps(PathwayKind kind) => switch (kind) {
    PathwayKind.academyAbroad ||
    PathwayKind.academyHome => 'ACADEMY OFFERS · BEST FIT FIRST',
    PathwayKind.seniorAbroad ||
    PathwayKind.seniorHome => 'CONTRACT OFFERS · BEST FIT FIRST',
    PathwayKind.academyTrials => 'ACADEMY TRIALS · BEST FIT FIRST',
    PathwayKind.homeTrials => 'OPEN TRIALS · BEST FIT FIRST',
  };
}

/// Charcoal card for offers, white for trials: who you are and what's
/// happening.
class _Intro extends StatelessWidget {
  const _Intro({required this.player, required this.kind, required this.count});

  final Player player;
  final PathwayKind kind;
  final int count;

  static const _numbers = {2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five'};

  @override
  Widget build(BuildContext context) {
    final n = _numbers[count] ?? '$count';
    final (title, text) = switch (kind) {
      PathwayKind.academyAbroad => (
        'Europe is calling',
        '$n European academies want you. Pick one: you will live and train '
            'abroad from next month.',
      ),
      PathwayKind.academyHome => (
        'They all want you',
        'Word travels fast. $n academies are competing to sign you, and each '
            'manager has made a pitch.',
      ),
      PathwayKind.seniorAbroad => (
        'Europe is calling',
        '$n European clubs want you in their squads. Pick one and you move '
            'abroad this summer.',
      ),
      PathwayKind.seniorHome => (
        'Contract offers',
        "You're past youth football. $n clubs have offered you a contract.",
      ),
      PathwayKind.academyTrials => (
        'Earn your chance',
        'European clubs run academies here. Make one of them notice you and '
            'they can take you abroad.',
      ),
      PathwayKind.homeTrials => (
        'Earn your chance',
        'No offers yet. These clubs are holding open trials this month. Pick '
            'one to attend.',
      ),
    };
    final caps =
        '${player.tier.label} · Age ${player.attributes.age} · '
                '${player.location.city}'
            .toUpperCase();
    final dark = kind.offers;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caps,
          style: AppText.caps(
            color: dark ? AppColors.onDarkMuted : AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppText.display(
            34,
            color: dark ? Colors.white : AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: AppText.inter(
            14,
            height: 1.43,
            color: dark ? AppColors.onDarkSoft : AppColors.mutedStrong,
          ),
        ),
      ],
    );
    const padding = EdgeInsets.fromLTRB(24, 22, 24, 22);
    return dark
        ? HeroCard(padding: padding, child: content)
        : SoftCard(padding: padding, radius: 28, child: content);
  }
}

/// Colours for a selectable card: charcoal when picked, white otherwise.
class _Palette {
  const _Palette(this.selected);

  final bool selected;

  Color get bg => selected ? AppColors.charcoal : AppColors.surface;
  Color get fg => selected ? Colors.white : AppColors.ink;
  Color get sub => selected ? AppColors.onDarkSoft : AppColors.muted;
  Color get chip =>
      selected ? Colors.white.withValues(alpha: 0.10) : AppColors.chip;
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette(selected);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: palette.bg,
        borderRadius: BorderRadius.circular(24),
        shadowColor: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.option,
    required this.contract,
    required this.selected,
    required this.onTap,
  });

  final Opportunity option;
  final Contract contract;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = _Palette(selected);
    final club = option.club;
    final decision = option.decision;
    Widget chip(String label, {Color? bg, Color? fg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? p.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.inter(11, weight: 700, color: fg ?? p.fg),
      ),
    );

    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClubCrest(initials: club.initials, inverted: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: AppText.inter(16, weight: 600, color: p.fg),
                    ),
                    Text(
                      '${club.country.label} · ${League.nameOf(club.country, club.division)}',
                      style: AppText.inter(13, color: p.sub),
                    ),
                  ],
                ),
              ),
              Text(
                '★' * club.stars + '☆' * (5 - club.stars),
                semanticsLabel: '${club.stars} of 5 stars',
                style: AppText.inter(
                  13,
                  letterSpacing: 1,
                  color: selected ? AppColors.mint : AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(club.style.label),
              chip(club.manager.philosophy.label),
              chip(
                'Fit ${option.fit}%',
                bg: selected ? AppColors.mint : AppColors.charcoal,
                fg: selected ? AppColors.ink : Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            option.detail,
            style: AppText.inter(13, height: 1.4, color: p.sub),
          ),
          const SizedBox(height: 4),
          Text(
            contractSummary(contract),
            style: AppText.inter(13, height: 1.4, color: p.sub),
          ),
          const SizedBox(height: 4),
          Text(
            decision.honoured
                ? 'Would play you at ${decision.position.label}, as you want'
                : 'Would play you at ${decision.position.label}, '
                      'not ${decision.wish.label}',
            style: AppText.inter(13, height: 1.4, weight: 600, color: p.fg),
          ),
        ],
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final Opportunity option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = _Palette(selected);
    final club = option.club;
    final trial = option.trial!;
    final where = option.site == null
        ? '${club.country.label} · Div ${club.division}'
        : '${club.country.label} · Div ${club.division} club';
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.tile,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  trial.day,
                  style: AppText.inter(
                    10,
                    weight: 700,
                    letterSpacing: 1,
                    color: p.sub,
                  ),
                ),
                Text(
                  '${trial.date}',
                  style: AppText.manrope(20, weight: 600, color: p.fg),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: AppText.inter(16, weight: 600, color: p.fg),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: '$where · ',
                    children: [
                      TextSpan(
                        text: '★' * club.stars + '☆' * (5 - club.stars),
                        semanticsLabel: '${club.stars} of 5 stars',
                      ),
                    ],
                  ),
                  style: AppText.inter(13, height: 1.4, color: p.sub),
                ),
                Text(
                  '${club.style.label} · Fit ${option.fit}%',
                  style: AppText.inter(12, height: 1.4, color: p.sub),
                ),
                Text(
                  option.detail,
                  style: AppText.inter(12, height: 1.4, color: p.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
