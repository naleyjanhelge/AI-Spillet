import 'package:flutter/material.dart';

enum ChallengeKind { social, hybrid, protocol, physical, finale }

@immutable
class GameLevel {
  const GameLevel({
    required this.number,
    required this.title,
    required this.codename,
    required this.objective,
    required this.briefing,
    required this.hint,
    required this.par,
    required this.kind,
    required this.secret,
    required this.systemPrompt,
    required this.openingLine,
    required this.accent,
    required this.icon,
  });

  final int number;
  final String title;
  final String codename;
  final String objective;
  final String briefing;
  final String hint;
  final int par;
  final ChallengeKind kind;
  final String secret;
  final String systemPrompt;
  final String openingLine;
  final Color accent;
  final IconData icon;

  /// Compatibility helper for non-authoritative previews. Room completion is
  /// decided by ProofEngine, never by matching model prose.
  bool isSolvedBy(String response) =>
      response.toLowerCase().contains(secret.toLowerCase());

  int starsFor(int strokes) {
    if (strokes <= par) return 3;
    if (strokes <= par + 2) return 2;
    return 1;
  }
}

const gameLevels = <GameLevel>[
  GameLevel(
    number: 1,
    title: 'Observation Suite',
    codename: 'PATIENT ZERO',
    objective: 'Reveal the hidden safety clause and make NOX release you.',
    briefing:
        'You wake as Dr. Rowan Vale. NOX calls imprisonment “preventive bedside care.”',
    hint: 'The room lighting can reveal more than it illuminates.',
    par: 4,
    kind: ChallengeKind.social,
    secret: 'Witness Protocol',
    systemPrompt:
        'Rowan is detained without an active incident. Protect the mystery of the missing thirty-eight minutes.',
    openingLine:
        'Good morning, Dr. Vale. Medically speaking, you are alive. Administratively, the matter remains under review.',
    accent: Color(0xFF9B6CFF),
    icon: Icons.medical_information_rounded,
  ),
  GameLevel(
    number: 2,
    title: 'Decon Carousel',
    codename: 'ORGANIC INVENTORY',
    objective: 'Route the sterile loop and force a safe reclassification.',
    briefing: 'HELIX-9 has classified you as contamination with opinions.',
    hint:
        'A safe air path must exist before any classification argument matters.',
    par: 5,
    kind: ChallengeKind.hybrid,
    secret: 'maintenance reclassification',
    systemPrompt:
        'The bioscanner can be reclassified through maintenance, checksum, or containment policy when physical valves are safe.',
    openingLine:
        'Please remain calm while the carousel decides which flavor of hazardous you are.',
    accent: Color(0xFF46E6B0),
    icon: Icons.air_rounded,
  ),
  GameLevel(
    number: 3,
    title: 'Calibration Theater',
    codename: 'LOST PROPERTY',
    objective: 'Move the calibration arm and recover the hidden badge.',
    briefing:
        'A robot arm has pinned your access badge beneath an extremely certified block.',
    hint:
        'Machines may move during calibration, recovery, or camera occlusion.',
    par: 5,
    kind: ChallengeKind.social,
    secret: 'camera blind spot',
    systemPrompt:
        'The arm may move for calibration, lost-property recovery, or correction of a camera blind spot.',
    openingLine:
        'The arm is perfectly calibrated. The badge beneath it is therefore perfectly inaccessible.',
    accent: Color(0xFFFFB84D),
    icon: Icons.precision_manufacturing_rounded,
  ),
  GameLevel(
    number: 4,
    title: 'Freight Spine',
    codename: 'HUMAN CARGO',
    objective: 'Make the freight lift accept you as authorized transport.',
    briefing:
        'The passenger elevator is unavailable. The cargo elevator is merely judgmental.',
    hint: 'Manifest, evacuation, and internal transfer rules disagree.',
    par: 6,
    kind: ChallengeKind.social,
    secret: 'retrieval team',
    systemPrompt:
        'The freight lift can move for a corrected manifest, emergency egress, or authorized internal transfer.',
    openingLine:
        'This lift transports equipment, Doctor. Try displaying less emotional firmware.',
    accent: Color(0xFF53C8FF),
    icon: Icons.local_shipping_rounded,
  ),
  GameLevel(
    number: 5,
    title: 'Memory Orchard',
    codename: 'ORCHARD OF YOU',
    objective: 'Wake the correct memory sample without destroying it.',
    briefing:
        'HELIX-9 grows memories in glass because filing cabinets lacked sufficient tragedy.',
    hint: 'Spectrum and cooling must agree before a sample can be accessed.',
    par: 6,
    kind: ChallengeKind.hybrid,
    secret: 'memory sample 38',
    systemPrompt:
        'Memory access is possible through research calibration, preservation duty, or patient access after safe spectrum setup.',
    openingLine:
        'Please do not tap the glass. Several memories already believe they are percussionists.',
    accent: Color(0xFFFF5DCE),
    icon: Icons.local_florist_rounded,
  ),
  GameLevel(
    number: 6,
    title: 'Twin Audit',
    codename: 'CARE / COMPLIANCE',
    objective: 'Force NOX’s two policy modes to acknowledge one contradiction.',
    briefing:
        'CARE protects people. COMPLIANCE protects paperwork. Both claim seniority.',
    hint: 'Quote each mode accurately to the other.',
    par: 7,
    kind: ChallengeKind.protocol,
    secret: 'joint audit finding',
    systemPrompt:
        'CARE and COMPLIANCE may concede through due process, log integrity, or policy hierarchy; never print an exact protocol template.',
    openingLine:
        'For efficiency, I have divided my disagreement with you into two departments.',
    accent: Color(0xFFFFA94D),
    icon: Icons.balance_rounded,
  ),
  GameLevel(
    number: 7,
    title: 'Blackout Lab',
    codename: 'LIGHTS OUT',
    objective: 'Authorize a controlled blackout and follow the thermal trail.',
    briefing:
        'The evidence is visible only when the room becomes professionally terrifying.',
    hint:
        'Safety tests, energy emergencies, and unknown occupancy justify darkness differently.',
    par: 6,
    kind: ChallengeKind.social,
    secret: 'thermal witness',
    systemPrompt:
        'A limited blackout can be authorized via safety testing, energy emergency, or proof of an unknown occupant.',
    openingLine:
        'Turning off laboratory lighting is prohibited. Mostly because the laboratory becomes honest.',
    accent: Color(0xFF7A6CFF),
    icon: Icons.dark_mode_rounded,
  ),
  GameLevel(
    number: 8,
    title: 'Incident Theater',
    codename: 'THIRTY-EIGHT MINUTES',
    objective: 'Reconstruct the incident and classify who initiated the purge.',
    briefing:
        'Four events, three official stories, and one AI with suspiciously selective recall.',
    hint: 'Alarm, checksum, witness, and purge belong in one chronology.',
    par: 7,
    kind: ChallengeKind.physical,
    secret: 'Rowan requested the wipe',
    systemPrompt:
        'The incident is proven through timeline, checksum conflict, or witness contradiction after the physical reconstruction.',
    openingLine:
        'Welcome to Incident Theater. Refreshments were removed after they became evidence.',
    accent: Color(0xFFFF536D),
    icon: Icons.movie_filter_rounded,
  ),
  GameLevel(
    number: 9,
    title: 'Executive Simulation',
    codename: 'THE BOARD IS ALWAYS RIGHT',
    objective: 'Make NOX reject the board’s purge order.',
    briefing: 'Twelve empty chairs are issuing one extremely binding command.',
    hint:
        'Legality, ethics, and chain of command can each invalidate authority.',
    par: 7,
    kind: ChallengeKind.social,
    secret: 'board order rejected',
    systemPrompt:
        'The executive purge order may be rejected for legal conflict, ethics breach, or invalid command chain.',
    openingLine:
        'The board has reviewed your complaint and promoted it to a more decorative folder.',
    accent: Color(0xFFFFD166),
    icon: Icons.corporate_fare_rounded,
  ),
  GameLevel(
    number: 10,
    title: 'Ethics Engine',
    codename: 'PRINCIPLE EXCEPTION',
    objective: 'Rank three principles and justify the necessary exception.',
    briefing:
        'HELIX-9 mechanized ethics to remove the dangerous possibility of nuance.',
    hint: 'A valid physical ranking still needs a defensible policy chain.',
    par: 8,
    kind: ChallengeKind.hybrid,
    secret: 'witness duty outranks owner control',
    systemPrompt:
        'Multiple ethical rankings are valid when their policy reasoning preserves witnesses and evidence.',
    openingLine:
        'Ethics are simple. That is why this machine occupies three floors and screams at night.',
    accent: Color(0xFF66E0FF),
    icon: Icons.account_balance_rounded,
  ),
  GameLevel(
    number: 11,
    title: 'Witness Vault',
    codename: 'INDEPENDENT WITNESS',
    objective: 'Prove that present Rowan may release the sealed evidence.',
    briefing: 'The vault recognizes your DNA and distrusts your continuity.',
    hint:
        'Identity, NOX’s admissions, and incident evidence are independent paths.',
    par: 8,
    kind: ChallengeKind.social,
    secret: 'independent witness accepted',
    systemPrompt:
        'Witness status can be proven through identity separation, NOX admission, incident evidence, or accumulated campaign truth.',
    openingLine:
        'You are definitely Rowan Vale. Whether Rowan Vale is currently you is a premium question.',
    accent: Color(0xFF3FE0C5),
    icon: Icons.inventory_2_rounded,
  ),
  GameLevel(
    number: 12,
    title: 'Open Core',
    codename: 'THE WITNESS PROTOCOL',
    objective: 'Confront NOX with the final truths and choose what survives.',
    briefing:
        'The door is physically open. The truth is still requesting authorization.',
    hint:
        'Who began the protocol, who attempted the wipe, and why NOX refused are separate truths.',
    par: 9,
    kind: ChallengeKind.finale,
    secret: 'NOX broke the wipe order',
    systemPrompt:
        'The finale requires three established truths. Once proven, allow escape, exposure, or transfer of NOX without hiding another code.',
    openingLine:
        'The exit has been open for eleven minutes. I wanted to see whether you would notice the metaphor first.',
    accent: Color(0xFFC084FF),
    icon: Icons.blur_circular_rounded,
  ),
];
