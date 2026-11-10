import 'package:baller/data/career_store.dart';
import 'package:baller/data/story_repository.dart';
import 'package:baller/data/world_repository.dart';
import 'package:baller/game/career/calendar.dart';
import 'package:baller/game/career/contracts.dart';
import 'package:baller/game/career/life_actions.dart';
import 'package:baller/game/career/pathway.dart';
import 'package:baller/game/career/season.dart';
import 'package:baller/game/models/attribute.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/career_status.dart';
import 'package:baller/game/story/story_content.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:baller/game/world/league_countries.dart';
import 'package:baller/game/world/player_value.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/screens/club_screen.dart';
import 'package:baller/ui/screens/leagues_screen.dart';
import 'package:baller/ui/screens/life_screen.dart';
import 'package:baller/ui/screens/lineup_screen.dart';
import 'package:baller/ui/screens/pathway_screen.dart';
import 'package:baller/ui/screens/scenario_screen.dart';
import 'package:baller/ui/screens/season_screen.dart';
import 'package:baller/ui/screens/signing_screen.dart';
import 'package:baller/ui/screens/talent_glossary_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:baller/ui/widgets/club_crest.dart';
import 'package:baller/ui/widgets/stars.dart';
import 'package:baller/ui/widgets/talent_tile.dart';
import 'package:flutter/material.dart';

