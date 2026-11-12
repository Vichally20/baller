import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/calendar.dart';
import 'package:baller/game/career/league_stats.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/ui/screens/league_stats_screen.dart';
import 'package:baller/ui/screens/season_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/club_crest.dart';
import 'package:baller/ui/widgets/league_picker.dart';
import 'package:flutter/material.dart';

/// The end of a season: who won each league, and the Golden Boot, Golden
/// Glove, Playmaker, Player and Young Player of the Season. Opens on the
/// player's own league.
class SeasonAwardsScreen extends StatefulWidget {
  const SeasonAwardsScreen({
    super.key,
    required this.player,
    this.onContinue,
    this.continueLabel = 'Continue',
  });

  final Player player;

  /// Runs when the bottom button is pressed (e.g. starting next season);
  /// the screen closes afterwards. No button without it.
  final Future<void> Function()? onContinue;
  final String continueLabel;

  @override
  State<SeasonAwardsScreen> createState() => _SeasonAwardsScreenState();
}

class _SeasonAwardsScreenState extends State<SeasonAwardsScreen> {
  late final _world = WorldRepository.forSeed(widget.player.worldSeed);
  late final _career = careerClubOf(widget.player, _world);
  late final Season? _season = seasonFor(
    widget.player,
    _world,
    widget.player.season,
  );
  late LeagueCountry _country =
      _career?.club.country ?? _world.leagues.first.country;
  late int _division = (_career?.club.division ?? 1) - 1;
  final _cache = <(LeagueCountry, int), LeagueStats>{};
  bool _busy = false;

  LeagueStats get _stats => _cache.putIfAbsent((
    _country,
    _division,
  ), () => leagueStats(widget.player, _world, _country, _division + 1));

  Future<void> _continue() async {
    setState(() => _busy = true);
    await widget.onContinue!();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final awards = stats.awards;
    final season = _season;
    final mine =
        season != null &&
        !season.youth &&
        season.club.country == _country &&
        season.club.division == _division + 1;
    final onContinue = widget.onContinue;
    return AlabasterPage(
      title: 'Season awards',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'SEASON ${seasonLabel(widget.player.season.season)}',
              textAlign: TextAlign.center,
              style: AppText.caps(),
            ),
          ),
          LeaguePicker(
            countries: [for (final l in _world.leagues) l.country],
            country: _country,
            division: _division,
            onCountry: (c) => setState(() => _country = c),
            onDivision: (d) => setState(() => _division = d),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stats.played == 0)
                  SoftCard(
                    child: Text(
                      'No games played yet this season.',
                      style: AppText.inter(14, color: AppColors.muted),
                    ),
                  )
                else ...[
                  if (!stats.isOver) ...[
                    _Notice(
                      'Season still going · round ${stats.played} of '
                      '${stats.totalRounds}. These are the awards if it '
                      'ended today.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (season != null &&
                      (mine ||
                          (season.youth &&
                              season.club.country == _country &&
                              season.club.division == _division + 1))) ...[
                    _YourSeason(season: season, awards: mine ? awards : null),
                    const SizedBox(height: 14),
                  ],
                  _Champions(
                    stats: stats,
                    yours: mine && awards.champions.club.id == season.club.id,
                  ),
                  const SizedBox(height: 14),
                  _AwardCard(
                    icon: Icons.sports_soccer,
                    title: 'Golden Boot',
                    caption: 'Most goals',
                    ranked: awards.goldenBoot,
                    value: (l) => l.goals,
                    unit: 'goals',
                  ),
                  _AwardCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Playmaker',
                    caption: 'Most assists',
                    ranked: awards.playmaker,
                    value: (l) => l.assists,
                    unit: 'assists',
                  ),
                  _AwardCard(
                    icon: Icons.back_hand_outlined,
                    title: 'Golden Glove',
                    caption: 'Most clean sheets by a keeper',
                    ranked: awards.goldenGlove,
                    value: (l) => l.cleanSheets,
                    unit: 'clean sheets',
                  ),
                  _AwardCard(
                    icon: Icons.star_outline_rounded,
                    title: 'Player of the Season',
                    caption: 'Goals, assists, clean sheets, quality, finish',
                    ranked: awards.playerOfTheSeason,
                    value: (l) => l.goals,
                    unit: 'goals',
                    describe: _summary,
                  ),
                  _AwardCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Young Player of the Season',
                    caption: 'Best player aged $youngPlayerMaxAge or under',
                    ranked: awards.youngPlayer,
                    value: (l) => l.goals,
                    unit: 'goals',
                    describe: _summary,
                  ),
                  const SizedBox(height: 4),
                  PillButton(
                    label: 'All league stats',
                    secondary: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LeagueStatsScreen(
                          player: widget.player,
                          initialCountry: _country,
                          initialDivision: _division + 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottom: onContinue == null
          ? null
          : PillButton(
              label: widget.continueLabel,
              trailingArrow: true,
              onPressed: _busy ? null : _continue,
            ),
    );
  }

  /// "18 goals · 7 assists" (with clean sheets for keepers and defenders).
  static String _summary(PlayerLine l) => [
    '${l.goals} goal${l.goals == 1 ? '' : 's'}',
    '${l.assists} assist${l.assists == 1 ? '' : 's'}',
    if (l.cleanSheets > 0) '${l.cleanSheets} clean sheets',
  ].join(' · ');
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.tile,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: AppText.inter(13, height: 1.4, color: AppColors.mutedStrong),
    ),
  );
}

