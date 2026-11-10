import 'package:baller/game/world/world_models.dart';

/// Represents a transfer between clubs in this career.
class TransferRecord {
  const TransferRecord({
    required this.playerId,
    required this.playerName,
    required this.fromClubId,
    required this.toClubId,
    required this.fee,
    this.date,
  });

  final String playerId;
  final String playerName;
  final String fromClubId;
  final String toClubId;
  final int fee;
  final String? date;

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'fromClubId': fromClubId,
    'toClubId': toClubId,
    'fee': fee,
    if (date != null) 'date': date,
  };

  factory TransferRecord.fromJson(Map<String, Object?> json) => TransferRecord(
    playerId: json['playerId'] as String,
    playerName: json['playerName'] as String,
    fromClubId: json['fromClubId'] as String,
    toClubId: json['toClubId'] as String,
    fee: json['fee'] as int,
    date: json['date'] as String?,
  );
}

/// Stores all world mutations (completed transfers, contract renewals,
/// and modified player attributes) for a specific career save slot.
class WorldSaveState {
  const WorldSaveState({
    this.transfers = const [],
    this.modifiedPlayers = const {},
  });

  static const empty = WorldSaveState();

  /// All completed transfers in this career.
  final List<TransferRecord> transfers;

  /// Players whose attributes, contract, or team changed from the generated baseline.
  final Map<String, SquadPlayer> modifiedPlayers;

  WorldSaveState recordTransfer(TransferRecord record, SquadPlayer player) =>
      WorldSaveState(
        transfers: [...transfers, record],
        modifiedPlayers: {...modifiedPlayers, player.id: player},
      );

  WorldSaveState updatePlayer(SquadPlayer player) => WorldSaveState(
    transfers: transfers,
    modifiedPlayers: {...modifiedPlayers, player.id: player},
  );

  Map<String, Object?> toJson() => {
    'transfers': [for (final t in transfers) t.toJson()],
    'modifiedPlayers': {
      for (final entry in modifiedPlayers.entries)
        entry.key: entry.value.toJson(),
    },
  };

  factory WorldSaveState.fromJson(Map<String, Object?> json) {
    final transfers = <TransferRecord>[];
    if (json['transfers'] case final List<Object?> list) {
      for (final item in list) {
        if (item is Map<String, Object?>) {
          transfers.add(TransferRecord.fromJson(item));
        }
      }
    }

    final modified = <String, SquadPlayer>{};
    if (json['modifiedPlayers'] case final Map<String, Object?> map) {
      for (final entry in map.entries) {
        if (entry.value is Map<String, Object?>) {
          final p = SquadPlayer.fromJson(entry.value);
          if (p != null) modified[entry.key] = p;
        }
      }
    }

    return WorldSaveState(
      transfers: List.unmodifiable(transfers),
      modifiedPlayers: Map.unmodifiable(modified),
    );
  }
}