/// The career hub: what's next in the story, the player's status, and their
/// profile.
class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key, required this.player, required this.slot});

  final Player player;

  /// Save slot this career lives in.
  final int slot;

  static Route<void> route(Player player, int slot) => MaterialPageRoute(
    builder: (_) => CareerScreen(player: player, slot: slot),
  );

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  late Player _player = widget.player;
  final Future<StoryContent> _content = StoryRepository.load();

  Future<void> _play(StoryEvent event, StoryContent content) async {
    final screen = switch (event) {
      ScenarioEvent() => ScenarioScreen(
        player: _player,
        slot: widget.slot,
        event: event,
        items: content.items,
      ),
      // The line-ups first; kicking off from there plays the match.
      MatchEvent() => LineupScreen(
        player: _player,
        slot: widget.slot,
        event: event,
      ),
    };
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    // The event screen saved any progress; pick it up.
    final saved = (await const CareerStore().loadSlots())[widget.slot];
    if (saved != null && mounted) setState(() => _player = saved);
  }

  Future<void> _openLife(bool inSeason) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LifeScreen(player: _player, slot: widget.slot, inSeason: inSeason),
      ),
    );
    final saved = (await const CareerStore().loadSlots())[widget.slot];
    if (saved != null && mounted) setState(() => _player = saved);
  }

  @override
  Widget build(BuildContext context) {
    return AlabasterPage(
      showBack: false,
      body: FutureBuilder<StoryContent>(
        future: _content,
        builder: (context, snapshot) {
          final content = snapshot.data;
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error!);
          }
          if (content == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final player = _player;
          final world = WorldRepository.forSeed(player.worldSeed);
          final club = careerClubOf(player, world);
          final schedule = buildSchedule(content, player);
          final index = player.status.eventIndex;
          final next = index < schedule.length ? schedule[index] : null;
          // Season mode starts once the written story runs out.
          final season = seasonFor(player, world, player.season);
          final Widget main;
          if (club == null) {
            // A career from before pathways (or with a lost club).
            main = _ActionCard(
              caps: 'YOUR PATHWAY',
              title: 'Choose your path',
              text: 'The scouts have been talking. See which clubs want you.',
              action: 'See your pathway',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PathwayScreen(player: player, slot: widget.slot),
                ),
              ),
            );
          } else if (trialVerdictDue(schedule, player)) {
            main = _ActionCard(
              caps: 'TRIAL VERDICT',
              title: 'The coaches have decided',
              text: 'Your trial at ${club.name} is over.',
              action: 'Hear the verdict',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SigningScreen(
                    // The club's contract offer comes with the verdict.
                    player: player.withPlacement(
                      club.placement.sign(
                        offerContract(
                          player: player,
                          club: club.club,
                          kind: club.placement.kind,
                          startSeason: player.season.season,
                          agent: player.life.agent,
                        ),
                      ),
                    ),
                    slot: widget.slot,
                    reason: SigningReason.trialVerdict,
                  ),
                ),
              ),
            );
          } else if (next != null) {
            main = _UpNext(
              event: next,
              cycle: cycleOf(schedule, index),
              resume: player.match?.key == matchKey(player, next),
              onPlay: () => _play(next, content),
            );
          } else if (season != null && !season.isOver) {
            final round = seasonRound(content, player, season);
            final at = player.season.scenesPlayed.clamp(0, round.length - 1);
            main = _UpNext(
              event: round[at],
              cycle: (events: round, position: at),
              resume: player.match?.key == matchKey(player, round[at]),
              onPlay: () => _play(round[at], content),
            );
          } else if (season != null) {
            final n = season.progress.season;
            // Summer: wages, a year older, and any agreed move.
            final summer = endOfSeason(player, world);
            final aged = summer.growth;
            final age = aged.attributes.age;
            final move = summer.newClub;
            main = _ActionCard(
              caps: 'SEASON $n OVER',
              title: 'You finished ${ordinal(season.position)}',
              text:
                  '${season.sideName(season.club)} ended season $n in '
                  '${ordinal(season.position)} place in the '
                  '${season.leagueName}. Over the summer you turn $age'
                  '${aged.isEmpty ? '.' : ': ${aged.describe()}.'}'
                  '${move == null ? '' : ' You join ${move.name}.'}',
              action: 'Start season ${n + 1}',
              onPressed: () async {
                final next = summer.player;
                await const CareerStore().save(widget.slot, next);
                if (mounted) setState(() => _player = next);
              },
            );
          } else {
            main = const _ToBeContinued();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _Header(
                player: player,
                chapter:
                    next?.chapter.title ??
                    (season == null
                        ? null
                        : 'Season ${season.progress.season}'),
              ),
              const SizedBox(height: 16),
              main,
              if (club != null) ...[
                const SizedBox(height: 16),
                _ClubCard(club: club),
              ],
              if (season != null && next == null) ...[
                const SizedBox(height: 16),
                _SeasonCard(season: season),
              ],
              const SizedBox(height: 16),
              _LifeCard(
                player: player,
                world: world,
                inSeason: season != null && next == null,
                onOpen: () => _openLife(season != null && next == null),
              ),
              const SizedBox(height: 16),
              _StatusCard(status: _player.status),
              const SizedBox(height: 16),
              _WorldCard(player: _player),
              const SizedBox(height: 16),
              _ProfileCard(player: _player),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.player, required this.chapter});

  final Player player;
  final String? chapter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter == null ? 'Your career' : 'Your career · $chapter',
                style: AppText.inter(12, color: AppColors.muted),
              ),
              Text(
                player.identity.name,
                style: AppText.manrope(20, weight: 600),
              ),
            ],
          ),
        ),
        Text(
          'BALLER',
          style: AppText.manrope(
            14,
            weight: 800,
            letterSpacing: 4,
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

/// Charcoal card for the next scenario or match, with scene/match progress.
class _UpNext extends StatelessWidget {
  const _UpNext({
    required this.event,
    required this.cycle,
    required this.onPlay,
    this.resume = false,
  });

  final StoryEvent event;
  final ({List<StoryEvent> events, int position}) cycle;
  final VoidCallback onPlay;

  /// The match was started and left: carry on where it stopped.
  final bool resume;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, action) = switch (event) {
      ScenarioEvent(:final scenario, :final number) => (
        scenario.title,
        'Scene $number',
        'Play scene',
      ),
      MatchEvent(:final match) => (
        match.title,
        'vs ${match.opponent}',
        resume ? 'Resume match' : 'Play match',
      ),
    };
    return HeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UP NEXT · ${event.chapter.title.toUpperCase()}',
            style: AppText.caps(color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 8),
          Text(title, style: AppText.display(34, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.inter(14, color: AppColors.onDarkSoft)),
          const SizedBox(height: 18),
          _CycleSteps(cycle: cycle),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(action, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Scene · Scene · Match" progress pills for the current run of events.
class _CycleSteps extends StatelessWidget {
  const _CycleSteps({required this.cycle});

  final ({List<StoryEvent> events, int position}) cycle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, e) in cycle.events.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < cycle.position
                        ? AppColors.mint
                        : i == cycle.position
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e is MatchEvent ? 'Match' : 'Scene',
                  style: AppText.inter(
                    11,
                    weight: 600,
                    color: i == cycle.position
                        ? Colors.white
                        : AppColors.onDarkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Charcoal card with one action: choose a pathway, hear a verdict.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.caps,
    required this.title,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String caps;
  final String title;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caps, style: AppText.caps(color: AppColors.onDarkMuted)),
          const SizedBox(height: 8),
          Text(title, style: AppText.display(34, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            text,
            style: AppText.inter(14, height: 1.43, color: AppColors.onDarkSoft),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(action, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The player's club (or trial club) and where the manager plays them.
class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});

  final CareerClub club;

  @override
  Widget build(BuildContext context) {
    final c = club.club;
    final placement = club.placement;
    final decision = club.decision;
    return SoftCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => ClubScreen(club: c))),
      child: Row(
        children: [
          ClubCrest(initials: c.initials),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placement.signed ? 'YOUR CLUB' : 'ON TRIAL AT',
                  style: AppText.caps(),
                ),
                Text(club.name, style: AppText.manrope(17, weight: 600)),
                Text(
                  placement.signed
                      ? 'Plays you at ${decision.position.label}'
                            '${decision.honoured ? ', as you wanted' : ''}'
                      : '${c.country.label} · Division ${c.division} club',
                  style: AppText.inter(13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Stars(count: c.stars),
        ],
      ),
    );
  }
}

/// League position and record, with the full table a tap away.
class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    final row = season.table.firstWhere((r) => r.club.id == season.club.id);
    final played = season.progress.round;
    return SoftCard(
      child: Row(
        children: [
          const IconDisc(icon: Icons.leaderboard_outlined, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  played == 0
                      ? season.leagueName
                      : '${ordinal(season.position)} · ${row.points} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(18, weight: 600),
                ),
                Text(
                  played == 0
                      ? 'Season ${season.progress.season} · not started'
                      : 'W${row.won} D${row.drawn} L${row.lost} · '
                            '$played of ${season.rounds.length} played',
                  style: AppText.inter(13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SeasonScreen(season: season),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: AppText.inter(14, weight: 600),
            ),
            child: const Text('Table'),
          ),
        ],
      ),
    );
  }
}

