import 'dart:math';

import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/story_content.dart';

/// Scenarios played before each match.
const int scenariosPerMatch = 2;

/// One step of the career: a scenario or a match.
sealed class StoryEvent {
  const StoryEvent(this.chapter);

  final Chapter chapter;
}

class ScenarioEvent extends StoryEvent {
  const ScenarioEvent(super.chapter, this.scenario, {required this.number});

  final Scenario scenario;

  /// 1-based position within the chapter.
  final int number;
}

class MatchEvent extends StoryEvent {
  const MatchEvent(super.chapter, this.match);

  final MatchInfo match;
}

/// Whether [player] meets the chapter's conditions. Pathway conditions need
/// a chosen pathway.
bool chapterApplies(Chapter chapter, Player player) {
  final when = chapter.when;
  final age = player.attributes.age;
  final kind = player.placement?.kind;
  return (when.pathways == null ||
          (kind != null && when.pathways!.any(kind.matches))) &&
      (when.tiers?.contains(player.tier) ?? true) &&
      (when.regions?.contains(player.location.region) ?? true) &&
      (when.countries?.contains(player.location.id) ?? true) &&
      (when.minAge == null || age >= when.minAge!) &&
      (when.maxAge == null || age <= when.maxAge!);
}

/// Turns written content into the order [player] meets it: the chapters
/// meant for them, each as [scenariosPerMatch] scenarios, then a match, and
/// so on. A chapter that ends mid-pair still gets its match.
List<StoryEvent> buildSchedule(StoryContent content, Player player) {
  final events = <StoryEvent>[];
  for (final chapter in content.chapters.where(
    (c) => chapterApplies(c, player),
  )) {
    var matchCount = 0;
    for (var i = 0; i < chapter.scenarios.length; i++) {
      events.add(ScenarioEvent(chapter, chapter.scenarios[i], number: i + 1));
      final endOfPair = (i + 1) % scenariosPerMatch == 0;
      final lastInChapter = i == chapter.scenarios.length - 1;
      if (endOfPair || lastInChapter) {
        events.add(
          MatchEvent(
            chapter,
            matchCount < chapter.matches.length
                ? chapter.matches[matchCount]
                : MatchInfo.fallback,
          ),
        );
        matchCount++;
      }
    }
  }
  return events;
}

/// The run of events [index] belongs to: the scenarios leading up to a match,
/// plus that match. Used to show "scene, scene, match" progress.
({List<StoryEvent> events, int position}) cycleOf(
  List<StoryEvent> schedule,
  int index,
) {
  var start = index;
  while (start > 0 && schedule[start - 1] is! MatchEvent) {
    start--;
  }
  var end = index;
  while (end < schedule.length - 1 && schedule[end] is! MatchEvent) {
    end++;
  }
  return (events: schedule.sublist(start, end + 1), position: index - start);
}

/// True once a trialist has finished the chapter that ends in the club's
/// verdict (or run out of story without one).
bool trialVerdictDue(List<StoryEvent> schedule, Player player) {
  final placement = player.placement;
  if (placement == null || placement.signed) return false;
  final index = player.status.eventIndex;
  if (index >= schedule.length) return true;
  final verdictChapter = schedule
      .map((e) => e.chapter)
      .where((c) => c.verdict)
      .firstOrNull;
  if (verdictChapter == null) return false;
  final lastEvent = schedule.lastIndexWhere((e) => e.chapter == verdictChapter);
  return index > lastEvent;
}

/// Picks one of the choice's outcomes, weighted.
Outcome resolveChoice(Choice choice, Random rng) {
  final total = choice.outcomes.fold(0, (sum, o) => sum + o.weight);
  var roll = rng.nextInt(total);
  for (final outcome in choice.outcomes) {
    if (roll < outcome.weight) return outcome;
    roll -= outcome.weight;
  }
  return choice.outcomes.last; // unreachable
}

/// Replaces {name}, {first}, {shirt}, {city}, {country}, {club},
/// {manager} and {position} in story text. Without a club, {club} and
/// {manager} read "the club" and "the manager", and {position} is the
/// position the player wants.
String fillText(String text, Player player, {CareerClub? club}) {
  final id = player.identity;
  return text
      .replaceAll('{club}', club?.name ?? 'the club')
      .replaceAll('{manager}', club?.club.manager.name ?? 'the manager')
      .replaceAll(
        '{position}',
        (club?.decision.position ?? player.preferredPosition).label,
      )
      .replaceAll('{name}', id.name)
      .replaceAll('{first}', id.name.split(' ').first)
      .replaceAll('{shirt}', id.shirtName)
      .replaceAll('{city}', player.location.city)
      .replaceAll('{country}', player.location.country);
}
