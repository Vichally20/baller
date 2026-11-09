import 'dart:convert';

import 'package:baller/game/story/story_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the story from assets/content/ once and keeps it.
class StoryRepository {
  StoryRepository._();

  static Future<StoryContent>? _cache;

  static Future<StoryContent> load({AssetBundle? bundle}) =>
      _cache ??= _load(bundle ?? rootBundle);

  /// Forget the loaded story. Tests call this so each starts fresh.
  @visibleForTesting
  static void resetCache() => _cache = null;

  static Future<StoryContent> _load(AssetBundle bundle) async {
    // cache: false — [_cache] already keeps the parsed story, and the
    // bundle's own cache can hold futures from a previous test run.
    Future<Object?> json(String path) async => jsonDecode(
      await bundle.loadString('assets/content/$path', cache: false),
    );

    final story = await json('story.json');
    final files = switch (story) {
      {'chapters': final List<Object?> files} => files.cast<String>(),
      _ => throw const FormatException('story.json: expected "chapters"'),
    };
    return StoryContent.fromJson(
      itemsJson: await json('items.json'),
      chapterJson: [for (final file in files) (file, await json(file))],
    );
  }
}
