/// The foot a player prefers. The other one is their weak foot (the
/// Ambidextrous Chaos talent removes that penalty).
enum Foot {
  left('Left'),
  right('Right');

  const Foot(this.label);

  final String label;
}

/// Who the player is: chosen on the first screen of a new career.
class PlayerIdentity {
  const PlayerIdentity({
    required this.name,
    required this.shirtName,
    required this.foot,
  });

  static const int minNameLength = 2;
  static const int maxNameLength = 24;
  static const int maxShirtLength = 12;

  /// Used for saves made before players had names.
  static const PlayerIdentity unnamed = PlayerIdentity(
    name: 'Player',
    shirtName: 'PLAYER',
    foot: Foot.right,
  );

  final String name;

  /// Printed on the shirt and used in commentary. Always upper case.
  final String shirtName;

  final Foot foot;

  // Letters from any alphabet, plus spaces, hyphens, apostrophes and dots
  // (e.g. "Jean-Luc", "N'Golo", "J. Smith").
  static final _nameChars = RegExp(r"^\p{L}[\p{L} '\-.]*$", unicode: true);
  static final _shirtChars = RegExp(r"^\p{L}[\p{L} '\-]*$", unicode: true);

  /// Trims and collapses runs of spaces.
  static String tidy(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Why [raw] can't be used as a name, or null if it's fine.
  static String? nameError(String raw) {
    final name = tidy(raw);
    if (name.length < minNameLength) return 'Enter at least 2 letters.';
    if (name.length > maxNameLength) {
      return 'Keep it to $maxNameLength characters.';
    }
    if (!_nameChars.hasMatch(name)) {
      return 'Use letters, spaces, hyphens or apostrophes.';
    }
    return null;
  }

  /// Why [raw] can't be used as a shirt name, or null if it's fine.
  /// Empty is fine: the suggestion is used instead.
  static String? shirtError(String raw) {
    final shirt = tidy(raw);
    if (shirt.isEmpty) return null;
    if (shirt.length > maxShirtLength) {
      return 'Keep it to $maxShirtLength characters.';
    }
    if (!_shirtChars.hasMatch(shirt)) {
      return 'Use letters, spaces, hyphens or apostrophes.';
    }
    return null;
  }

  /// Default shirt name: the last word of the name, upper case.
  static String suggestShirt(String rawName) {
    final words = tidy(rawName).split(' ');
    final last = words.last.replaceAll('.', '');
    final shirt = last.toUpperCase();
    return shirt.length > maxShirtLength
        ? shirt.substring(0, maxShirtLength)
        : shirt;
  }

  /// Builds an identity from raw form input. Call only after [nameError] and
  /// [shirtError] return null.
  factory PlayerIdentity.fromInput({
    required String name,
    required String shirtName,
    required Foot foot,
  }) {
    assert(nameError(name) == null && shirtError(shirtName) == null);
    final shirt = tidy(shirtName);
    return PlayerIdentity(
      name: tidy(name),
      shirtName: (shirt.isEmpty ? suggestShirt(name) : shirt).toUpperCase(),
      foot: foot,
    );
  }
}
