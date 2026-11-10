import 'dart:math';

import 'package:baller/game/career/calendar.dart';
import 'package:baller/game/career/contracts.dart';
import 'package:baller/game/career/growth.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/life.dart';
import 'package:baller/game/models/placement.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/world/world_models.dart';

/// Things the player does off the pitch: talks with the manager (once a
/// week), hiring an agent, and the end-of-season handover. PROVISIONAL
/// numbers, to tune.

/// Coach relationship needed for the manager to grant a request.
const int strongRelationship = 70;

/// This week, for the once-a-week talk: a league round, or a story event.
String weekKey(Player player, {required bool inSeason}) => inSeason
    ? 'S${player.season.season}R${player.season.round}'
    : 'E${player.status.eventIndex}';

bool canTalk(Player player, String week) => player.life.lastTalk != week;

/// The player after a talk, and what the manager said.
class TalkResult {
  const TalkResult(this.player, this.message, {this.good = true});

  final Player player;
  final String message;

  /// Went the player's way.
  final bool good;
}

/// A random number fixed for this week and talk, so asking again (or
/// reloading) can't reroll it.
double _roll(Player player, String week, int talk) {
  var hash = player.worldSeed;
  for (final unit in '$week:$talk'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return Random(hash).nextDouble();
}

Player _talked(Player player, String week, {int coach = 0, Life? life}) =>
    player.copyWith(
      status: player.status.apply(Effects(coach: coach)),
      life: (life ?? player.life).copyWith(lastTalk: week),
    );

/// Usually the relationship improves (3 in 4); sometimes it's a bad time.
TalkResult askFeedback(Player player, String week) {
  final skills = Attribute.values.where((a) => a.isSkill).toList()
    ..sort((a, b) => player.attributes[a].compareTo(player.attributes[b]));
  final weakest = skills.first;
  if (_roll(player, week, 1) < 0.75) {
    return TalkResult(
      _talked(player, week, coach: 5),
      '"Good attitude. Keep it up, and work on your ${weakest.label}."',
    );
  }
  return TalkResult(
    _talked(player, week, coach: -5),
    '"Not now. Show me on the pitch."',
    good: false,
  );
}

/// With a strong relationship, the manager agrees 3 times in 5 to play
/// the player where they want.
TalkResult askForPosition(Player player, World world, String week) {
  final career = careerClubOf(player, world);
  if (career == null) return TalkResult(player, '', good: false);
  final wish = player.preferredPosition.label;
  if (career.decision.honoured) {
    return TalkResult(player, 'You already play at $wish.');
  }
  if (player.status.coach >= strongRelationship &&
      _roll(player, week, 2) < 0.6) {
    return TalkResult(
      _talked(player, week, life: player.life.copyWith(playWish: true)),
      '"Fine. You start at $wish. Don\'t make me regret it."',
    );
  }
  return TalkResult(
    _talked(player, week, coach: -5),
    player.status.coach >= strongRelationship
        ? '"Not yet. The team needs you where you are."'
        : '"Earn my trust first."',
    good: false,
  );
}

/// With a strong relationship: a 10–20% raise. Too early, and the
/// relationship suffers.
TalkResult askForRaise(Player player, World world, String week) {
  final contract = contractOf(player, world);
  final placement = player.placement;
  if (contract == null || placement == null) {
    return TalkResult(player, '', good: false);
  }
  if (player.status.coach < strongRelationship) {
    return TalkResult(
      _talked(player, week, coach: -10),
      '"A raise? You\'ve barely started."',
      good: false,
    );
  }
  final rise = 1.10 + _roll(player, week, 3) * 0.10;
  final raised = contract.withWeeklyWage(
    ((contract.weeklyWage * rise) / 10).round() * 10,
  );
  return TalkResult(
    _talked(player, week).copyWith(placement: placement.withContract(raised)),
    '"You\'ve earned it." Your wage goes up ${((rise - 1) * 100).round()}%.',
  );
}

/// Agreeing a move costs the relationship with the current manager.
Player agreeTransfer(Player player, TransferOffer offer, String week) =>
    _talked(
      player,
      week,
      coach: -10,
      life: player.life.copyWith(
        transfer: PendingTransfer(
          clubId: offer.club.id,
          contract: offer.contract,
        ),
      ),
    );

Player hireAgent(Player player) =>
    player.copyWith(life: player.life.copyWith(agent: true));

Player dismissAgent(Player player) =>
    player.copyWith(life: player.life.copyWith(agent: false));

/// Pays the wages (and sponsorship) for every payday from [from] to [to].
Player payWages(Player player, World world, DateTime from, DateTime to) {
  final months = paydaysBetween(from, to);
  if (months == 0) return player;
  final income = monthlyIncome(player, world).total * months;
  return player.withStatus(player.status.apply(Effects(money: income)));
}

/// What changes over the summer, ready to show before it happens.
class Summer {
  const Summer({required this.player, required this.growth, this.newClub});

  /// The player at the start of the next season.
  final Player player;

  /// A year older.
  final Growth growth;

  /// The club they move to, if a transfer was agreed.
  final Club? newClub;
}

/// The end of a season: wages for the summer, a year older, any agreed
/// move completed, and a fresh season. Manager agreements don't carry
/// over to a new club.
Summer endOfSeason(Player player, World world) {
  final season = player.season.season;
  final paid = payWages(
    player,
    world,
    roundDate(season, player.season.round == 0 ? 0 : player.season.round - 1),
    preSeason(season + 1),
  );
  final aged = ageOneYear(paid);
  var next = paid
      .copyWith(attributes: aged.attributes)
      .withSeason(paid.season.nextSeason());
  Club? newClub;
  final transfer = player.life.transfer;
  if (transfer != null) {
    newClub = world.clubById(transfer.clubId);
    if (newClub != null) {
      final kind = newClub.country == homeLeagueOf(player.location)
          ? PathwayKind.seniorHome
          : PathwayKind.seniorAbroad;
      next = next.copyWith(
        placement: Placement(
          kind: kind,
          clubId: newClub.id,
          signed: true,
          contract: transfer.contract,
        ),
        life: Life(agent: player.life.agent),
      );
    }
  }
  return Summer(player: next, growth: aged, newClub: newClub);
}

/// Wages due by a league matchday: everything since the last matchday (or
/// since pre-season, for the first). [round] is the round being played.
Player payForMatchday(Player player, World world, int season, int round) =>
    payWages(
      player,
      world,
      round == 0 ? preSeason(season) : roundDate(season, round - 1),
      roundDate(season, round),
    );