/// Charcoal card for the league winners.
class _Champions extends StatelessWidget {
  const _Champions({required this.stats, required this.yours});

  final LeagueStats stats;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    final row = stats.awards.champions;
    final gd = row.goalDifference;
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconDisc(
                icon: Icons.emoji_events_outlined,
                background: Color(0x1FFFFFFF),
                foreground: AppColors.mint,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${stats.isOver ? 'CHAMPIONS' : 'TOP OF THE TABLE'} · '
                  '${stats.name.toUpperCase()}',
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              ClubCrest(initials: row.club.initials, size: 56, inverted: true),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  row.club.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(30, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DarkFigure('${row.points}', 'Points'),
              _DarkFigure('${row.won}-${row.drawn}-${row.lost}', 'W-D-L'),
              _DarkFigure('${gd > 0 ? '+' : ''}$gd', 'Goal diff'),
            ],
          ),
          if (yours) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const YouTag(onDark: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "That's your club. League winners.",
                    style: AppText.inter(14, weight: 600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkFigure extends StatelessWidget {
  const _DarkFigure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.display(24, color: Colors.white)),
        Text(
          label.toUpperCase(),
          style: AppText.caps(color: AppColors.onDarkMuted),
        ),
      ],
    ),
  );
}

/// One award: the winner big, second and third underneath. Turns charcoal
/// when the player won it.
class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.ranked,
    required this.value,
    required this.unit,
    this.describe,
  });

  final IconData icon;
  final String title;
  final String caption;
  final List<PlayerLine> ranked;
  final int Function(PlayerLine) value;
  final String unit;

  /// Replaces the big number with a line of text (for the overall awards).
  final String Function(PlayerLine)? describe;

  @override
  Widget build(BuildContext context) {
    final winner = ranked.firstOrNull;
    final won = winner?.isUser ?? false;
    final ink = won ? Colors.white : AppColors.ink;
    final muted = won ? AppColors.onDarkMuted : AppColors.muted;
    final describe = this.describe;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconDisc(
              icon: icon,
              size: 36,
              background: won ? const Color(0x1FFFFFFF) : AppColors.chip,
              foreground: won ? AppColors.mint : AppColors.ink,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppText.caps(color: muted)),
                  Text(caption, style: AppText.inter(12, color: muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (winner == null)
          Text('Not awarded', style: AppText.inter(14, color: muted))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            winner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.manrope(20, weight: 600, color: ink),
                          ),
                        ),
                        if (won) ...[
                          const SizedBox(width: 8),
                          const YouTag(onDark: true),
                        ],
                      ],
                    ),
                    Text(
                      describe == null
                          ? '${winner.club.name} · ${winner.role.code}'
                          : '${winner.club.name} · ${describe(winner)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inter(13, color: muted),
                    ),
                  ],
                ),
              ),
              if (describe == null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${value(winner)}',
                      style: AppText.display(34, color: ink),
                    ),
                    Text(unit.toUpperCase(), style: AppText.caps(color: muted)),
                  ],
                ),
              ],
            ],
          ),
        if (ranked.length > 1) ...[
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: won ? const Color(0x1FFFFFFF) : AppColors.sand,
          ),
          const SizedBox(height: 10),
          for (final (i, l) in ranked.indexed.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: AppText.inter(12, weight: 600, color: muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${l.isUser ? 'You' : l.name} · ${l.club.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inter(
                        13,
                        weight: l.isUser ? 700 : 400,
                        color: ink,
                      ),
                    ),
                  ),
                  if (describe == null)
                    Text(
                      '${value(l)}',
                      style: AppText.inter(13, weight: 600, color: ink),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: won ? HeroCard(child: content) : SoftCard(child: content),
    );
  }
}

/// Where the player's side finished and their own numbers, with any
/// awards they won.
class _YourSeason extends StatelessWidget {
  const _YourSeason({required this.season, this.awards});

  final Season season;

  /// Their league's awards (senior players only).
  final SeasonAwards? awards;

  @override
  Widget build(BuildContext context) {
    final you = yourSeason(season.progress);
    final won = awards?.wonByUser ?? const <String>[];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR SEASON', style: AppText.caps()),
          const SizedBox(height: 6),
          Text(
            '${season.sideName(season.club)} finished '
            '${ordinal(season.position)}',
            style: AppText.manrope(18, weight: 600),
          ),
          if (season.youth)
            Text(
              '${season.leagueName} champions: '
              '${season.sideName(season.table.first.club)}',
              style: AppText.inter(13, color: AppColors.muted),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Figure('${you.apps}', 'Apps'),
              _Figure('${you.goals}', 'Goals'),
              _Figure('${you.assists}', 'Assists'),
            ],
          ),
          if (won.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in won)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 14,
                          color: AppColors.mint,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            w,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.inter(
                              12,
                              weight: 600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (season.youth) ...[
            const SizedBox(height: 12),
            Text(
              'Youth football has no individual awards. The senior '
              "league's are below.",
              style: AppText.inter(12, height: 1.4, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.display(30)),
        Text(label.toUpperCase(), style: AppText.caps()),
      ],
    ),
  );
}
