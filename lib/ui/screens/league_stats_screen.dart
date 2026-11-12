import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/league_stats.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/league_picker.dart';
import 'package:flutter/material.dart';

enum StatBoard {
  goals('Goals', 'Golden Boot race'),
  assists('Assists', 'Most assists'),
  cleanSheets('Clean sheets', 'Golden Glove race');

  const StatBoard(this.label, this.race);

  final String label;
  final String race;

  List<PlayerLine> of(LeagueStats s) => switch (this) {
    goals => s.topScorers,
    assists => s.topAssists,
    cleanSheets => s.topCleanSheets,
  };

  int value(PlayerLine l) => switch (this) {
    goals => l.goals,
    assists => l.assists,
    cleanSheets => l.cleanSheets,
  };
}

/// Top scorers, assists and clean sheets in any senior division, this
/// season, as far as the player has got.
class LeagueStatsScreen extends StatefulWidget {
  const LeagueStatsScreen({
    super.key,
    required this.player,
    this.initialCountry,
    this.initialDivision = 1,
  });

  final Player player;
  final LeagueCountry? initialCountry;

  /// 1-based.
  final int initialDivision;

  @override
  State<LeagueStatsScreen> createState() => _LeagueStatsScreenState();
}

class _LeagueStatsScreenState extends State<LeagueStatsScreen> {
  late final _world = WorldRepository.forSeed(widget.player.worldSeed);
  late LeagueCountry _country =
      widget.initialCountry ?? _world.leagues.first.country;
  late int _division = widget.initialDivision - 1;
  StatBoard _board = StatBoard.goals;
  final _cache = <(LeagueCountry, int), LeagueStats>{};

  LeagueStats get _stats => _cache.putIfAbsent((
    _country,
    _division,
  ), () => leagueStats(widget.player, _world, _country, _division + 1));

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final ranked = _board.of(stats);
    final top = ranked.take(20).toList();
    final you = stats.lines.where((l) => l.isUser).firstOrNull;
    final yourRank = you == null ? -1 : ranked.indexOf(you);
    return AlabasterPage(
      title: 'League stats',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          LeaguePicker(
            countries: [for (final l in _world.leagues) l.country],
            country: _country,
            division: _division,
            onCountry: (c) => setState(() => _country = c),
            onDivision: (d) => setState(() => _division = d),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _BoardTabs(
              selected: _board,
              onSelect: (b) => setState(() => _board = b),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _Leader(
              stats: stats,
              board: _board,
              leader: top.firstOrNull,
            ),
          ),
          if (top.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
                child: Column(
                  children: [
                    _Header(board: _board),
                    for (final (i, l) in top.indexed)
                      _Row(rank: i + 1, line: l, value: _board.value(l)),
                    if (you != null && yourRank >= top.length) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '···',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      _Row(
                        rank: yourRank + 1,
                        line: you,
                        value: _board.value(you),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_board == StatBoard.cleanSheets)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                'Keepers only. A clean sheet is a game without conceding.',
                style: AppText.inter(12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardTabs extends StatelessWidget {
  const _BoardTabs({required this.selected, required this.onSelect});

  final StatBoard selected;
  final ValueChanged<StatBoard> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final b in StatBoard.values) ...[
        Expanded(
          child: SizedBox(
            height: 40,
            child: CountryChip(
              label: b.label,
              selected: b == selected,
              onTap: () => onSelect(b),
            ),
          ),
        ),
        if (b != StatBoard.values.last) const SizedBox(width: 8),
      ],
    ],
  );
}

/// Charcoal card with whoever leads the [board].
class _Leader extends StatelessWidget {
  const _Leader({required this.stats, required this.board, this.leader});

  final LeagueStats stats;
  final StatBoard board;
  final PlayerLine? leader;

  @override
  Widget build(BuildContext context) {
    final leader = this.leader;
    final when = stats.played == 0
        ? 'NOT STARTED'
        : stats.isOver
        ? 'FINAL'
        : 'ROUND ${stats.played} OF ${stats.totalRounds}';
    return HeroCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${board.race.toUpperCase()} · $when',
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  leader == null
                      ? 'No one yet'
                      : leader.isUser
                      ? 'You'
                      : leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(28, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  leader == null
                      ? 'No games played yet this season.'
                      : '${leader.club.name} · ${leader.role.code}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(14, color: AppColors.onDarkSoft),
                ),
              ],
            ),
          ),
          if (leader != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${board.value(leader)}',
                  style: AppText.display(44, color: Colors.white),
                ),
                Text(
                  board.label.toUpperCase(),
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.board});

  final StatBoard board;

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
          SizedBox(width: 28, child: Text('#', style: style)),
          Expanded(child: Text('PLAYER', style: style)),
          SizedBox(
            width: 36,
            child: Text('APPS', textAlign: TextAlign.end, style: style),
          ),
          SizedBox(
            width: 52,
            child: Text(
              switch (board) {
                StatBoard.goals => 'GLS',
                StatBoard.assists => 'AST',
                StatBoard.cleanSheets => 'CS',
              },
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.line, required this.value});

  final int rank;
  final PlayerLine line;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    color: line.isUser ? AppColors.tile : null,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            style: AppText.inter(13, weight: 600, color: AppColors.mutedStrong),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      line.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inter(14, weight: 600),
                    ),
                  ),
                  if (line.isUser) ...[
                    const SizedBox(width: 6),
                    const YouTag(),
                  ],
                ],
              ),
              Text(
                '${line.club.name} · ${line.role.code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.inter(11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${line.apps}',
            textAlign: TextAlign.end,
            style: AppText.inter(13, color: AppColors.mutedStrong),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: AppText.manrope(18, weight: 600),
          ),
        ),
      ],
    ),
  );
}

/// Small charcoal "YOU" pill.
class YouTag extends StatelessWidget {
  const YouTag({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: onDark ? AppColors.mint : AppColors.charcoal,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      'YOU',
      style: AppText.inter(
        9,
        weight: 700,
        letterSpacing: 1,
        color: onDark ? AppColors.ink : Colors.white,
      ),
    ),
  );
}
