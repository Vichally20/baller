import 'package:baller/data/career_store.dart';
import 'package:baller/game/world/world_generator.dart';
import 'package:baller/game/world/world_save_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('World.transferPlayer moves player and updates squad rosters', () {
    final world = generateWorld(123);
    final clubA = world.clubs.first;
    final clubB = world.clubs.elementAt(1);

    final playerToMove = clubA.squad.first;
    final originalClubACount = clubA.squad.length;
    final originalClubBCount = clubB.squad.length;

    final success = world.transferPlayer(
      playerId: playerToMove.id,
      toClubId: clubB.id,
    );

    expect(success, isTrue);
    expect(clubA.squad.length, originalClubACount - 1);
    expect(clubB.squad.length, originalClubBCount + 1);

    final movedPlayerInB = clubB.squad.firstWhere((p) => p.id == playerToMove.id);
    expect(movedPlayerInB.clubId, clubB.id);
    expect(clubA.squad.any((p) => p.id == playerToMove.id), isFalse);
  });

  test('WorldSaveState round-trips to and from JSON', () {
    final world = generateWorld(999);
    final player = world.clubs.first.squad.first;

    final transfer = TransferRecord(
      playerId: player.id,
      playerName: player.name,
      fromClubId: player.clubId,
      toClubId: world.clubs.last.id,
      fee: 15000000,
      date: '2026-08-15',
    );

    final modified = player.copyWith(wage: 95000, contractYears: 4);

    final state = WorldSaveState(
      transfers: [transfer],
      modifiedPlayers: {modified.id: modified},
    );

    final json = state.toJson();
    final loaded = WorldSaveState.fromJson(json);

    expect(loaded.transfers, hasLength(1));
    expect(loaded.transfers.first.playerId, player.id);
    expect(loaded.transfers.first.fee, 15000000);
    expect(loaded.modifiedPlayers.containsKey(player.id), isTrue);
    expect(loaded.modifiedPlayers[player.id]!.wage, 95000);
    expect(loaded.modifiedPlayers[player.id]!.contractYears, 4);
  });

  test('CareerStore saves and loads WorldSaveState per slot', () async {
    const store = CareerStore();
    final world = generateWorld(42);
    final player = world.clubs.first.squad.first;

    final modified = player.copyWith(wage: 120000);
    final state = WorldSaveState(
      transfers: [
        TransferRecord(
          playerId: player.id,
          playerName: player.name,
          fromClubId: player.clubId,
          toClubId: 'spain-1-0',
          fee: 25000000,
        ),
      ],
      modifiedPlayers: {player.id: modified},
    );

    await store.saveWorldState(0, state);
    final loaded = await store.loadWorldState(0);

    expect(loaded.transfers, hasLength(1));
    expect(loaded.transfers.first.toClubId, 'spain-1-0');
    expect(loaded.modifiedPlayers[player.id]!.wage, 120000);

    // Slot 1 is still empty
    final slot1State = await store.loadWorldState(1);
    expect(slot1State.transfers, isEmpty);
    expect(slot1State.modifiedPlayers, isEmpty);

    // Clearing slot 0 clears world state too
    await store.clear(0);
    final clearedState = await store.loadWorldState(0);
    expect(clearedState.transfers, isEmpty);
  });

  test('World.applySaveState restores modifications', () {
    final world = generateWorld(555);
    final clubA = world.clubs.first;
    final clubB = world.clubs.last;
    final player = clubA.squad.first;

    // Simulate saved transfer of player to clubB with bumped wage
    final updated = player.copyWith(
      clubId: clubB.id,
      wage: 200000,
    );

    final saveState = WorldSaveState(
      transfers: [
        TransferRecord(
          playerId: player.id,
          playerName: player.name,
          fromClubId: clubA.id,
          toClubId: clubB.id,
          fee: 50000000,
        ),
      ],
      modifiedPlayers: {player.id: updated},
    );

    world.applySaveState(saveState);

    expect(clubA.squad.any((p) => p.id == player.id), isFalse);
    final playerInB = clubB.squad.firstWhere((p) => p.id == player.id);
    expect(playerInB.clubId, clubB.id);
    expect(playerInB.wage, 200000);
  });
}

