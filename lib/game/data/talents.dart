import 'package:baller/game/models/talent.dart';

// --- Rules ------------------------------------------------------------------

/// Max talents a player can hold of each archetype.
const int maxInnateTalents = 1;
const int maxLogicTalents = 2;

/// Chance a new player is born with an innate talent.
const double innateTalentChance = 0.30;

/// New players start with 0..this many logic talents (each count equally
/// likely); more can be learned during the career, up to [maxLogicTalents].
const int maxStartingLogicTalents = 2;

// --- Talents ----------------------------------------------------------------
// Inspirations (real players / Blue Lock) are design notes only — keep them in
// comments, never in player-facing text.

const List<Talent> allTalents = [
  // ===== Innate =====

  // Inspiration: Gareth Bale (vs. Marc Bartra, Copa del Rey), Rafael Leão.
  Talent(
    id: 'unstoppable_locomotive',
    name: 'Unstoppable Locomotive',
    alias: 'The Knock-On',
    archetype: TalentArchetype.innate,
    description:
        "When receiving the ball on the wing with open space ahead, the player "
        "rolls their Talent to push the ball 15 yards forward. This "
        "temporarily nullifies the opponent's Defence stat, turning the "
        "sequence into a pure Pace vs. Pace stat check.",
  ),
  // Inspiration: Didier Drogba, Victor Osimhen, Diego Costa.
  Talent(
    id: 'apex_bully',
    name: 'Apex Bully',
    alias: 'Target Man Dominance',
    archetype: TalentArchetype.innate,
    description:
        "When receiving a cross or a long ball, the player rolls Talent to "
        "trigger a physical wrestle. If successful, it temporarily reduces the "
        "marking defender's Physical stat to zero, guaranteeing the striker "
        "wins the header or holds up the ball.",
  ),
  // Inspiration: Eden Hazard, Vinícius Júnior, prime Sadio Mané.
  Talent(
    id: 'gravity_well',
    name: 'Gravity Well',
    alias: 'Sticky Feet / Ankle Breaker',
    archetype: TalentArchetype.innate,
    description:
        "The player invites tackles. When an opponent rolls to defend, a "
        "successful Talent roll by the striker creates a \"foul or get "
        "bypassed\" scenario. It debuffs the opponent's Defence stat for the "
        "rest of the match by destroying their confidence.",
  ),
  // Inspiration: Steven Gerrard, Federico Valverde, Wayne Rooney.
  Talent(
    id: 'artillery_strike',
    name: 'Artillery Strike',
    alias: 'Chaos Cannon',
    archetype: TalentArchetype.innate,
    description:
        "A long-range shooting trait. Instead of needing the team to build up "
        "a high Chance Quality inside the box, the player rolls Talent to "
        "unleash a 30-yard screamer. This bypasses the midfield entirely and "
        "pits pure Shot power against the goalkeeper.",
  ),
  // Inspiration: Ronaldo Nazário (R9) — the name is his nickname.
  Talent(
    id: 'el_fenomeno',
    name: 'El Fenómeno',
    alias: 'The Keeper Bypass',
    archetype: TalentArchetype.innate,
    description:
        "Triggers in 1-on-1 situations with the goalkeeper. Instead of rolling "
        "Shot against the goalkeeper's save stat, the striker rolls Dribble + "
        "Talent to round the keeper, resulting in an automatic tap-in with "
        "100% Chance Quality.",
  ),
  // Inspiration: Son Heung-min, Ousmane Dembélé, Santi Cazorla.
  Talent(
    id: 'ambidextrous_chaos',
    name: 'Ambidextrous Chaos',
    alias: 'Two-Footed Threat',
    archetype: TalentArchetype.innate,
    description:
        "Match logic normally forces attackers onto their weak foot, reducing "
        "their Shot stat by 20–30%. This trait removes the weak-foot penalty "
        "completely, so defensive positioning is useless: the player can "
        "shoot from any angle.",
  ),
  // Inspiration: Kylian Mbappé, Rafael Leão · Blue Lock: Chigiri Hyoma,
  // Zantetsu Tsurugi.
  Talent(
    id: 'hyper_speed',
    name: 'Hyper-Speed',
    alias: 'Explosive Acceleration',
    archetype: TalentArchetype.innate,
    description:
        "A massive temporary buff to the Pace stat that lets the player ignore "
        "off-the-ball positioning checks by simply outrunning the defence "
        "into open space.",
  ),
  // Inspiration: Zlatan Ibrahimović, Erling Haaland · Blue Lock: Ryusei Shido.
  Talent(
    id: 'acrobatic_finishing',
    name: 'Acrobatic Finishing',
    alias: 'Biological Finishing',
    archetype: TalentArchetype.innate,
    description:
        "Lets the player trigger a shot from impossible angles or chaotic "
        "crosses, bypassing the Chance Quality check entirely.",
  ),
  // Inspiration: Cristiano Ronaldo · Blue Lock: Shoei Barou, Michael Kaiser.
  Talent(
    id: 'predator_eye',
    name: 'Predator Eye',
    archetype: TalentArchetype.innate,
    description:
        "Focuses purely on the goalkeeper. The striker delays their shot until "
        "the exact moment the keeper's vision is blocked by a defender, "
        "reducing the goalkeeper's save stat to near zero.",
  ),
  // Inspiration: Dennis Bergkamp, Dimitar Berbatov · Blue Lock: Seishiro Nagi.
  Talent(
    id: 'black_hole_trapping',
    name: 'Black Hole Trapping',
    alias: 'Perfect First Touch',
    archetype: TalentArchetype.innate,
    description:
        "Turns terrible, low-quality passes into high-quality solo scoring "
        "chances by instantly killing the ball's momentum to bypass the first "
        "defender.",
  ),
  // Inspiration: Neymar, Ronaldinho, Lamine Yamal · Blue Lock: Meguru Bachira.
  Talent(
    id: 'elastic_dribbling',
    name: 'Elastic Dribbling',
    alias: 'Rhythm Dribbling',
    archetype: TalentArchetype.innate,
    description:
        "A highly unpredictable dribbling state where the player's Dribble "
        "stat multiplies based on how chaotic the defence is. It breaks "
        "standard defensive logic.",
  ),
  // Inspiration: Thierry Henry · Blue Lock: Rin Itoshi.
  Talent(
    id: 'puppeteer',
    name: 'Puppeteer',
    alias: 'Destructive Accuracy',
    archetype: TalentArchetype.innate,
    description:
        "Uses extreme Shot and Pass accuracy to force defenders and "
        "goalkeepers to move exactly where the striker wants them before "
        "curling the ball into the top corner.",
  ),

  // ===== Logic =====

  // Inspiration: Karim Benzema, Roberto Firmino, Harry Kane.
  Talent(
    id: 'tactical_vacuum',
    name: 'The Tactical Vacuum',
    alias: 'False 9',
    archetype: TalentArchetype.logic,
    description:
        "The striker intentionally drops deep into midfield. A successful "
        "Talent roll pulls the opponent's centre-backs out of position, "
        "temporarily removing their highest Defence stats from the box and "
        "giving big stat buffs to wingers who run into the empty space.",
  ),
  // Inspiration: Jude Bellingham, Frank Lampard, İlkay Gündoğan.
  Talent(
    id: 'the_ghost',
    name: 'The Ghost',
    alias: 'Late Arrival',
    archetype: TalentArchetype.logic,
    description:
        "The player stays out of the build-up, so no opponent is assigned to "
        "mark them. When a cross comes in, they roll Talent to arrive late, "
        "bypassing all Physical and Defence checks for a free shot.",
  ),
  // Inspiration: Kevin De Bruyne, Trent Alexander-Arnold, Cesc Fàbregas.
  Talent(
    id: 'the_scalpel',
    name: 'The Scalpel',
    alias: 'Line-Breaking Vision',
    archetype: TalentArchetype.logic,
    description:
        "Instead of making five or six safe passes to build up Chance Quality, "
        "the player rolls Talent to play one impossible, curling 40-yard "
        "ground pass. It bypasses the opponent's entire midfield block and "
        "gives the striker an immediate 1-on-1.",
  ),
  // Inspiration: Toni Kroos, Andrea Pirlo.
  Talent(
    id: 'tempo_dictator',
    name: 'Tempo Dictator',
    alias: 'The Metronome',
    archetype: TalentArchetype.logic,
    description:
        "Triggers when your team is losing momentum or being pressed heavily. "
        "The player rolls Talent to slow the game down, resetting your team's "
        "Tactical Cohesion to 100% and cancelling the opponent's momentum "
        "buffs.",
  ),
  // Inspiration: Sergio Busquets, Rodri, N'Golo Kanté.
  Talent(
    id: 'preventative_vision',
    name: 'Preventative Vision',
    alias: 'The Anchor',
    archetype: TalentArchetype.logic,
    description:
        "A defensive trait. When the opponent triggers a chaotic Innate roll, "
        "like a sudden counter-attack or dribble, the player rolls Talent to "
        "read it and intercept the ball before the move even starts.",
  ),
  // Inspiration: Mesut Özil, Dennis Bergkamp.
  Talent(
    id: 'geometric_architect',
    name: 'Geometric Architect',
    alias: 'Impossible Angles',
    archetype: TalentArchetype.logic,
    description:
        "Creates passing lanes that shouldn't exist. When surrounded by "
        "defenders, a successful Talent roll lets the player's Pass stat "
        "ignore the opponent's blocking stats with backheels, flicks or a "
        "ball bounced off the turf.",
  ),
  // Inspiration: Thomas Müller, Xavi, Kevin De Bruyne · Blue Lock: Isagi
  // Yoichi, Michael Kaiser, Sae Itoshi.
  Talent(
    id: 'meta_vision',
    name: 'Meta-Vision',
    alias: 'Supreme Spatial IQ',
    archetype: TalentArchetype.logic,
    description:
        "The player constantly scans the pitch to foresee the game five "
        "seconds ahead. A massive buff to intercepting loose balls and "
        "finding the highest-quality scoring zone.",
  ),
  // Inspiration: Robert Lewandowski · Blue Lock: Michael Kaiser.
  Talent(
    id: 'the_impact',
    name: 'The Impact',
    alias: 'Zero-Windup Swing',
    archetype: TalentArchetype.logic,
    description:
        "A biomechanically perfect shot with zero wind-up. If the player finds "
        "even a one-second gap in the defence, the shot cannot be blocked by "
        "the Defence stat.",
  ),
  // Inspiration: Filippo Inzaghi · Blue Lock: Isagi Yoichi, Otoya Eita.
  Talent(
    id: 'blind_spot_exploitation',
    name: 'Blind Spot Exploitation',
    archetype: TalentArchetype.logic,
    description:
        "The striker slips into the defender's blind spot and receives passes "
        "completely unmarked. Bypasses the Physical check because there is no "
        "defender to fight for the ball.",
  ),
  // Inspiration: Lionel Messi (playmaking phase) · Blue Lock: Isagi Yoichi.
  Talent(
    id: 'egocentrism',
    name: 'Egocentrism',
    alias: 'Protagonist Manipulation',
    archetype: TalentArchetype.logic,
    description:
        "The player reads the selfish desires of their teammates. Instead of "
        "asking for a pass, they use teammates as bait and move into the "
        "exact space created when a teammate tries to score.",
  ),
  // Inspiration: FC Barcelona (prime Messi & Dani Alves) · Blue Lock: Kurona
  // Ranze with Isagi.
  Talent(
    id: 'planetary_hotline',
    name: 'Planetary Hotline',
    alias: 'High-Speed Tiki-Taka',
    archetype: TalentArchetype.logic,
    description:
        "A synergy trait. When the player links up with a teammate who has "
        "matching tactical IQ, their consecutive one-touch passes multiply "
        "Chance Quality exponentially.",
  ),
  // Inspiration: Luka Modrić · Blue Lock: Hiori Yo, Sae Itoshi.
  Talent(
    id: 'logical_playmaking',
    name: 'Logical Playmaking',
    alias: 'Beautiful Playmaking',
    archetype: TalentArchetype.logic,
    description:
        "Every pass carries perfect tactical information. Receiving a pass "
        "from this player buffs the receiver's Shot and Pace stats because the "
        "ball arrives exactly where they need it to keep top speed.",
  ),
];

List<Talent> talentsOf(TalentArchetype archetype) => [
  for (final t in allTalents)
    if (t.archetype == archetype) t,
];
