import 'package:baller/data/career_store.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/calendar.dart';
import 'package:baller/game/career/contracts.dart';
import 'package:baller/game/career/life_actions.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/club_crest.dart';
import 'package:baller/ui/widgets/stars.dart';
import 'package:flutter/material.dart';

/// The player's life off the pitch: the date, money, contract, the
/// manager (one talk a week) and an agent. Every change saves at once.
class LifeScreen extends StatefulWidget {
  const LifeScreen({
    super.key,
    required this.player,
    required this.slot,
    required this.inSeason,
  });

  final Player player;
  final int slot;

  /// The league season is under way (transfers can be agreed).
  final bool inSeason;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  late Player _player = widget.player;
  late final World _world = WorldRepository.forSeed(_player.worldSeed);

  /// What the manager said last, shown under the buttons.
  TalkResult? _lastTalk;

  String get _week => weekKey(_player, inSeason: widget.inSeason);

  Future<void> _save(Player player) async {
    setState(() => _player = player);
    await const CareerStore().save(widget.slot, player);
  }

  Future<void> _talk(TalkResult Function() talk) async {
    final result = talk();
    setState(() => _lastTalk = result);
    if (!identical(result.player, _player)) await _save(result.player);
  }

  Future<void> _findClub() async {
    final agreed = await Navigator.of(context).push<Player>(
      MaterialPageRoute(
        builder: (_) => TransferScreen(player: _player, week: _week),
      ),
    );
    if (agreed != null) await _save(agreed);
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final career = careerClubOf(player, _world);
    final signed = career != null && career.placement.signed;
    final club = signed ? career.club : null;
    final date = today(player.season, inSeason: widget.inSeason);
    return AlabasterPage(
      title: 'Your life',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          HeroCard(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(date).toUpperCase(),
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  player.identity.name,
                  style: AppText.display(32, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'Age ${player.attributes.age}',
                    if (career != null) career.decision.position.label,
                    if (club != null) club.name,
                  ].join(' · '),
                  style: AppText.inter(14, color: AppColors.onDarkSoft),
                ),
                const SizedBox(height: 14),
                Text(
                  'Market value ${formatEuros(playerMarketValue(player, club: club))}',
                  style: AppText.inter(14, weight: 600, color: AppColors.mint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MoneyCard(player: player, world: _world, date: date),
          if (signed) ...[
            const SizedBox(height: 14),
            _ContractCard(player: player, world: _world),
            const SizedBox(height: 14),
            _ManagerCard(
              manager: career.club.manager,
              coach: player.status.coach,
              canTalk: canTalk(player, _week),
              lastTalk: _lastTalk,
              honoured: career.decision.honoured,
              transferAgreed: player.life.transfer != null,
              inSeason: widget.inSeason,
              onFeedback: () => _talk(() => askFeedback(_player, _week)),
              onPosition: () =>
                  _talk(() => askForPosition(_player, _world, _week)),
              onRaise: () => _talk(() => askForRaise(_player, _world, _week)),
              onFindClub: _findClub,
            ),
            const SizedBox(height: 14),
            _AgentCard(
              player: player,
              world: _world,
              onHire: () => _save(hireAgent(_player)),
              onDismiss: () => _save(dismissAgent(_player)),
            ),
          ] else ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Text(
                'Sign for a club to get a contract, a manager to talk to '
                'and an agent.',
                style: AppText.inter(14, height: 1.45, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Balance and what each payday brings.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.player,
    required this.world,
    required this.date,
  });

  final Player player;
  final World world;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final income = monthlyIncome(player, world);
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.inter(14, color: AppColors.mutedStrong),
            ),
          ),
          Text(value, style: AppText.inter(14, weight: strong ? 700 : 500)),
        ],
      ),
    );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONEY', style: AppText.caps()),
          const SizedBox(height: 6),
          Text(
            formatWage(player.status.money),
            style: AppText.display(32, color: AppColors.ink),
          ),
          if (income.total > 0) ...[
            const SizedBox(height: 10),
            line('Wage a month', formatWage(income.wage)),
            if (income.agentFee > 0)
              line('Agent (15%)', '−${formatWage(income.agentFee)}'),
            if (income.sponsorship > 0)
              line('Sponsor', '+${formatWage(income.sponsorship)}'),
            const Divider(height: 16),
            line('Each payday', formatWage(income.total), strong: true),
            const SizedBox(height: 6),
            Text(
              'Next payday: ${formatDate(payday(date))}',
              style: AppText.inter(13, color: AppColors.muted),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'No wages yet.',
              style: AppText.inter(13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.player, required this.world});

  final Player player;
  final World world;

  @override
  Widget build(BuildContext context) {
    final contract = contractOf(player, world)!;
    final transfer = player.life.transfer;
    final next = transfer == null ? null : world.clubById(transfer.clubId);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONTRACT', style: AppText.caps()),
          const SizedBox(height: 6),
          Text(
            contractSummary(contract),
            style: AppText.manrope(18, weight: 600),
          ),
          Text(
            'Until the end of the ${seasonLabel(contract.endSeason)} season',
            style: AppText.inter(13, color: AppColors.muted),
          ),
          if (transfer != null && next != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.tile,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Agreed: you join ${next.name} when the season ends, on '
                '${contractSummary(transfer.contract)}.',
                style: AppText.inter(
                  13,
                  height: 1.45,
                  color: AppColors.mutedStrong,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.manager,
    required this.coach,
    required this.canTalk,
    required this.lastTalk,
    required this.honoured,
    required this.transferAgreed,
    required this.inSeason,
    required this.onFeedback,
    required this.onPosition,
    required this.onRaise,
    required this.onFindClub,
  });

  final Manager manager;
  final int coach;
  final bool canTalk;
  final TalkResult? lastTalk;
  final bool honoured;
  final bool transferAgreed;
  final bool inSeason;
  final VoidCallback onFeedback;
  final VoidCallback onPosition;
  final VoidCallback onRaise;
  final VoidCallback onFindClub;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.sand),
          foregroundColor: AppColors.ink,
          textStyle: AppText.inter(14, weight: 600),
        ),
        child: Text(label),
      ),
    );
    final last = lastTalk;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANAGER', style: AppText.caps()),
          const SizedBox(height: 6),
          Text(manager.name, style: AppText.manrope(18, weight: 600)),
          Text(
            '${manager.philosophy.label} · ${manager.temperament.label}',
            style: AppText.inter(13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Relationship',
                style: AppText.inter(13, color: AppColors.mutedStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: coach / CareerStatus.meterMax,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text('$coach', style: AppText.inter(14, weight: 600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Requests need a relationship of $strongRelationship or more.',
            style: AppText.inter(12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          action('Ask for feedback', canTalk ? onFeedback : null),
          const SizedBox(height: 8),
          action(
            honoured ? 'You play your position' : 'Ask to play your position',
            canTalk && !honoured ? onPosition : null,
          ),
          const SizedBox(height: 8),
          action('Ask for a raise', canTalk ? onRaise : null),
          const SizedBox(height: 8),
          action(
            transferAgreed ? 'Move agreed' : 'Find a new club',
            canTalk && inSeason && !transferAgreed ? onFindClub : null,
          ),
          const SizedBox(height: 10),
          if (last != null && last.message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: last.good
                    ? AppColors.mint.withValues(alpha: 0.3)
                    : AppColors.tile,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(last.message, style: AppText.inter(14, height: 1.45)),
            )
          else
            Text(
              canTalk
                  ? 'One talk a week.'
                  : "You've spoken to the manager this week.",
              style: AppText.inter(12, color: AppColors.muted),
            ),
          if (!inSeason)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Moves can be agreed once the league season starts.',
                style: AppText.inter(12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.player,
    required this.world,
    required this.onHire,
    required this.onDismiss,
  });

  final Player player;
  final World world;
  final VoidCallback onHire;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hasAgent = player.life.agent;
    final income = monthlyIncome(player, world);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AGENT', style: AppText.caps()),
          const SizedBox(height: 6),
          Text(
            hasAgent ? 'You have an agent' : 'No agent',
            style: AppText.manrope(18, weight: 600),
          ),
          const SizedBox(height: 4),
          Text(
            hasAgent
                ? 'They find you a sponsor (${formatWage(income.sponsorship)} '
                      'a month), get 25% more on every new contract, and '
                      'bring offers from abroad. They take 15% of your wages.'
                : 'An agent finds you a sponsor, gets 25% more on every new '
                      'contract and brings offers from abroad, for 15% of '
                      'your wages.',
            style: AppText.inter(
              14,
              height: 1.45,
              color: AppColors.mutedStrong,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: hasAgent
                ? OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Let them go'),
                  )
                : FilledButton(
                    onPressed: onHire,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Hire an agent'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Clubs that would sign the player for next season. Agreeing pops with
/// the updated player; the move happens when the season ends.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.player, required this.week});

  final Player player;
  final String week;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late final List<TransferOffer> _offers = transferOffers(
    widget.player,
    WorldRepository.forSeed(widget.player.worldSeed),
  );
  int _picked = 0;

  @override
  Widget build(BuildContext context) {
    final offers = _offers;
    return AlabasterPage(
      title: 'Find a new club',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Text(
            widget.player.life.agent
                ? 'Your agent has been on the phone. These clubs would sign '
                      'you for next season.'
                : 'Your manager has let it be known you want to move. These '
                      'clubs would sign you for next season.',
            style: AppText.inter(
              14,
              height: 1.45,
              color: AppColors.mutedStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agreeing a move costs 10 relationship with your current manager.',
            style: AppText.inter(12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (offers.isEmpty)
            Text(
              'Nobody is interested yet.',
              style: AppText.inter(14, color: AppColors.muted),
            ),
          for (final (i, offer) in offers.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _OfferTile(
              offer: offer,
              selected: i == _picked,
              onTap: () => setState(() => _picked = i),
            ),
          ],
        ],
      ),
      bottom: offers.isEmpty
          ? null
          : PillButton(
              label: 'Agree to join ${offers[_picked].club.name}',
              trailingArrow: true,
              onPressed: () => Navigator.of(
                context,
              ).pop(agreeTransfer(widget.player, offers[_picked], widget.week)),
            ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final TransferOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final club = offer.club;
    final fg = selected ? Colors.white : AppColors.ink;
    final sub = selected ? AppColors.onDarkSoft : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.charcoal : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                ClubCrest(initials: club.initials, inverted: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: AppText.inter(16, weight: 600, color: fg),
                      ),
                      Text(
                        '${club.country.label} · ${League.nameOf(club.country, club.division)} · '
                        'Fit ${offer.fit}%',
                        style: AppText.inter(13, color: sub),
                      ),
                      Text(
                        contractSummary(offer.contract),
                        style: AppText.inter(13, color: sub),
                      ),
                      Text(
                        'Would play you at ${offer.decision.position.label}',
                        style: AppText.inter(13, weight: 600, color: fg),
                      ),
                    ],
                  ),
                ),
                Stars(
                  count: club.stars,
                  color: selected ? AppColors.mint : AppColors.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
