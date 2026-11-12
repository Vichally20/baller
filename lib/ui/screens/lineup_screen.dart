import 'dart:math';

import 'package:baller/data/world_repository.dart';
import 'package:baller/game/match/lineup.dart';
import 'package:baller/game/match/match_engine.dart';
import 'package:baller/game/match/matchup.dart';
import 'package:baller/game/models/player.dart';
import 'package:baller/game/story/story_engine.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/ui/screens/match_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';

/// Before every match: both starting elevens on the pitch, theirs at the
/// top and yours at the bottom, in their managers' formations. Kicking off
/// plays the match; finishing it returns straight to the hub.
class LineupScreen extends StatefulWidget {
  const LineupScreen({
    super.key,
    required this.player,
    required this.slot,
    required this.event,
    this.seed,
  });

  final Player player;
  final int slot;
  final MatchEvent event;

  /// Passed on to the match, for deterministic tests.
  final int? seed;

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  late final Matchup? _matchup = matchupFor(
    widget.player,
    WorldRepository.forSeed(widget.player.worldSeed),
    opponentName: widget.event.match.opponent,
    // League rounds get their own squads; story matches use their place in
    // the story.
    eventIndex: widget.event.isSeason
        ? 100000 +
              widget.player.season.season * 100 +
              widget.player.season.round
        : widget.player.status.eventIndex,
    fixture: widget.event.fixture,
  );

  /// Built only to read the elevens, so they are exactly the ones the
  /// match engine plays.
  late final MatchSim _preview = MatchSim(
    shirtName: widget.player.identity.shirtName,
    user: widget.player,
    homeClub: _matchup?.home,
    awayClub: _matchup?.away,
    userPosition: _matchup?.userPosition,
    random: Random(0),
  );

  Future<void> _kickOff({bool simulate = false}) async {
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          player: widget.player,
          slot: widget.slot,
          event: widget.event,
          matchup: _matchup,
          seed: widget.seed,
          simulate: simulate,
        ),
      ),
    );
    if (finished == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.event.match;
    final home = _preview.homeEleven;
    final away = _preview.awayEleven;
    final shirt = widget.player.identity.shirtName;
    return AlabasterPage(
      title: 'Line-ups',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(match.title.toUpperCase(), style: AppText.caps()),
            const SizedBox(height: 8),
            _TeamLine(name: match.opponent, formation: away.formation),
            const SizedBox(height: 8),
            Expanded(
              child: _Pitch(
                home: home,
                away: away,
                userName: shirt.isEmpty ? 'You' : shirt,
              ),
            ),
            const SizedBox(height: 8),
            _TeamLine(
              name: _matchup?.home.name ?? 'Your side',
              formation: home.formation,
              yours: true,
            ),
          ],
        ),
      ),
      bottom: Row(
        children: [
          Expanded(
            child: PillButton(
              label: 'Simulate',
              leading: Icons.fast_forward_rounded,
              secondary: true,
              onPressed: () => _kickOff(simulate: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label:
                  widget.player.match?.key ==
                      matchKey(widget.player, widget.event)
                  ? 'Resume'
                  : 'Kick off',
              trailingArrow: true,
              onPressed: _kickOff,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.name,
    required this.formation,
    this.yours = false,
  });

  final String name;
  final String formation;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: yours ? AppColors.mint : Colors.transparent,
            border: Border.all(color: AppColors.charcoal, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: AppText.inter(14, weight: 600),
          ),
        ),
        const SizedBox(width: 8),
        Text(formation, style: AppText.inter(13, color: AppColors.muted)),
      ],
    );
  }
}

/// The charcoal pitch with both elevens.
class _Pitch extends StatelessWidget {
  const _Pitch({
    required this.home,
    required this.away,
    required this.userName,
  });

  final Lineup home;
  final Lineup away;
  final String userName;

  static const double _dot = 26;
  static const double _labelWidth = 74;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ColoredBox(
        color: AppColors.charcoal,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            Map<String, int> countSurnames(Lineup lineup) {
              final counts = <String, int>{};
              for (final p in lineup.players) {
                final s = _surname(p.name);
                counts[s] = (counts[s] ?? 0) + 1;
              }
              return counts;
            }

            final ourSurnames = countSurnames(home);
            final theirSurnames = countSurnames(away);

            /// "Lawal", or "B. Lawal" when two teammates share the surname.
            String label(SquadPlayer p, {required bool ours}) {
              final s = _surname(p.name);
              final shared = ((ours ? ourSurnames : theirSurnames)[s] ?? 0) > 1;
              return shared ? '${p.name[0]}. $s' : s;
            }

            // Theirs attack downwards from the top, so left and right swap.
            Widget marker(LineupSpot spot, {required bool ours}) {
              final x = ours ? spot.slot.x : 1 - spot.slot.x;
              final y = ours
                  ? h * (0.93 - spot.slot.depth * 0.38)
                  : h * (0.06 + spot.slot.depth * 0.36);
              final left = (x * w - _labelWidth / 2).clamp(
                0.0,
                w - _labelWidth,
              );
              return Positioned(
                left: left,
                top: y - _dot / 2,
                width: _labelWidth,
                child: _Marker(
                  name: spot.isUser
                      ? userName
                      : label(spot.player!, ours: ours),
                  role: spot.slot.role.code,
                  ours: ours,
                  isUser: spot.isUser,
                ),
              );
            }

            return Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PitchLines()),
                ),
                for (final spot in away.spots) marker(spot, ours: false),
                for (final spot in home.spots) marker(spot, ours: true),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _surname(String name) => name.trim().split(' ').last;
}

/// A player: a ring (filled for the user) and their name.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.name,
    required this.role,
    required this.ours,
    required this.isUser,
  });

  final String name;
  final String role;
  final bool ours;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ours
          ? (isUser ? 'You, $role' : '$name, $role')
          : 'Opponent $name, $role',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _Pitch._dot,
            height: _Pitch._dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUser ? AppColors.mint : Colors.transparent,
              border: Border.all(
                color: isUser
                    ? AppColors.mint
                    : ours
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                width: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.inter(
              11,
              weight: isUser ? 700 : 500,
              // Theirs a shade dimmer, so the two sides stay easy to tell
              // apart.
              color: isUser
                  ? AppColors.mint
                  : ours
                  ? AppColors.onDarkSoft
                  : AppColors.onDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint pitch markings: halfway line, centre circle, both boxes.
class _PitchLines extends CustomPainter {
  const _PitchLines();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final w = size.width;
    final h = size.height;
    const inset = 12.0;
    canvas.drawRRect(
      RRect.fromLTRBR(
        inset,
        inset,
        w - inset,
        h - inset,
        const Radius.circular(18),
      ),
      paint,
    );
    canvas.drawLine(Offset(inset, h / 2), Offset(w - inset, h / 2), paint);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.14, paint);
    for (final top in [true, false]) {
      final boxW = w * 0.56;
      final boxH = h * 0.13;
      final goalW = w * 0.28;
      final goalH = h * 0.05;
      final y = top ? inset : h - inset;
      final dir = top ? 1 : -1;
      canvas.drawRect(
        Rect.fromLTWH((w - boxW) / 2, top ? y : y - boxH, boxW, boxH),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH((w - goalW) / 2, top ? y : y - goalH, goalW, goalH),
        paint,
      );
      canvas.drawCircle(Offset(w / 2, y + dir * boxH * 0.72), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_PitchLines oldDelegate) => false;
}
