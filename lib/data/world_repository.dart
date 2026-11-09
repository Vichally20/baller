import 'package:baller/game/world/world_generator.dart';
import 'package:baller/game/world/world_models.dart';
import 'package:baller/game/world/world_save_state.dart';

/// Generates a career's world on first use and keeps it (one per slot at
/// most, so two careers never hold more than two worlds in memory).
abstract final class WorldRepository {
  static final Map<int, World> _cache = {};

  static World forSeed(int seed, {WorldSaveState? saveState}) {
    final cached = _cache[seed];
    if (cached != null) {
      if (saveState != null) cached.applySaveState(saveState);
      return cached;
    }
    if (_cache.length >= 2) _cache.remove(_cache.keys.first);
    final world = generateWorld(seed);
    if (saveState != null) world.applySaveState(saveState);
    return _cache[seed] = world;
  }

  static void clearCache() => _cache.clear();
}
