import 'package:baller/game/career/season.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// "1st", "2nd", "3rd", "11th", "22nd"…
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// The league table for the player's season, and their results.
class SeasonScreen extends StatelessWidget {
  const SeasonScreen({super.key, required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    final progress = season.progress;
    final rounds = season.rounds.length;
    final division = season.club.division;
    return AlabasterPage(
      title: 'Season ${progress.season}',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          HeroCard(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season.leagueName.toUpperCase(),
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.round == 0
                      ? 'Not started'
                      : '${ordinal(season.position)} of ${season.table.length}',
                  style: AppText.display(34, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  season.isOver
                      ? 'Season over · all $rounds rounds played'
                      : 'Round ${progress.round + 1} of $rounds next',
                  style: AppText.inter(14, color: AppColors.onDarkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            child: Column(
              children: [
                const _Header(),
                for (final (i, row) in season.table.indexed)
                  _Row(
                    rank: i + 1,
                    row: row,
                    name: season.sideName(row.club),
                    mine: row.club.id == season.club.id,
                    zone: i < 3 && division > 1
                        ? _Zone.up
                        : i >= season.table.length - 3 && division < 3
                        ? _Zone.down
                        : null,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Text(
                    '${switch (division) {
                      1 => 'Bottom 3 go down.',
                      3 => 'Top 3 go up.',
                      _ => 'Top 3 go up, bottom 3 go down.',
                    }} Moving between divisions comes in a later update.',
                    style: AppText.inter(
                      12,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _RoundResults(season: season),
          if (progress.round > 0) ...[
            const SizedBox(height: 14),
            _Results(season: season),
          ],
        ],
      ),
    );
  }
}

enum _Zone { up, down }

/// Every game in a round: the scores of the ones played, the fixtures of
/// the ones to come. Opens on the latest round played.
class _RoundResults extends StatefulWidget {
  const _RoundResults({required this.season});

  final Season season;

  @override
  State<_RoundResults> createState() => _RoundResultsState();
}

class _RoundResultsState extends State<_RoundResults> {
  late int _round = (widget.season.progress.round - 1).clamp(
    0,
    widget.season.rounds.length - 1,
  );

  @override
  Widget build(BuildContext context) {
    final season = widget.season;
    final fixtures = season.rounds[_round];
    final last = season.rounds.length - 1;
    Widget arrow(IconData icon, String tooltip, int? to) => IconButton(
      onPressed: to == null ? null : () => setState(() => _round = to),
      tooltip: tooltip,
      icon: Icon(icon),
    );
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              arrow(
                Icons.chevron_left,
                'Previous round',
                _round > 0 ? _round - 1 : null,
              ),
              Expanded(
                child: Text(
                  'ROUND ${_round + 1} · RESULTS',
                  textAlign: TextAlign.center,
                  style: AppText.caps(),
                ),
              ),
              arrow(
                Icons.chevron_right,
                'Next round',
                _round < last ? _round + 1 : null,
              ),
            ],
          ),
          for (final (i, f) in fixtures.indexed)
            () {
              final score = season.scoreOf(_round, i);
              final mine = f.involves(season.club);
              final style = AppText.inter(13, weight: mine ? 700 : 500);
              return Container(
                color: mine ? AppColors.tile : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        season.sideName(f.home),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        score == null ? 'v' : '${score.$1}–${score.$2}',
                        textAlign: TextAlign.center,
                        style: AppText.inter(
                          14,
                          weight: 700,
                          color: score == null
                              ? AppColors.muted
                              : AppColors.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        season.sideName(f.away),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final style = AppText.inter(
      10,
      weight: 700,
      letterSpacing: 1,
      color: AppColors.muted,
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: style)),
          Expanded(child: Text('CLUB', style: style)),
          cell('P', 26),
          cell('GD', 34),
          cell('PTS', 38),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.row,
    required this.name,
    required this.mine,
    required this.zone,
  });

  final int rank;
  final LeagueRow row;
  final String name;
  final bool mine;
  final _Zone? zone;

  @override
  Widget build(BuildContext context) {
    final weight = mine ? 700 : 500;
    Widget cell(String text, double width, {int? w}) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.end,
        style: AppText.inter(13, weight: w ?? weight),
      ),
    );
    final gd = row.goalDifference;
    return Semantics(
      label:
          '$rank, $name${mine ? ', your club' : ''}, played ${row.played}, '
          'goal difference $gd, ${row.points} points',
      excludeSemantics: true,
      child: Container(
        color: mine ? AppColors.tile : null,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: switch (zone) {
                        _Zone.up => const Color(0xFF2E7D52),
                        _Zone.down => const Color(0xFFB4543A),
                        null => Colors.transparent,
                      },
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    '$rank',
                    style: AppText.inter(
                      12,
                      weight: 600,
                      color: AppColors.mutedStrong,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.inter(14, weight: mine ? 700 : 500),
              ),
            ),
            cell('${row.played}', 26),
            cell(gd > 0 ? '+$gd' : '$gd', 34),
            cell('${row.points}', 38, w: 700),
          ],
        ),
      ),
    );
  }
}

/// The player's results so far, newest first.
class _Results extends StatelessWidget {
  const _Results({required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    final results = season.progress.results;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR RESULTS', style: AppText.caps()),
          const SizedBox(height: 8),
          for (var r = results.length - 1; r >= 0; r--)
            () {
              final fixture = season.rounds[r].firstWhere(
                (f) => f.involves(season.club),
              );
              final atHome = fixture.home.id == season.club.id;
              final opponent = season.sideName(
                atHome ? fixture.away : fixture.home,
              );
              final (scored, conceded) = results[r];
              final outcome = scored > conceded
                  ? 'W'
                  : scored == conceded
                  ? 'D'
                  : 'L';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: outcome == 'W'
                            ? AppColors.mint
                            : outcome == 'D'
                            ? AppColors.chip
                            : AppColors.charcoal,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        outcome,
                        style: AppText.inter(
                          12,
                          weight: 700,
                          color: outcome == 'L' ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'R${r + 1} · ${atHome ? 'vs' : 'at'} $opponent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.inter(14),
                      ),
                    ),
                    Text(
                      '$scored–$conceded',
                      style: AppText.inter(14, weight: 700),
                    ),
                  ],
                ),
              );
            }(),
        ],
      ),
    );
  }
}
