import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/screens/club_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// Every league in the world: pick a country and a division.
class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key, required this.world, this.initialCountry});

  final World world;

  /// Opens on this league if given (e.g. the player's home country).
  final LeagueCountry? initialCountry;

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  late LeagueCountry _country =
      widget.initialCountry ?? widget.world.leagues.first.country;
  int _division = 0;

  League get _league =>
      widget.world.leagues.firstWhere((l) => l.country == _country);

  @override
  Widget build(BuildContext context) {
    // Pre-season: no results yet, so rank by squad strength.
    final clubs = [..._league.divisions[_division]]
      ..sort(
        (a, b) => b.stars != a.stars
            ? b.stars.compareTo(a.stars)
            : b.averageRating.compareTo(a.averageRating),
      );
    return AlabasterPage(
      title: 'Leagues',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              children: [
                for (final league in widget.world.leagues) ...[
                  _CountryChip(
                    label: league.country.label,
                    selected: league.country == _country,
                    onTap: () => setState(() => _country = league.country),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _DivisionTabs(
              selected: _division,
              onSelect: (d) => setState(() => _division = d),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Text(
              'Pre-season · ranked by squad strength · '
              '${League.matchesPerSeason} matchdays · top '
              '${League.promotionPlaces} up, bottom '
              '${League.promotionPlaces} down',
              style: AppText.inter(12, height: 1.35, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    const _TableHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: clubs.length,
                        itemBuilder: (context, i) =>
                            _ClubRow(rank: i + 1, club: clubs[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : AppColors.softShadow,
        ),
        child: Material(
          color: selected ? AppColors.charcoal : AppColors.surface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  label,
                  style: AppText.inter(
                    14,
                    weight: 600,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DivisionTabs extends StatelessWidget {
  const _DivisionTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var d = 0; d < League.divisionCount; d++)
            Expanded(
              child: Semantics(
                selected: d == selected,
                button: true,
                child: Material(
                  color: d == selected
                      ? AppColors.charcoal
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(d),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          'Division ${d + 1}',
                          style: AppText.inter(
                            14,
                            weight: 600,
                            color: d == selected
                                ? Colors.white
                                : AppColors.mutedStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppText.inter(
      10,
      weight: 700,
      letterSpacing: 1,
      color: AppColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: style)),
          Expanded(child: Text('CLUB', style: style)),
          SizedBox(
            width: 34,
            child: Text('AVG', textAlign: TextAlign.end, style: style),
          ),
          SizedBox(
            width: 60,
            child: Text('VALUE', textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.rank, required this.club});

  final int rank;
  final Club club;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '★' * club.stars,
      club.style.label,
      if (club.hasAcademy) 'Academy',
    ].join(' · ');
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => ClubScreen(club: club))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: AppText.inter(
                  13,
                  weight: 600,
                  color: AppColors.mutedStrong,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.inter(14, weight: 600),
                  ),
                  Text(
                    meta,
                    semanticsLabel:
                        '${club.stars} stars, ${club.style.label}'
                        '${club.hasAcademy ? ', has an academy' : ''}',
                    style: AppText.inter(11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                club.averageRating.round().toString(),
                textAlign: TextAlign.end,
                style: AppText.inter(14, weight: 700),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                formatEuros(club.squadValue),
                textAlign: TextAlign.end,
                style: AppText.inter(12, color: AppColors.mutedStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
