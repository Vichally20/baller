import 'package:baller/game/models/placement.dart';

/// The player's life off the pitch: agent, talks with the manager, and a
/// move agreed for the end of the season.
class Life {
  const Life({
    this.agent = false,
    this.playWish = false,
    this.lastTalk,
    this.transfer,
  });

  static const start = Life();

  /// An agent negotiates better contracts and finds sponsors, for
  /// [agentCut] of the wages.
  final bool agent;

  /// The manager agreed to play the player in their preferred position.
  final bool playWish;

  /// The week the manager was last asked something ("S1R4", "E3"); one
  /// talk a week.
  final String? lastTalk;

  /// A move agreed with another club, completed when the season ends.
  final PendingTransfer? transfer;

  Life copyWith({
    bool? agent,
    bool? playWish,
    String? lastTalk,
    PendingTransfer? transfer,
    bool clearTransfer = false,
  }) => Life(
    agent: agent ?? this.agent,
    playWish: playWish ?? this.playWish,
    lastTalk: lastTalk ?? this.lastTalk,
    transfer: clearTransfer ? null : (transfer ?? this.transfer),
  );

  Map<String, Object?> toJson() => {
    'agent': agent,
    'playWish': playWish,
    'lastTalk': ?lastTalk,
    'transfer': ?transfer?.toJson(),
  };

  /// Null when [json] is malformed.
  static Life? fromJson(Object? json) {
    if (json case {
      'agent': final bool agent,
      'playWish': final bool playWish,
    }) {
      final lastTalk = json['lastTalk'];
      if (lastTalk != null && lastTalk is! String) return null;
      PendingTransfer? transfer;
      if (json['transfer'] case final Object raw) {
        transfer = PendingTransfer.fromJson(raw);
        if (transfer == null) return null;
      }
      return Life(
        agent: agent,
        playWish: playWish,
        lastTalk: lastTalk as String?,
        transfer: transfer,
      );
    }
    return null;
  }
}

/// The agent's share of the wages.
const double agentCut = 0.15;

/// A move to [clubId] on [contract], once the season is over.
class PendingTransfer {
  const PendingTransfer({required this.clubId, required this.contract});

  final String clubId;
  final Contract contract;

  Map<String, Object?> toJson() => {
    'club': clubId,
    'contract': contract.toJson(),
  };

  static PendingTransfer? fromJson(Object? json) {
    if (json case {'club': final String club, 'contract': final Object raw}) {
      final contract = Contract.fromJson(raw);
      return contract == null
          ? null
          : PendingTransfer(clubId: club, contract: contract);
    }
    return null;
  }
}