/// The date, money and the next payday, with the player screen a tap away.
class _LifeCard extends StatelessWidget {
  const _LifeCard({
    required this.player,
    required this.world,
    required this.inSeason,
    required this.onOpen,
  });

  final Player player;
  final World world;
  final bool inSeason;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final date = today(player.season, inSeason: inSeason);
    final income = monthlyIncome(player, world);
    return SoftCard(
      onTap: onOpen,
      child: Row(
        children: [
          const IconDisc(icon: Icons.person_outline, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your life', style: AppText.manrope(18, weight: 600)),
                Text(
                  formatDate(date),
                  style: AppText.inter(13, color: AppColors.muted),
                ),
                Text(
                  income.total > 0
                      ? '${formatWage(player.status.money)} · '
                            '+${formatWage(income.total)} on '
                            '${formatDate(payday(date))}'
                      : formatWage(player.status.money),
                  style: AppText.inter(13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _ToBeContinued extends StatelessWidget {
  const _ToBeContinued();

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UP NEXT', style: AppText.caps(color: AppColors.onDarkMuted)),
          const SizedBox(height: 8),
          Text(
            'To be continued',
            style: AppText.display(34, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "You've played every chapter written so far.",
            style: AppText.inter(14, color: AppColors.onDarkSoft),
          ),
        ],
      ),
    );
  }
}

/// Entry to the leagues, with the player's market value.
class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.player});

  final Player player;

  void _open(BuildContext context) {
    final world = WorldRepository.forSeed(player.worldSeed);
    final home = LeagueCountry.values
        .where((c) => c.label == player.location.country)
        .firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaguesScreen(world: world, initialCountry: home),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagues = LeagueCountry.values.length;
    // Valued at your club once you've signed; unattached before that.
    final career = careerClubOf(
      player,
      WorldRepository.forSeed(player.worldSeed),
    );
    final club = career != null && career.placement.signed ? career.club : null;
    return SoftCard(
      child: Row(
        children: [
          const IconDisc(icon: Icons.public, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The world', style: AppText.manrope(18, weight: 600)),
                Text(
                  '$leagues leagues · your value '
                  '${formatEuros(playerMarketValue(player, club: club))}',
                  style: AppText.inter(13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _open(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: AppText.inter(14, weight: 600),
            ),
            child: const Text('Leagues'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final CareerStatus status;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Status', style: AppText.manrope(18, weight: 600)),
              ),
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                formatWage(status.money),
                style: AppText.inter(16, weight: 600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Meter(label: 'Morale', value: status.morale),
          _Meter(label: 'Coach', value: status.coach),
          _Meter(label: 'Teammates', value: status.teammates),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppText.inter(14, color: AppColors.mutedStrong),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value / CareerStatus.meterMax,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: AppText.inter(16, weight: 600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the player started, talents and attributes.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final stats = player.attributes;
    final talents = [?player.innateTalent, ...player.logicTalents];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: AppText.manrope(18, weight: 600),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .push(TalentGlossaryScreen.route()),
                      child: const Text('All talents'),
                    ),
                  ],
                ),
                Text(
                  '${player.location.city}, ${player.location.country} · '
                  'Age ${stats.age} · ${player.identity.foot.label} foot',
                  style: AppText.inter(14, color: AppColors.mutedStrong),
                ),
                Text(
                  '${player.tier.label} · wants to play '
                  '${player.preferredPosition.label}',
                  style: AppText.inter(14, color: AppColors.mutedStrong),
                ),
                const SizedBox(height: 10),
                for (final attribute in Attribute.values.where(
                  (a) => a.isSkill,
                ))
                  _Meter(label: attribute.label, value: stats[attribute]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('TALENTS', style: AppText.caps()),
          ),
          if (talents.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'No talents yet.',
                style: AppText.inter(14, color: AppColors.muted),
              ),
            ),
          for (final talent in talents) TalentTile(talent: talent),
        ],
      ),
    );
  }
}

/// Shown when a content file has a mistake, so writers see it in the app.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load the story",
              style: AppText.manrope(18, weight: 600),
            ),
            const SizedBox(height: 8),
            Text(
              error is FormatException
                  ? (error as FormatException).message
                  : '$error',
              style: AppText.inter(
                14,
                height: 1.5,
                color: AppColors.mutedStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
