import 'package:baller/game/models/season_progress.dart';

/// The game calendar. Season 1 is 2026/27; every season starts in July
/// (pre-season), plays one league round each Saturday from early August,
/// and pays wages on the last day of every month.

/// The calendar year season 1 starts in.
const int firstSeasonYear = 2026;

/// 1 July of the season's first year.
DateTime preSeason(int season) => DateTime(firstSeasonYear + season - 1, 7);

/// The first Saturday on or after 8 August: matchday 1.
DateTime seasonStart(int season) {
  final year = firstSeasonYear + season - 1;
  var day = 8;
  while (DateTime(year, 8, day).weekday != DateTime.saturday) {
    day++;
  }
  return DateTime(year, 8, day);
}

/// The Saturday of [round] (0-based).
/// (Built from the calendar date, not by adding hours, so clock changes
/// can't move a matchday.)
DateTime roundDate(int season, int round) {
  final start = seasonStart(season);
  return DateTime(start.year, start.month, start.day + 7 * round);
}

/// Today's date: the next league matchday, or pre-season before the
/// league has started (and before season mode).
DateTime today(SeasonProgress progress, {required bool inSeason}) => inSeason
    ? roundDate(progress.season, progress.round)
    : preSeason(progress.season);

/// How many month-end paydays fall after [from] and on or before [to].
int paydaysBetween(DateTime from, DateTime to) {
  final months = (to.year * 12 + to.month) - (from.year * 12 + from.month);
  return months < 0 ? 0 : months;
}

/// The last day of [date]'s month: the next payday.
DateTime payday(DateTime date) => DateTime(date.year, date.month + 1, 0);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Sat 8 Aug 2026".
String formatDate(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "2026/27".
String seasonLabel(int season) {
  final year = firstSeasonYear + season - 1;
  return '$year/${(year + 1) % 100}';
}
