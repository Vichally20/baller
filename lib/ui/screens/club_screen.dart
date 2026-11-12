import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/stars.dart';
import 'package:flutter/material.dart';

/// A club: strength, style, academy, manager and the full squad.
class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key, required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    return AlabasterPage(
      title: 'Club',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _ClubHero(club: club),
          const SizedBox(height: 14),
          ManagerCard(manager: club.manager),
          const SizedBox(height: 14),
          _SquadCard(club: club),
        ],
      ),
    );
  }
}

class _ClubHero extends StatelessWidget {
  const _ClubHero({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    Widget fact(String caps, Widget value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caps, style: AppText.caps(color: AppColors.onDarkMuted)),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
    final valueStyle = AppText.inter(14, weight: 600, color: Colors.white);

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  club.initials,
                  style: AppText.manrope(18, weight: 800, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: AppText.display(28, color: Colors.white),
                    ),
                    Text(
                      '${club.country.label} · ${League.nameOf(club.country, club.division)}',
                      style: AppText.inter(13, color: AppColors.onDarkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact(
                'STRENGTH',
                Stars(count: club.stars, size: 15, color: AppColors.mint),
              ),
              fact('STYLE', Text(club.style.label, style: valueStyle)),
              fact(
                'ACADEMY',
                Text(club.hasAcademy ? 'Yes' : 'No', style: valueStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The manager's name, philosophy, youth trust and temperament.
class ManagerCard extends StatelessWidget {
  const ManagerCard({super.key, required this.manager});

  final Manager manager;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, {bool dark = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? AppColors.charcoal : AppColors.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.inter(
          12,
          weight: dark ? 700 : 600,
          color: dark ? Colors.white : AppColors.ink,
        ),
      ),
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANAGER', style: AppText.caps()),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.chip,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  manager.initials,
                  style: AppText.inter(15, weight: 700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(manager.name, style: AppText.inter(17, weight: 600)),
                    Text(
                      'Age ${manager.age} · ${manager.nationality.label} · '
                      '${manager.formation}',
                      style: AppText.inter(13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(manager.philosophy.label, dark: true),
              Semantics(
                label: 'Youth trust ${manager.youthTrust} of 5',
                excludeSemantics: true,
                child: chip(
                  'Youth trust ${'★' * manager.youthTrust}'
                  '${'☆' * (5 - manager.youthTrust)}',
                ),
              ),
              chip(manager.temperament.label),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            manager.philosophy.description,
            style: AppText.inter(
              14,
              height: 1.43,
              color: AppColors.mutedStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Squad', style: AppText.manrope(18, weight: 600)),
                ),
                Text(
                  '${club.squad.length} / ${Club.maxSquadSize} · worth '
                  '${formatEuros(club.squadValue)}',
                  style: AppText.inter(12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          for (final p in club.squad)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.role == SquadRole.gk
                          ? AppColors.tile
                          : AppColors.charcoal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.role.code,
                      style: AppText.inter(
                        11,
                        weight: 700,
                        color: p.role == SquadRole.gk
                            ? AppColors.mutedStrong
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.inter(14, weight: 600),
                        ),
                        Text(
                          'Age ${p.age} · ${p.nationality.label}',
                          style: AppText.inter(11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      formatEuros(p.value),
                      textAlign: TextAlign.end,
                      style: AppText.inter(12, color: AppColors.mutedStrong),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${p.rating}',
                      textAlign: TextAlign.end,
                      style: AppText.manrope(17, weight: 600),
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
