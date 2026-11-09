/// The two kinds of talent a player can hold.
enum TalentArchetype {
  innate(
    'Innate',
    'Rare natural gifts that make a player extra special. Not every player '
        'has one, and no player can have more than one.',
  ),
  logic(
    'Logic',
    'Learned skills built on football IQ, space and timing. Any player can '
        'have them, up to two.',
  );

  const TalentArchetype(this.label, this.description);

  final String label;
  final String description;
}

/// A special trait that bends the match rules when it triggers.
class Talent {
  const Talent({
    required this.id,
    required this.name,
    required this.archetype,
    required this.description,
    this.alias,
  });

  final String id;
  final String name;

  /// Secondary name, e.g. "The Knock-On".
  final String? alias;

  final TalentArchetype archetype;

  /// What the talent does in a match (shown to players).
  final String description;
}
