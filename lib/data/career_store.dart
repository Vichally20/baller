import 'dart:convert';

import 'package:baller/game/models/player.dart';
import 'package:baller/game/save/player_codec.dart';
import 'package:baller/game/world/world_save_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves careers on the device with shared_preferences, in [slotCount] slots.
///
/// A slot is written when a career starts. The title screen reads all slots
/// to offer "Continue career" and to choose where a new career goes.
class CareerStore {
  const CareerStore({this.codec = const PlayerCodec()});

  static const int slotCount = 2;

  /// Key used before slots existed; migrated into slot 0 on first load.
  static const String _legacyKey = 'career.player';

  static String _key(int slot) => 'career.slot.$slot';
  static String _worldKey(int slot) => 'career.world.$slot';

  final PlayerCodec codec;

  /// Every slot in order; null where a slot is empty or unreadable.
  Future<List<Player?>> loadSlots() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    return [
      for (var slot = 0; slot < slotCount; slot++)
        _decode(prefs.getString(_key(slot))),
    ];
  }

  Future<void> save(int slot, Player player) async {
    _checkSlot(slot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(slot), jsonEncode(codec.toJson(player)));
  }

  /// Loads world mutations (transfers and player changes) for this slot.
  Future<WorldSaveState> loadWorldState(int slot) async {
    _checkSlot(slot);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_worldKey(slot));
    if (raw == null) return WorldSaveState.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return WorldSaveState.fromJson(decoded);
      }
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable world state save: $e');
    }
    return WorldSaveState.empty;
  }

  /// Saves world mutations for this slot.
  Future<void> saveWorldState(int slot, WorldSaveState state) async {
    _checkSlot(slot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_worldKey(slot), jsonEncode(state.toJson()));
  }

  Future<void> clear(int slot) async {
    _checkSlot(slot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(slot));
    await prefs.remove(_worldKey(slot));
  }

  /// Index of the first empty slot, or null when every slot is taken.
  static int? firstEmpty(List<Player?> slots) {
    final index = slots.indexOf(null);
    return index == -1 ? null : index;
  }

  Player? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return codec.fromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable career save: $e');
      return null;
    }
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final legacy = prefs.getString(_legacyKey);
    if (legacy == null) return;
    if (prefs.getString(_key(0)) == null) {
      await prefs.setString(_key(0), legacy);
    }
    await prefs.remove(_legacyKey);
  }

  static void _checkSlot(int slot) {
    if (slot < 0 || slot >= slotCount) {
      throw RangeError.range(slot, 0, slotCount - 1, 'slot');
    }
  }
}
