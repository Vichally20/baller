import 'package:baller/data/career_store.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/position_decision.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/ui/screens/career_screen.dart';
import 'package:baller/ui/screens/club_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/club_crest.dart';
import 'package:baller/ui/widgets/stars.dart';
import 'package:flutter/material.dart';

enum SigningReason {
  /// The player accepted an offer.
  offer,

  /// The trial club offered a contract.
  trialVerdict,
}

/// The player joins the club, and the manager decides where they play.
/// Continuing saves the signed career and opens the hub.
class SigningScreen extends StatefulWidget {
  const SigningScreen({
    super.key,
    required this.player,
    required this.slot,
    required this.reason,
  });

  /// Already placed at the club, signed.
  final Player player;
  final int slot;
  final SigningReason reason;

  @override
  State<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends State<SigningScreen> {
  late final CareerClub _club = careerClubOf(
    widget.player,
    WorldRepository.forSeed(widget.player.worldSeed),
  )!;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    await const CareerStore().save(widget.slot, widget.player);
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      CareerScreen.route(widget.player, widget.slot),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _club.club;
    final verdict = widget.reason == SigningReason.trialVerdict;
    return AlabasterPage(
      title: verdict ? 'Trial verdict' : 'Signing',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          HeroCard(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict ? 'THEY WANT YOU · CONTRACT OFFERED' : 'WELCOME TO',
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ClubCrest(
                      initials: club.initials,
                      size: 56,
                      inverted: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        club.name,
                        style: AppText.display(30, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${club.country.label} · Division ${club.division} · '
                        '${club.style.label}',
                        style: AppText.inter(13, color: AppColors.onDarkSoft),
                      ),
                    ),
                    Stars(count: club.stars, size: 14, color: AppColors.mint),
                  ],
                ),
                if (verdict) ...[
                  const SizedBox(height: 12),
                  Text(
                    _club.placement.kind.abroad
                        ? 'The academy staff have seen enough. The parent '
                              'club is bringing you to Europe.'
                        : 'The coaches have seen enough. There is a contract '
                              'waiting for you.',
                    style: AppText.inter(
                      14,
                      height: 1.43,
                      color: AppColors.onDarkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DecisionCard(decision: _club.decision, player: widget.player),
          const SizedBox(height: 14),
          ManagerCard(manager: club.manager),
        ],
      ),
      bottom: PillButton(
        label: verdict ? 'Sign the contract' : 'Start career',
        trailingArrow: true,
        onPressed: _saving ? null : _continue,
      ),
    );
  }
}

/// "The manager's decision": where the player will play, and why.
class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision, required this.player});

  final PositionDecision decision;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final second = decision.second;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("THE MANAGER'S DECISION", style: AppText.caps()),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  decision.position.label,
                  style: AppText.display(30, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: decision.honoured ? AppColors.mint : AppColors.chip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  decision.honoured ? 'Your wish' : 'Best fit',
                  style: AppText.inter(12, weight: 700),
                ),
              ),
            ],
          ),
          if (second != null) ...[
            const SizedBox(height: 2),
            Text(
              'Also used at ${second.label}',
              style: AppText.inter(14, color: AppColors.mutedStrong),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              decision.reason,
              style: AppText.inter(
                13,
                height: 1.45,
                color: AppColors.mutedStrong,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You wanted ${decision.wish.label} '
            '(${decision.wish.rating(player.attributes)}) · best fit '
            '${decision.best.label} '
            '(${decision.best.rating(player.attributes)})',
            style: AppText.inter(12, height: 1.4, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
