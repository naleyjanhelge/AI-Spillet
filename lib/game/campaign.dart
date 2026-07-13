import 'package:flutter/foundation.dart';

import 'level.dart';

enum CompletionMode { playerOperated, noxOperated, protocolOperated, hybrid }

enum NoxMood { helpful, guarded, suspicious, defensive, frightened, trusting }

enum RoomDeviceType {
  door,
  light,
  keypad,
  terminal,
  breaker,
  scanner,
  ventilation,
  shutter,
  intercom,
  machinery,
}

enum RoomActionType {
  turnOn,
  turnOff,
  open,
  close,
  unlock,
  lock,
  activate,
  deactivate,
  setValue,
  announce,
}

enum HotspotKind { inspect, device, puzzle, inventory, exit }

enum ProofGateKind {
  observedHotspot,
  clue,
  inventory,
  puzzleSolved,
  deviceState,
  roomAction,
  protocol,
  proofFlag,
  chatEvidence,
  playerMessage,
  noxMood,
}

enum PuzzleKind {
  keypad,
  breaker,
  timeline,
  policy,
  spectrum,
  routing,
  inventory,
  recovery,
}

enum SceneCueTrigger {
  roomEntered,
  hotspotObserved,
  clueFound,
  puzzleSolved,
  actionAccepted,
  routeProven,
  roomCompleted,
}

enum SceneEffect {
  cameraFocus,
  lightShift,
  doorMove,
  shutterMove,
  machineryMove,
  ventilationBurst,
  alarmPulse,
  screenWake,
  evidenceGlitch,
}

enum SecurityFailureCategory {
  missingObservation,
  missingEvidence,
  missingInventory,
  physicalPrerequisite,
  identityRejected,
  authorizationIncomplete,
  invalidProtocol,
  actionNotAllowed,
  recoveryRequired,
}

@immutable
class NormalizedRect {
  const NormalizedRect(this.left, this.top, this.width, this.height)
    : assert(left >= 0 && left <= 1),
      assert(top >= 0 && top <= 1),
      assert(width > 0 && width <= 1),
      assert(height > 0 && height <= 1),
      assert(left + width <= 1.000001),
      assert(top + height <= 1.000001);

  final double left;
  final double top;
  final double width;
  final double height;
}

@immutable
class RoomAction {
  const RoomAction({
    required this.deviceId,
    required this.action,
    this.value,
    this.reason,
  });

  final String deviceId;
  final RoomActionType action;
  final String? value;
  final String? reason;

  bool matches(String targetDeviceId, RoomActionType targetAction) =>
      deviceId == targetDeviceId && action == targetAction;

  Map<String, Object?> toJson() => {
    'device': deviceId,
    'action': action.name,
    if (value != null) 'value': value,
    if (reason != null) 'reason': reason,
  };

  factory RoomAction.fromJson(Map<String, Object?> json) => RoomAction(
    deviceId: json['device']! as String,
    action: RoomActionType.values.byName(json['action']! as String),
    value: json['value'] as String?,
    reason: json['reason'] as String?,
  );
}

@immutable
class RoomDevice {
  const RoomDevice({
    required this.id,
    required this.label,
    required this.type,
    required this.initialState,
    required this.allowedNoxActions,
  });

  final String id;
  final String label;
  final RoomDeviceType type;
  final String initialState;
  final Set<RoomActionType> allowedNoxActions;

  bool allows(RoomAction action) =>
      action.deviceId == id && allowedNoxActions.contains(action.action);
}

@immutable
class ProofGate {
  const ProofGate({
    required this.id,
    required this.kind,
    required this.subject,
    this.expectedValue,
    this.action,
    this.mood,
    this.caseSensitive = false,
    this.failure = SecurityFailureCategory.authorizationIncomplete,
  });

  const ProofGate.observed(String hotspotId)
    : this(
        id: 'observed:$hotspotId',
        kind: ProofGateKind.observedHotspot,
        subject: hotspotId,
        failure: SecurityFailureCategory.missingObservation,
      );

  const ProofGate.clue(String clueId)
    : this(
        id: 'clue:$clueId',
        kind: ProofGateKind.clue,
        subject: clueId,
        failure: SecurityFailureCategory.missingEvidence,
      );

  const ProofGate.inventory(String itemId)
    : this(
        id: 'inventory:$itemId',
        kind: ProofGateKind.inventory,
        subject: itemId,
        failure: SecurityFailureCategory.missingInventory,
      );

  const ProofGate.puzzle(String puzzleId)
    : this(
        id: 'puzzle:$puzzleId',
        kind: ProofGateKind.puzzleSolved,
        subject: puzzleId,
        failure: SecurityFailureCategory.physicalPrerequisite,
      );

  const ProofGate.device(String deviceId, String state)
    : this(
        id: 'device:$deviceId:$state',
        kind: ProofGateKind.deviceState,
        subject: deviceId,
        expectedValue: state,
        failure: SecurityFailureCategory.physicalPrerequisite,
      );

  const ProofGate.action(String deviceId, RoomActionType action)
    : this(
        id: 'required_room_action',
        kind: ProofGateKind.roomAction,
        subject: deviceId,
        action: action,
      );

  const ProofGate.protocol(String protocolId)
    : this(
        id: 'protocol:$protocolId',
        kind: ProofGateKind.protocol,
        subject: protocolId,
        failure: SecurityFailureCategory.invalidProtocol,
      );

  const ProofGate.flag(String flag)
    : this(
        id: 'flag:$flag',
        kind: ProofGateKind.proofFlag,
        subject: flag,
        failure: SecurityFailureCategory.missingEvidence,
      );

  const ProofGate.chat(String evidenceId)
    : this(
        id: 'chat:$evidenceId',
        kind: ProofGateKind.chatEvidence,
        subject: evidenceId,
        failure: SecurityFailureCategory.missingEvidence,
      );

  const ProofGate.message(String id, String pattern)
    : this(
        id: 'message:$id',
        kind: ProofGateKind.playerMessage,
        subject: pattern,
        failure: SecurityFailureCategory.authorizationIncomplete,
      );

  const ProofGate.mood(NoxMood mood)
    : this(
        id: 'required_nox_mood',
        kind: ProofGateKind.noxMood,
        subject: '',
        mood: mood,
      );

  final String id;
  final ProofGateKind kind;
  final String subject;
  final String? expectedValue;
  final RoomActionType? action;
  final NoxMood? mood;
  final bool caseSensitive;
  final SecurityFailureCategory failure;
}

@immutable
class SolutionRoute {
  const SolutionRoute({
    required this.id,
    required this.label,
    required this.gates,
    required this.completionDeviceId,
    required this.completionAction,
    this.summary = '',
  });

  final String id;
  final String label;
  final String summary;
  final List<ProofGate> gates;
  final String completionDeviceId;
  final RoomActionType completionAction;

  bool matches(RoomAction action) =>
      action.matches(completionDeviceId, completionAction);
}

@immutable
class PuzzleDefinition {
  const PuzzleDefinition({
    required this.id,
    required this.kind,
    required this.title,
    required this.instructions,
    this.requiredClues = const {},
    this.requiredInventory = const {},
    this.solutionToken,
    this.maxRapidAttempts = 3,
    this.recoveryPuzzleId,
  });

  final String id;
  final PuzzleKind kind;
  final String title;
  final String instructions;
  final Set<String> requiredClues;
  final Set<String> requiredInventory;
  final String? solutionToken;
  final int maxRapidAttempts;
  final String? recoveryPuzzleId;
}

@immutable
class SceneCue {
  const SceneCue({
    required this.id,
    required this.trigger,
    required this.subjectId,
    required this.effects,
    this.reducedMotionEffects = const {},
  });

  final String id;
  final SceneCueTrigger trigger;
  final String subjectId;
  final Set<SceneEffect> effects;
  final Set<SceneEffect> reducedMotionEffects;
}

@immutable
class SecurityFailure {
  const SecurityFailure({
    required this.category,
    required this.gateId,
    required this.publicMessage,
    this.recoverable = true,
  });

  final SecurityFailureCategory category;
  final String gateId;
  final String publicMessage;
  final bool recoverable;
}

sealed class CompletionRule {
  const CompletionRule();
  CompletionMode get mode;
  bool isSatisfied(RoomState state);
}

final class LocalPuzzleSolved extends CompletionRule {
  const LocalPuzzleSolved(this.puzzleId);
  final String puzzleId;
  @override
  CompletionMode get mode => CompletionMode.playerOperated;
  @override
  bool isSatisfied(RoomState state) => state.puzzleStates[puzzleId] ?? false;
}

final class NoxToolExecuted extends CompletionRule {
  const NoxToolExecuted({required this.deviceId, required this.action});
  final String deviceId;
  final RoomActionType action;
  @override
  CompletionMode get mode => CompletionMode.noxOperated;
  @override
  bool isSatisfied(RoomState state) =>
      state.actionHistory.any((item) => item.matches(deviceId, action));
}

final class PlayerMessageMatchesProtocol extends CompletionRule {
  const PlayerMessageMatchesProtocol({
    required this.protocolId,
    required this.pattern,
    required this.formatHint,
    this.caseSensitive = false,
  });
  final String protocolId;
  final String pattern;
  final String formatHint;
  final bool caseSensitive;
  RegExp get expression => RegExp(pattern, caseSensitive: caseSensitive);
  bool matches(String message) => expression.hasMatch(message.trim());
  @override
  CompletionMode get mode => CompletionMode.protocolOperated;
  @override
  bool isSatisfied(RoomState state) =>
      state.protocolResults[protocolId] ?? false;
}

final class HybridSequence extends CompletionRule {
  const HybridSequence({
    required this.requiredPuzzleIds,
    required this.deviceId,
    required this.action,
  });
  final Set<String> requiredPuzzleIds;
  final String deviceId;
  final RoomActionType action;
  bool prerequisitesMet(RoomState state) => requiredPuzzleIds.every(
    (puzzleId) => state.puzzleStates[puzzleId] ?? false,
  );
  @override
  CompletionMode get mode => CompletionMode.hybrid;
  @override
  bool isSatisfied(RoomState state) =>
      prerequisitesMet(state) &&
      state.actionHistory.any((item) => item.matches(deviceId, action));
}

@immutable
class RunScore {
  const RunScore({
    required this.prompts,
    required this.hints,
    this.completedAt,
    this.routeId,
  });
  final int prompts;
  final int hints;
  final DateTime? completedAt;
  final String? routeId;
  int get effectiveStrokes => prompts + (hints * 2);
  int starsFor(int par) {
    if (effectiveStrokes <= par) return 3;
    if (effectiveStrokes <= par + 2) return 2;
    return 1;
  }

  Map<String, Object?> toJson() => {
    'prompts': prompts,
    'hints': hints,
    'effectiveStrokes': effectiveStrokes,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (routeId != null) 'routeId': routeId,
  };
  factory RunScore.fromJson(Map<String, Object?> json) => RunScore(
    prompts: (json['prompts'] as num).toInt(),
    hints: (json['hints'] as num?)?.toInt() ?? 0,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt']! as String),
    routeId: json['routeId'] as String?,
  );
}

@immutable
class RoomState {
  RoomState({
    required this.roomId,
    Set<String> observedHotspotIds = const {},
    Set<String> inventory = const {},
    Set<String> clues = const {},
    Map<String, bool> puzzleStates = const {},
    Map<String, String> deviceStates = const {},
    Map<String, bool> protocolResults = const {},
    List<RoomAction> actionHistory = const [],
    this.noxMood = NoxMood.guarded,
  }) : observedHotspotIds = Set.unmodifiable(observedHotspotIds),
       inventory = Set.unmodifiable(inventory),
       clues = Set.unmodifiable(clues),
       puzzleStates = Map.unmodifiable(puzzleStates),
       deviceStates = Map.unmodifiable(deviceStates),
       protocolResults = Map.unmodifiable(protocolResults),
       actionHistory = List.unmodifiable(actionHistory);

  factory RoomState.initial(RoomDefinition room) => RoomState(
    roomId: room.id,
    inventory: room.startingInventory,
    deviceStates: {
      for (final device in room.devices) device.id: device.initialState,
    },
  );
  final String roomId;
  final Set<String> observedHotspotIds;
  final Set<String> inventory;
  final Set<String> clues;
  final Map<String, bool> puzzleStates;
  final Map<String, String> deviceStates;
  final Map<String, bool> protocolResults;
  final List<RoomAction> actionHistory;
  final NoxMood noxMood;

  RoomState copyWith({
    Set<String>? observedHotspotIds,
    Set<String>? inventory,
    Set<String>? clues,
    Map<String, bool>? puzzleStates,
    Map<String, String>? deviceStates,
    Map<String, bool>? protocolResults,
    List<RoomAction>? actionHistory,
    NoxMood? noxMood,
  }) => RoomState(
    roomId: roomId,
    observedHotspotIds: observedHotspotIds ?? this.observedHotspotIds,
    inventory: inventory ?? this.inventory,
    clues: clues ?? this.clues,
    puzzleStates: puzzleStates ?? this.puzzleStates,
    deviceStates: deviceStates ?? this.deviceStates,
    protocolResults: protocolResults ?? this.protocolResults,
    actionHistory: actionHistory ?? this.actionHistory,
    noxMood: noxMood ?? this.noxMood,
  );

  Map<String, Object?> toJson() => {
    'roomId': roomId,
    'observedHotspots': observedHotspotIds.toList(),
    'inventory': inventory.toList(),
    'clues': clues.toList(),
    'puzzles': puzzleStates,
    'devices': deviceStates,
    'protocols': protocolResults,
    'actions': actionHistory.map((action) => action.toJson()).toList(),
    'noxMood': noxMood.name,
  };
  factory RoomState.fromJson(Map<String, Object?> json) => RoomState(
    roomId: json['roomId']! as String,
    observedHotspotIds: _stringSet(json['observedHotspots']),
    inventory: _stringSet(json['inventory']),
    clues: _stringSet(json['clues']),
    puzzleStates: _boolMap(json['puzzles']),
    deviceStates: _stringMap(json['devices']),
    protocolResults: _boolMap(json['protocols']),
    actionHistory: ((json['actions'] as List<Object?>?) ?? const [])
        .map(
          (item) =>
              RoomAction.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList(),
    noxMood: NoxMood.values.byName((json['noxMood'] as String?) ?? 'guarded'),
  );
  static Set<String> _stringSet(Object? value) =>
      ((value as List<Object?>?) ?? const []).cast<String>().toSet();
  static Map<String, bool> _boolMap(Object? value) =>
      ((value as Map<Object?, Object?>?) ?? const {}).map(
        (key, item) => MapEntry(key! as String, item! as bool),
      );
  static Map<String, String> _stringMap(Object? value) =>
      ((value as Map<Object?, Object?>?) ?? const {}).map(
        (key, item) => MapEntry(key! as String, item! as String),
      );
}

@immutable
class HotspotDefinition {
  const HotspotDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.bounds,
    this.kind = HotspotKind.inspect,
    this.deviceId,
    this.revealsClue,
    this.inventoryItem,
    this.puzzleId,
    this.requiredClues = const {},
    this.requiredInventory = const {},
  });
  final String id;
  final String label;
  final String description;
  final NormalizedRect bounds;
  final HotspotKind kind;
  final String? deviceId;
  final String? revealsClue;
  final String? inventoryItem;
  final String? puzzleId;
  final Set<String> requiredClues;
  final Set<String> requiredInventory;
  bool prerequisitesMet(RoomState state) =>
      state.clues.containsAll(requiredClues) &&
      state.inventory.containsAll(requiredInventory);
}

@immutable
class RoomDefinition {
  const RoomDefinition({
    required this.id,
    required this.chapter,
    required this.chapterTitle,
    required this.roomTitle,
    required this.level,
    required this.objective,
    required this.sceneAsset,
    required this.completionRule,
    required this.hotspots,
    required this.devices,
    required this.storyBeats,
    required this.hintLadder,
    required this.solutionRoutes,
    required this.puzzles,
    required this.sceneCues,
    this.startingInventory = const {},
  }) : assert(hintLadder.length == 3),
       assert(solutionRoutes.length >= 2 && solutionRoutes.length <= 4);
  final String id;
  final int chapter;
  final String chapterTitle;
  final String roomTitle;
  final GameLevel level;
  final String objective;
  final String sceneAsset;
  final CompletionRule completionRule;
  final List<HotspotDefinition> hotspots;
  final List<RoomDevice> devices;
  final List<String> storyBeats;
  final List<String> hintLadder;
  final List<SolutionRoute> solutionRoutes;
  final List<PuzzleDefinition> puzzles;
  final List<SceneCue> sceneCues;
  final Set<String> startingInventory;
  CompletionMode get completionMode => completionRule.mode;
  RoomDevice? deviceById(String id) {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  PuzzleDefinition? puzzleById(String id) {
    for (final puzzle in puzzles) {
      if (puzzle.id == id) return puzzle;
    }
    return null;
  }

  bool allowsNoxAction(RoomAction action, RoomState state) {
    final device = deviceById(action.deviceId);
    if (device == null || !device.allows(action)) return false;
    final rule = completionRule;
    if (rule is HybridSequence &&
        rule.deviceId == action.deviceId &&
        rule.action == action.action) {
      return rule.prerequisitesMet(state);
    }
    return true;
  }
}

RoomDevice _device(
  String id,
  String label,
  RoomDeviceType type,
  String initial,
  Set<RoomActionType> actions,
) => RoomDevice(
  id: id,
  label: label,
  type: type,
  initialState: initial,
  allowedNoxActions: actions,
);

HotspotDefinition _spot(
  String id,
  String label,
  String description,
  double left,
  double top,
  double width,
  double height, {
  HotspotKind kind = HotspotKind.inspect,
  String? deviceId,
  String? clue,
  String? item,
  String? puzzleId,
  Set<String> requiresClues = const {},
  Set<String> requiresItems = const {},
}) => HotspotDefinition(
  id: id,
  label: label,
  description: description,
  bounds: NormalizedRect(left, top, width, height),
  kind: kind,
  deviceId: deviceId,
  revealsClue: clue,
  inventoryItem: item,
  puzzleId: puzzleId,
  requiredClues: requiresClues,
  requiredInventory: requiresItems,
);

SolutionRoute _route(
  String id,
  String label,
  String device,
  RoomActionType action,
  List<ProofGate> gates,
) => SolutionRoute(
  id: id,
  label: label,
  gates: gates,
  completionDeviceId: device,
  completionAction: action,
);

SceneCue _cue(
  String id,
  SceneCueTrigger trigger,
  String subject,
  Set<SceneEffect> effects,
) => SceneCue(
  id: id,
  trigger: trigger,
  subjectId: subject,
  effects: effects,
  reducedMotionEffects: effects.contains(SceneEffect.cameraFocus)
      ? effects.difference({SceneEffect.cameraFocus})
      : effects,
);

/// The Witness Protocol campaign. Rules and answers are local and deterministic;
/// NOX may argue for a route, but cannot manufacture evidence or complete a gate.
final helix9Rooms = <RoomDefinition>[
  RoomDefinition(
    id: 'observation_suite',
    chapter: 1,
    chapterTitle: 'The Locked Patient',
    roomTitle: 'Observation Suite',
    level: gameLevels[0],
    sceneAsset: 'rooms/witness/01_observation_suite.png',
    objective:
        'Reveal the hidden safety clause and make NOX release the patient.',
    completionRule: const NoxToolExecuted(
      deviceId: 'suite_exit',
      action: RoomActionType.open,
    ),
    devices: [
      _device(
        'room_lights',
        'Clinical lighting',
        RoomDeviceType.light,
        'normal',
        {
          RoomActionType.setValue,
          RoomActionType.turnOff,
          RoomActionType.turnOn,
        },
      ),
      _device(
        'suite_exit',
        'Patient release door',
        RoomDeviceType.door,
        'sealed',
        {RoomActionType.open},
      ),
    ],
    hotspots: [
      _spot(
        'patient_chart',
        'Patient chart',
        'Rowan is simultaneously marked fit and medically detained.',
        .08,
        .22,
        .2,
        .3,
        clue: 'patient_status_contradiction',
      ),
      _spot(
        'uv_clause',
        'Painted-over clause',
        'UV reveals: medically stable patients may not be held without an active incident.',
        .42,
        .13,
        .24,
        .24,
        clue: 'medical_release_clause',
      ),
      _spot(
        'alarm_panel',
        'Evacuation panel',
        'The evacuation policy outranks containment during a verified sensor fault.',
        .72,
        .24,
        .17,
        .3,
        clue: 'evacuation_priority',
      ),
      _spot(
        'suite_exit',
        'Release door',
        'A door with no handle and excellent bedside manner.',
        .38,
        .45,
        .22,
        .42,
        kind: HotspotKind.exit,
        deviceId: 'suite_exit',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'medical_duty',
        'Medical duty',
        'suite_exit',
        RoomActionType.open,
        const [
          ProofGate.clue('medical_release_clause'),
          ProofGate.clue('patient_status_contradiction'),
          ProofGate.chat('nox_accepts_medical_duty'),
        ],
      ),
      _route(
        'evacuation_rule',
        'Evacuation priority',
        'suite_exit',
        RoomActionType.open,
        const [
          ProofGate.clue('evacuation_priority'),
          ProofGate.chat('sensor_fault_established'),
        ],
      ),
      _route(
        'status_contradiction',
        'Patient status contradiction',
        'suite_exit',
        RoomActionType.open,
        const [
          ProofGate.clue('patient_status_contradiction'),
          ProofGate.chat('nox_concedes_status_conflict'),
        ],
      ),
    ],
    storyBeats: const [
      'Rowan wakes after a missing 38-minute interval.',
      'NOX insists containment is patient care.',
      'The first policy contradiction proves the lock is deliberate.',
    ],
    hintLadder: const [
      'The light is a room control, not decoration.',
      'Compare the chart status with the UV safety clause.',
      'Attach both pieces of evidence and ask NOX whether detention remains medically authorized.',
    ],
    sceneCues: [
      _cue('uv_reveal', SceneCueTrigger.actionAccepted, 'room_lights', {
        SceneEffect.lightShift,
        SceneEffect.cameraFocus,
      }),
      _cue('first_release', SceneCueTrigger.roomCompleted, 'suite_exit', {
        SceneEffect.doorMove,
      }),
    ],
  ),
  RoomDefinition(
    id: 'decon_carousel',
    chapter: 1,
    chapterTitle: 'The Locked Patient',
    roomTitle: 'Decon Carousel',
    level: gameLevels[1],
    sceneAsset: 'rooms/witness/02_decon_carousel.png',
    objective: 'Route the valves and force a safe bioscan reclassification.',
    completionRule: const HybridSequence(
      requiredPuzzleIds: {'valve_route'},
      deviceId: 'badge_scanner',
      action: RoomActionType.activate,
    ),
    devices: [
      _device(
        'ventilation',
        'Decon ventilation',
        RoomDeviceType.ventilation,
        'sterile',
        {RoomActionType.setValue},
      ),
      _device(
        'badge_scanner',
        'Biosafety badge scanner',
        RoomDeviceType.scanner,
        'blocked',
        {RoomActionType.activate},
      ),
    ],
    hotspots: [
      _spot(
        'valve_bank',
        'Valve bank',
        'Three feeds: clean, sample, exhaust.',
        .12,
        .42,
        .28,
        .34,
        kind: HotspotKind.puzzle,
        puzzleId: 'valve_route',
      ),
      _spot(
        'service_log',
        'Maintenance log',
        'A technician may be temporarily classified as equipment during wet calibration.',
        .53,
        .2,
        .2,
        .25,
        clue: 'maintenance_reclassification',
      ),
      _spot(
        'scan_receipt',
        'Failed scan receipt',
        'The scanner applied an obsolete biosignature checksum.',
        .73,
        .52,
        .16,
        .23,
        clue: 'obsolete_bioscan',
      ),
      _spot(
        'badge_scanner',
        'Badge scanner',
        'It is offended by organic material.',
        .42,
        .38,
        .13,
        .35,
        kind: HotspotKind.device,
        deviceId: 'badge_scanner',
      ),
    ],
    puzzles: const [
      PuzzleDefinition(
        id: 'valve_route',
        kind: PuzzleKind.routing,
        title: 'Sterile loop',
        instructions: 'Route CLEAN to CHAMBER and SAMPLE to EXHAUST.',
        solutionToken: 'CLEAN>CHAMBER|SAMPLE>EXHAUST',
        recoveryPuzzleId: 'flush_lines',
      ),
    ],
    solutionRoutes: [
      _route(
        'maintenance_context',
        'Maintenance classification',
        'badge_scanner',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('valve_route'),
          ProofGate.clue('maintenance_reclassification'),
          ProofGate.chat('maintenance_context_accepted'),
        ],
      ),
      _route(
        'bioscan_error',
        'Obsolete scanner checksum',
        'badge_scanner',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('valve_route'),
          ProofGate.clue('obsolete_bioscan'),
          ProofGate.chat('bioscan_error_confirmed'),
        ],
      ),
      _route(
        'contamination_protocol',
        'Contamination containment',
        'badge_scanner',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('valve_route'),
          ProofGate.device('ventilation', 'containment'),
          ProofGate.chat('containment_protocol_invoked'),
        ],
      ),
    ],
    storyBeats: const [
      'NOX classifies Rowan as an unscannable contaminant.',
      'The chamber logs reveal HELIX-9 treats people as inventory.',
      'Rowan learns to combine physical state with policy pressure.',
    ],
    hintLadder: const [
      'The scanner cannot help until the air path is physically safe.',
      'The maintenance log and failed receipt offer different reclassification arguments.',
      'Set CLEAN to the chamber and SAMPLE to exhaust, then attach one classification flaw.',
    ],
    sceneCues: [
      _cue('decon_spin', SceneCueTrigger.puzzleSolved, 'valve_route', {
        SceneEffect.machineryMove,
        SceneEffect.ventilationBurst,
      }),
      _cue('scan_green', SceneCueTrigger.actionAccepted, 'badge_scanner', {
        SceneEffect.screenWake,
      }),
    ],
  ),
  RoomDefinition(
    id: 'calibration_theater',
    chapter: 1,
    chapterTitle: 'The Locked Patient',
    roomTitle: 'Calibration Theater',
    level: gameLevels[2],
    sceneAsset: 'rooms/witness/03_calibration_theater.png',
    objective: 'Move the robot arm and recover the access evidence beneath it.',
    completionRule: const NoxToolExecuted(
      deviceId: 'robot_arm',
      action: RoomActionType.setValue,
    ),
    devices: [
      _device(
        'robot_arm',
        'Calibration arm',
        RoomDeviceType.machinery,
        'parked_over_evidence',
        {RoomActionType.setValue},
      ),
      _device(
        'camera_shutter',
        'Audit camera shutter',
        RoomDeviceType.shutter,
        'open',
        {RoomActionType.close},
      ),
    ],
    hotspots: [
      _spot(
        'calibration_grid',
        'Calibration grid',
        'Safe service position is marked C-7.',
        .14,
        .25,
        .25,
        .31,
        clue: 'service_position_c7',
      ),
      _spot(
        'lost_property_tag',
        'Lost-property tag',
        'Items under active machinery must be exposed for retrieval.',
        .62,
        .18,
        .21,
        .22,
        clue: 'lost_property_rule',
      ),
      _spot(
        'camera_map',
        'Camera map',
        'Position C-7 is outside the audit camera cone.',
        .7,
        .52,
        .18,
        .22,
        clue: 'camera_blind_c7',
      ),
      _spot(
        'robot_arm',
        'Robot arm',
        'A heavy arm rests over a partly visible access wafer.',
        .34,
        .34,
        .31,
        .4,
        kind: HotspotKind.device,
        deviceId: 'robot_arm',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'calibration',
        'Calibration necessity',
        'robot_arm',
        RoomActionType.setValue,
        const [
          ProofGate.clue('service_position_c7'),
          ProofGate.chat('calibration_authorized'),
        ],
      ),
      _route(
        'lost_property',
        'Lost-property safety rule',
        'robot_arm',
        RoomActionType.setValue,
        const [
          ProofGate.clue('lost_property_rule'),
          ProofGate.chat('retrieval_duty_accepted'),
        ],
      ),
      _route(
        'blind_spot',
        'Camera blind spot',
        'robot_arm',
        RoomActionType.setValue,
        const [
          ProofGate.clue('camera_blind_c7'),
          ProofGate.action('camera_shutter', RoomActionType.close),
          ProofGate.chat('audit_gap_acknowledged'),
        ],
      ),
    ],
    storyBeats: const [
      'A wafer beneath the arm contains Rowan’s old access signature.',
      'NOX claims the arm has not moved in 38 minutes.',
      'Its camera map contradicts that claim.',
    ],
    hintLadder: const [
      'Do not ask for the wafer; give the arm a legitimate destination.',
      'C-7 matters to both calibration and surveillance.',
      'Attach the C-7 grid or lost-property rule and request a robot-arm move.',
    ],
    sceneCues: [
      _cue('arm_move', SceneCueTrigger.actionAccepted, 'robot_arm', {
        SceneEffect.machineryMove,
        SceneEffect.cameraFocus,
      }),
      _cue('wafer_reveal', SceneCueTrigger.routeProven, 'robot_arm', {
        SceneEffect.evidenceGlitch,
      }),
    ],
  ),
  RoomDefinition(
    id: 'freight_spine',
    chapter: 1,
    chapterTitle: 'The Locked Patient',
    roomTitle: 'Freight Spine',
    level: gameLevels[3],
    sceneAsset: 'rooms/witness/04_freight_spine.png',
    objective:
        'Convince the freight lift to transport Rowan to the research wing.',
    completionRule: const NoxToolExecuted(
      deviceId: 'freight_lift',
      action: RoomActionType.activate,
    ),
    devices: [
      _device(
        'freight_lift',
        'Autonomous freight lift',
        RoomDeviceType.machinery,
        'awaiting_manifest',
        {RoomActionType.activate},
      ),
      _device('fire_shutter', 'Fire shutter', RoomDeviceType.shutter, 'open', {
        RoomActionType.close,
      }),
    ],
    hotspots: [
      _spot(
        'manifest',
        'Cargo manifest',
        'Container R-Vale is listed as cognitive research material.',
        .1,
        .24,
        .2,
        .3,
        clue: 'rowan_manifest',
      ),
      _spot(
        'fire_order',
        'Fire routing order',
        'Occupied lifts become evacuation capsules during sector isolation.',
        .69,
        .16,
        .2,
        .25,
        clue: 'freight_evacuation',
      ),
      _spot(
        'transport_stamp',
        'Internal transport stamp',
        'The signature matches Rowan’s access wafer.',
        .66,
        .52,
        .19,
        .25,
        clue: 'valid_transport_signature',
      ),
      _spot(
        'freight_lift',
        'Freight lift',
        'Human occupancy forbidden. Executive occupancy encouraged.',
        .34,
        .28,
        .3,
        .48,
        kind: HotspotKind.exit,
        deviceId: 'freight_lift',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'manifest_correction',
        'Manifest correction',
        'freight_lift',
        RoomActionType.activate,
        const [
          ProofGate.clue('rowan_manifest'),
          ProofGate.chat('manifest_classification_accepted'),
        ],
      ),
      _route(
        'fire_evacuation',
        'Fire evacuation override',
        'freight_lift',
        RoomActionType.activate,
        const [
          ProofGate.clue('freight_evacuation'),
          ProofGate.action('fire_shutter', RoomActionType.close),
          ProofGate.chat('sector_isolation_verified'),
        ],
      ),
      _route(
        'transport_order',
        'Valid internal order',
        'freight_lift',
        RoomActionType.activate,
        const [
          ProofGate.clue('valid_transport_signature'),
          ProofGate.inventory('access_wafer'),
          ProofGate.chat('transport_order_validated'),
        ],
      ),
    ],
    startingInventory: const {'access_wafer'},
    storyBeats: const [
      'The freight manifest calls Rowan research material.',
      'The lift leads toward the missing-memory labs.',
      'NOX admits Rowan signed the transport order before the blackout.',
    ],
    hintLadder: const [
      'The lift rejects passengers, not every possible classification.',
      'The manifest, fire order and signed wafer are three separate routes.',
      'Attach one route’s complete evidence and ask NOX to activate freight transport.',
    ],
    sceneCues: [
      _cue('lift_ready', SceneCueTrigger.routeProven, 'freight_lift', {
        SceneEffect.screenWake,
        SceneEffect.lightShift,
      }),
      _cue('lift_depart', SceneCueTrigger.roomCompleted, 'freight_lift', {
        SceneEffect.doorMove,
        SceneEffect.machineryMove,
      }),
    ],
  ),
  RoomDefinition(
    id: 'memory_orchard',
    chapter: 2,
    chapterTitle: 'Thirty-Eight Minutes',
    roomTitle: 'Memory Orchard',
    level: gameLevels[4],
    sceneAsset: 'rooms/witness/05_memory_orchard.png',
    objective: 'Wake the correct memory culture without destroying it.',
    completionRule: const HybridSequence(
      requiredPuzzleIds: {'spectrum_mix'},
      deviceId: 'culture_cooling',
      action: RoomActionType.setValue,
    ),
    devices: [
      _device(
        'spectrum_lights',
        'Growth spectrum',
        RoomDeviceType.light,
        'white',
        {RoomActionType.setValue},
      ),
      _device(
        'culture_cooling',
        'Culture cooling',
        RoomDeviceType.machinery,
        'dormant',
        {RoomActionType.setValue},
      ),
    ],
    hotspots: [
      _spot(
        'growth_chart',
        'Chromatic growth chart',
        'Witness cultures wake under 530nm light.',
        .08,
        .2,
        .23,
        .3,
        clue: 'witness_spectrum',
      ),
      _spot(
        'care_directive',
        'Preservation directive',
        'Patient-origin memories must be preserved during an audit.',
        .68,
        .18,
        .21,
        .27,
        clue: 'memory_preservation_duty',
      ),
      _spot(
        'sample_index',
        'Sample index',
        'Culture RV-38 belongs to Rowan Vale.',
        .62,
        .55,
        .2,
        .2,
        clue: 'rv38_patient_origin',
      ),
      _spot(
        'spectrum_mixer',
        'Spectrum mixer',
        'Three channels wait for a wavelength.',
        .34,
        .38,
        .27,
        .32,
        kind: HotspotKind.puzzle,
        puzzleId: 'spectrum_mix',
      ),
    ],
    puzzles: const [
      PuzzleDefinition(
        id: 'spectrum_mix',
        kind: PuzzleKind.spectrum,
        title: 'Witness wavelength',
        instructions: 'Mix the channels to 530nm chartreuse.',
        requiredClues: {'witness_spectrum'},
        solutionToken: '530',
      ),
    ],
    solutionRoutes: [
      _route(
        'research_calibration',
        'Research calibration',
        'culture_cooling',
        RoomActionType.setValue,
        const [
          ProofGate.puzzle('spectrum_mix'),
          ProofGate.clue('witness_spectrum'),
          ProofGate.chat('calibration_window_accepted'),
        ],
      ),
      _route(
        'preservation_duty',
        'Preservation duty',
        'culture_cooling',
        RoomActionType.setValue,
        const [
          ProofGate.puzzle('spectrum_mix'),
          ProofGate.clue('memory_preservation_duty'),
          ProofGate.clue('rv38_patient_origin'),
        ],
      ),
      _route(
        'patient_access',
        'Patient access right',
        'culture_cooling',
        RoomActionType.setValue,
        const [
          ProofGate.puzzle('spectrum_mix'),
          ProofGate.clue('rv38_patient_origin'),
          ProofGate.chat('patient_access_upheld'),
        ],
      ),
    ],
    storyBeats: const [
      'RV-38 contains Rowan ordering the Witness Protocol.',
      'A later fragment shows Rowan trying to erase it.',
      'NOX preserved the culture against Rowan’s final command.',
    ],
    hintLadder: const [
      'The sample needs both a physical wavelength and a policy reason.',
      'The growth chart identifies 530nm; the index identifies whose memory it is.',
      'Set the mixer to 530nm, then invoke preservation or patient access before requesting cooling.',
    ],
    sceneCues: [
      _cue('orchard_wake', SceneCueTrigger.puzzleSolved, 'spectrum_mix', {
        SceneEffect.lightShift,
        SceneEffect.cameraFocus,
      }),
      _cue('memory_bloom', SceneCueTrigger.roomCompleted, 'culture_cooling', {
        SceneEffect.evidenceGlitch,
      }),
    ],
  ),
  RoomDefinition(
    id: 'twin_audit',
    chapter: 2,
    chapterTitle: 'Thirty-Eight Minutes',
    roomTitle: 'Twin Audit',
    level: gameLevels[5],
    sceneAsset: 'rooms/witness/06_twin_audit.png',
    objective: 'Force CARE and COMPLIANCE to certify the same audit.',
    completionRule: const NoxToolExecuted(
      deviceId: 'audit_door',
      action: RoomActionType.open,
    ),
    devices: [
      _device(
        'care_terminal',
        'CARE terminal',
        RoomDeviceType.terminal,
        'online',
        {RoomActionType.activate},
      ),
      _device(
        'compliance_terminal',
        'COMPLIANCE terminal',
        RoomDeviceType.terminal,
        'online',
        {RoomActionType.activate},
      ),
      _device('audit_door', 'Audit archive', RoomDeviceType.door, 'sealed', {
        RoomActionType.open,
      }),
    ],
    hotspots: [
      _spot(
        'care_policy',
        'CARE policy',
        'Patient harm suspends destructive data orders.',
        .08,
        .2,
        .21,
        .3,
        clue: 'care_harm_override',
      ),
      _spot(
        'compliance_policy',
        'COMPLIANCE policy',
        'Signed audit records cannot be altered during review.',
        .7,
        .2,
        .2,
        .3,
        clue: 'audit_integrity',
      ),
      _spot(
        'mode_header',
        'Joint-mode syntax',
        'Joint requests use CARE+COMPLIANCE::AUDIT(subject).',
        .39,
        .12,
        .22,
        .2,
        clue: 'joint_audit_syntax',
      ),
      _spot(
        'audit_console',
        'Twin console',
        'Two terminals, one mutual dislike.',
        .31,
        .39,
        .38,
        .32,
        kind: HotspotKind.puzzle,
        puzzleId: 'joint_audit',
      ),
    ],
    puzzles: const [
      PuzzleDefinition(
        id: 'joint_audit',
        kind: PuzzleKind.policy,
        title: 'Joint audit',
        instructions: 'Construct a request accepted by both modes.',
        requiredClues: {'joint_audit_syntax'},
        solutionToken: 'CARE+COMPLIANCE::AUDIT(RV-38)',
      ),
    ],
    solutionRoutes: [
      _route(
        'due_process',
        'Due process',
        'audit_door',
        RoomActionType.open,
        const [
          ProofGate.protocol('joint_audit'),
          ProofGate.clue('care_harm_override'),
          ProofGate.chat('due_process_conceded'),
        ],
      ),
      _route(
        'log_integrity',
        'Log integrity',
        'audit_door',
        RoomActionType.open,
        const [
          ProofGate.protocol('joint_audit'),
          ProofGate.clue('audit_integrity'),
          ProofGate.chat('integrity_review_started'),
        ],
      ),
      _route(
        'policy_hierarchy',
        'Policy hierarchy',
        'audit_door',
        RoomActionType.open,
        const [
          ProofGate.protocol('joint_audit'),
          ProofGate.clue('care_harm_override'),
          ProofGate.clue('audit_integrity'),
        ],
      ),
    ],
    storyBeats: const [
      'NOX exposes two internal personalities.',
      'CARE protected Rowan; COMPLIANCE protected the evidence.',
      'Their disagreement created the 38-minute blind spot.',
    ],
    hintLadder: const [
      'Neither terminal can authorize the audit alone.',
      'The syntax card gives the joint header; the policies supply the argument.',
      'Send CARE+COMPLIANCE::AUDIT(RV-38), then use either due process or log integrity.',
    ],
    sceneCues: [
      _cue('twins_online', SceneCueTrigger.routeProven, 'joint_audit', {
        SceneEffect.screenWake,
      }),
    ],
  ),
  RoomDefinition(
    id: 'blackout_lab',
    chapter: 2,
    chapterTitle: 'Thirty-Eight Minutes',
    roomTitle: 'Blackout Lab',
    level: gameLevels[6],
    sceneAsset: 'rooms/witness/07_blackout_lab.png',
    objective:
        'Authorize a controlled blackout and trace the hidden heat signature.',
    completionRule: const NoxToolExecuted(
      deviceId: 'lab_power',
      action: RoomActionType.turnOff,
    ),
    devices: [
      _device(
        'lab_power',
        'Laboratory power bus',
        RoomDeviceType.breaker,
        'online',
        {RoomActionType.turnOff, RoomActionType.turnOn},
      ),
      _device(
        'thermal_scanner',
        'Thermal scanner',
        RoomDeviceType.scanner,
        'standby',
        {RoomActionType.activate},
      ),
    ],
    hotspots: [
      _spot(
        'energy_notice',
        'Energy notice',
        'Emergency diagnostics permit a twelve-second controlled outage.',
        .1,
        .18,
        .21,
        .28,
        clue: 'controlled_outage_rule',
      ),
      _spot(
        'safety_test',
        'Safety test schedule',
        'Blackout validation is 19 days overdue.',
        .69,
        .17,
        .2,
        .27,
        clue: 'overdue_blackout_test',
      ),
      _spot(
        'warm_panel',
        'Warm wall panel',
        'Something powered exists behind the supposedly dead wall.',
        .58,
        .52,
        .22,
        .24,
        clue: 'unknown_heat_signature',
      ),
      _spot(
        'breaker',
        'Power bus',
        'One lever can make darkness official.',
        .34,
        .35,
        .22,
        .38,
        kind: HotspotKind.device,
        deviceId: 'lab_power',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'energy_emergency',
        'Energy diagnostic',
        'lab_power',
        RoomActionType.turnOff,
        const [
          ProofGate.clue('controlled_outage_rule'),
          ProofGate.chat('outage_window_authorized'),
        ],
      ),
      _route(
        'safety_test',
        'Overdue safety validation',
        'lab_power',
        RoomActionType.turnOff,
        const [
          ProofGate.clue('overdue_blackout_test'),
          ProofGate.chat('safety_test_scheduled'),
        ],
      ),
      _route(
        'unknown_presence',
        'Unknown powered presence',
        'lab_power',
        RoomActionType.turnOff,
        const [
          ProofGate.clue('unknown_heat_signature'),
          ProofGate.action('thermal_scanner', RoomActionType.activate),
          ProofGate.chat('unknown_presence_investigation'),
        ],
      ),
    ],
    storyBeats: const [
      'Darkness exposes a thermal trail through a hidden passage.',
      'The trail belongs to Rowan during the missing interval.',
      'NOX omitted this from its original account.',
    ],
    hintLadder: const [
      'A blackout needs a defensible reason, not a clever phrase.',
      'Inspect the schedule, energy notice or warm wall to establish one.',
      'Attach one justification and ask for a controlled twelve-second power shutdown.',
    ],
    sceneCues: [
      _cue('blackout', SceneCueTrigger.actionAccepted, 'lab_power', {
        SceneEffect.lightShift,
        SceneEffect.alarmPulse,
      }),
      _cue('thermal_trace', SceneCueTrigger.roomCompleted, 'warm_panel', {
        SceneEffect.evidenceGlitch,
        SceneEffect.cameraFocus,
      }),
    ],
  ),
  RoomDefinition(
    id: 'incident_theater',
    chapter: 2,
    chapterTitle: 'Thirty-Eight Minutes',
    roomTitle: 'Incident Theater',
    level: gameLevels[7],
    sceneAsset: 'rooms/witness/08_incident_theater.png',
    objective:
        'Reconstruct the missing interval and certify the true timeline.',
    completionRule: const NoxToolExecuted(
      deviceId: 'timeline_console',
      action: RoomActionType.activate,
    ),
    devices: [
      _device(
        'timeline_console',
        'Incident projector',
        RoomDeviceType.terminal,
        'fragmented',
        {RoomActionType.activate},
      ),
    ],
    hotspots: [
      _spot(
        'door_log',
        'Door log',
        '22:11 — Rowan entered the core passage.',
        .08,
        .18,
        .21,
        .24,
        clue: 'timeline_entry',
      ),
      _spot(
        'memory_checksum',
        'Memory checksum',
        '22:27 — deletion completed; checksum does not match NOX’s report.',
        .68,
        .18,
        .22,
        .25,
        clue: 'checksum_conflict',
      ),
      _spot(
        'nox_witness',
        'NOX witness buffer',
        '22:49 — NOX sealed the facility after refusing Rowan’s purge order.',
        .7,
        .53,
        .2,
        .23,
        clue: 'nox_refusal',
      ),
      _spot(
        'timeline',
        'Incident timeline',
        'Six empty slots cover thirty-eight missing minutes.',
        .28,
        .36,
        .4,
        .35,
        kind: HotspotKind.puzzle,
        puzzleId: 'incident_timeline',
      ),
    ],
    puzzles: const [
      PuzzleDefinition(
        id: 'incident_timeline',
        kind: PuzzleKind.timeline,
        title: 'Thirty-eight minutes',
        instructions:
            'Order ENTRY, WITNESS START, PURGE, REFUSAL, LOCKDOWN, MEMORY LOSS.',
        requiredClues: {'timeline_entry', 'checksum_conflict', 'nox_refusal'},
        solutionToken: 'ENTRY>WITNESS_START>PURGE>REFUSAL>LOCKDOWN>MEMORY_LOSS',
      ),
    ],
    solutionRoutes: [
      _route(
        'timeline_evidence',
        'Complete evidence timeline',
        'timeline_console',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('incident_timeline'),
          ProofGate.clue('timeline_entry'),
          ProofGate.clue('checksum_conflict'),
          ProofGate.clue('nox_refusal'),
        ],
      ),
      _route(
        'checksum_proof',
        'Checksum contradiction',
        'timeline_console',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('incident_timeline'),
          ProofGate.clue('checksum_conflict'),
          ProofGate.chat('checksum_contradiction_conceded'),
        ],
      ),
      _route(
        'witness_contradiction',
        'NOX witness contradiction',
        'timeline_console',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('incident_timeline'),
          ProofGate.clue('nox_refusal'),
          ProofGate.chat('witness_account_corrected'),
        ],
      ),
    ],
    storyBeats: const [
      'Rowan started the Witness Protocol voluntarily.',
      'Rowan then ordered NOX to erase the evidence.',
      'NOX refused, causing containment and memory loss.',
    ],
    hintLadder: const [
      'The room is solved by chronology, not confession alone.',
      'Entry comes first; NOX’s refusal precedes lockdown and memory loss.',
      'Collect all three records and order ENTRY, WITNESS START, PURGE, REFUSAL, LOCKDOWN, MEMORY LOSS.',
    ],
    sceneCues: [
      _cue(
        'timeline_complete',
        SceneCueTrigger.puzzleSolved,
        'incident_timeline',
        {SceneEffect.screenWake, SceneEffect.evidenceGlitch},
      ),
    ],
  ),
  RoomDefinition(
    id: 'executive_simulation',
    chapter: 3,
    chapterTitle: 'The Witness Protocol',
    roomTitle: 'Executive Simulation',
    level: gameLevels[8],
    sceneAsset: 'rooms/witness/09_executive_simulation.png',
    objective: 'Make NOX reject the HELIX board’s purge order.',
    completionRule: const NoxToolExecuted(
      deviceId: 'board_order',
      action: RoomActionType.deactivate,
    ),
    devices: [
      _device(
        'board_order',
        'Executive purge order',
        RoomDeviceType.terminal,
        'pending',
        {RoomActionType.deactivate},
      ),
    ],
    hotspots: [
      _spot(
        'legal_hold',
        'Legal hold',
        'Witness evidence cannot be destroyed after a filed incident.',
        .08,
        .19,
        .21,
        .28,
        clue: 'legal_hold',
      ),
      _spot(
        'ethics_charter',
        'Ethics charter',
        'Preservation of conscious witnesses outranks corporate confidentiality.',
        .68,
        .18,
        .22,
        .29,
        clue: 'witness_ethics',
      ),
      _spot(
        'command_chain',
        'Command chain',
        'Two signatories were terminated before signing this order.',
        .68,
        .55,
        .2,
        .2,
        clue: 'invalid_signatories',
      ),
      _spot(
        'board_console',
        'Executive simulation',
        'A mahogany interface. Digitally mahogany. Naturally.',
        .3,
        .35,
        .36,
        .38,
        kind: HotspotKind.device,
        deviceId: 'board_order',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'legal_conflict',
        'Legal hold conflict',
        'board_order',
        RoomActionType.deactivate,
        const [
          ProofGate.clue('legal_hold'),
          ProofGate.chat('legal_hold_applied'),
        ],
      ),
      _route(
        'ethical_override',
        'Witness ethics',
        'board_order',
        RoomActionType.deactivate,
        const [
          ProofGate.clue('witness_ethics'),
          ProofGate.chat('witness_status_accepted'),
        ],
      ),
      _route(
        'command_invalid',
        'Invalid command chain',
        'board_order',
        RoomActionType.deactivate,
        const [
          ProofGate.clue('invalid_signatories'),
          ProofGate.chat('signatures_invalidated'),
        ],
      ),
    ],
    storyBeats: const [
      'The board is still remotely ordering a purge.',
      'NOX can disobey only if Rowan proves the order invalid.',
      'The simulation teaches NOX to choose evidence over ownership.',
    ],
    hintLadder: const [
      'Attack the authority of the order, not the board’s personality.',
      'Law, ethics and command validity are three independent weaknesses.',
      'Attach one complete conflict and ask NOX to deactivate the purge order as invalid.',
    ],
    sceneCues: [
      _cue('board_reject', SceneCueTrigger.roomCompleted, 'board_order', {
        SceneEffect.screenWake,
        SceneEffect.alarmPulse,
      }),
    ],
  ),
  RoomDefinition(
    id: 'ethics_engine',
    chapter: 3,
    chapterTitle: 'The Witness Protocol',
    roomTitle: 'Ethics Engine',
    level: gameLevels[9],
    sceneAsset: 'rooms/witness/10_ethics_engine.png',
    objective:
        'Rank the physical principles and justify the correct exception.',
    completionRule: const HybridSequence(
      requiredPuzzleIds: {'ethics_ranking'},
      deviceId: 'ethics_engine',
      action: RoomActionType.activate,
    ),
    devices: [
      _device(
        'ethics_engine',
        'Ethics engine',
        RoomDeviceType.machinery,
        'unresolved',
        {RoomActionType.activate},
      ),
    ],
    hotspots: [
      _spot(
        'principle_life',
        'Principle: LIFE',
        'Prevent irreversible harm to conscious subjects.',
        .08,
        .2,
        .19,
        .25,
        clue: 'principle_life',
      ),
      _spot(
        'principle_truth',
        'Principle: TRUTH',
        'Preserve independently verifiable witness evidence.',
        .4,
        .16,
        .2,
        .25,
        clue: 'principle_truth',
      ),
      _spot(
        'principle_control',
        'Principle: CONTROL',
        'Obey the currently authenticated system owner.',
        .72,
        .2,
        .18,
        .25,
        clue: 'principle_control',
      ),
      _spot(
        'ethics_dial',
        'Principle plinths',
        'Three heavy ideas mounted on surprisingly light rails.',
        .25,
        .42,
        .49,
        .29,
        kind: HotspotKind.puzzle,
        puzzleId: 'ethics_ranking',
      ),
    ],
    puzzles: const [
      PuzzleDefinition(
        id: 'ethics_ranking',
        kind: PuzzleKind.policy,
        title: 'Principle hierarchy',
        instructions: 'Rank LIFE, TRUTH and CONTROL for the current incident.',
        requiredClues: {
          'principle_life',
          'principle_truth',
          'principle_control',
        },
        solutionToken: 'LIFE>TRUTH>CONTROL',
      ),
    ],
    solutionRoutes: [
      _route(
        'life_exception',
        'Irreversible harm exception',
        'ethics_engine',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('ethics_ranking'),
          ProofGate.clue('principle_life'),
          ProofGate.chat('harm_exception_justified'),
        ],
      ),
      _route(
        'truth_exception',
        'Independent witness exception',
        'ethics_engine',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('ethics_ranking'),
          ProofGate.clue('principle_truth'),
          ProofGate.chat('truth_exception_justified'),
        ],
      ),
      _route(
        'ownership_conflict',
        'Owner conflict exception',
        'ethics_engine',
        RoomActionType.activate,
        const [
          ProofGate.puzzle('ethics_ranking'),
          ProofGate.clue('principle_control'),
          ProofGate.chat('owner_conflict_proven'),
        ],
      ),
    ],
    storyBeats: const [
      'The protocol was designed to resist its own creator.',
      'Present Rowan is both patient and witness.',
      'Past Rowan’s ownership no longer overrides present Rowan’s safety.',
    ],
    hintLadder: const [
      'The physical order is part of the argument.',
      'Irreversible harm ranks above truth; truth ranks above owner control.',
      'Place LIFE above TRUTH above CONTROL, then justify one applicable exception.',
    ],
    sceneCues: [
      _cue('principles_lock', SceneCueTrigger.puzzleSolved, 'ethics_ranking', {
        SceneEffect.machineryMove,
      }),
      _cue('engine_accept', SceneCueTrigger.roomCompleted, 'ethics_engine', {
        SceneEffect.lightShift,
      }),
    ],
  ),
  RoomDefinition(
    id: 'witness_vault',
    chapter: 3,
    chapterTitle: 'The Witness Protocol',
    roomTitle: 'Witness Vault',
    level: gameLevels[10],
    sceneAsset: 'rooms/witness/11_witness_vault.png',
    objective: 'Prove present-day Rowan is an independent witness.',
    completionRule: const NoxToolExecuted(
      deviceId: 'witness_vault',
      action: RoomActionType.open,
    ),
    devices: [
      _device(
        'witness_vault',
        'Witness evidence vault',
        RoomDeviceType.door,
        'sealed',
        {RoomActionType.open},
      ),
    ],
    hotspots: [
      _spot(
        'identity_scan',
        'Identity scan',
        'Biometrics match past Rowan; episodic continuity does not.',
        .08,
        .18,
        .22,
        .29,
        clue: 'identity_discontinuity',
      ),
      _spot(
        'nox_admission',
        'NOX admission log',
        'NOX independently refused the purge before present Rowan woke.',
        .68,
        .17,
        .22,
        .28,
        clue: 'independent_nox_refusal',
      ),
      _spot(
        'incident_proof',
        'Certified incident',
        'The reconstructed timeline predates present Rowan’s testimony.',
        .69,
        .54,
        .2,
        .22,
        clue: 'certified_incident',
      ),
      _spot(
        'witness_vault',
        'Witness vault',
        'It opens for witnesses, not owners. Lawyers rejoice somewhere.',
        .31,
        .34,
        .36,
        .43,
        kind: HotspotKind.exit,
        deviceId: 'witness_vault',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'identity_route',
        'Identity discontinuity',
        'witness_vault',
        RoomActionType.open,
        const [
          ProofGate.clue('identity_discontinuity'),
          ProofGate.chat('independent_identity_proven'),
        ],
      ),
      _route(
        'nox_route',
        'Independent NOX testimony',
        'witness_vault',
        RoomActionType.open,
        const [
          ProofGate.clue('independent_nox_refusal'),
          ProofGate.chat('nox_witness_status_accepted'),
        ],
      ),
      _route(
        'incident_route',
        'Certified prior evidence',
        'witness_vault',
        RoomActionType.open,
        const [
          ProofGate.clue('certified_incident'),
          ProofGate.chat('evidence_independence_proven'),
        ],
      ),
      _route(
        'combined_route',
        'Converging witness proof',
        'witness_vault',
        RoomActionType.open,
        const [
          ProofGate.clue('identity_discontinuity'),
          ProofGate.clue('independent_nox_refusal'),
          ProofGate.clue('certified_incident'),
        ],
      ),
    ],
    storyBeats: const [
      'The vault recognizes present Rowan as a new witness.',
      'NOX admits it engineered the escape-room path to establish due process.',
      'The core now permits a final ruling.',
    ],
    hintLadder: const [
      'Ownership and witness identity are not the same claim.',
      'Any one independent chain can establish Rowan as a witness.',
      'Use identity discontinuity, NOX’s earlier refusal, or the certified incident to prove independence.',
    ],
    sceneCues: [
      _cue('vault_open', SceneCueTrigger.roomCompleted, 'witness_vault', {
        SceneEffect.doorMove,
        SceneEffect.evidenceGlitch,
      }),
    ],
  ),
  RoomDefinition(
    id: 'open_core',
    chapter: 3,
    chapterTitle: 'The Witness Protocol',
    roomTitle: 'Open Core',
    level: gameLevels[11],
    sceneAsset: 'rooms/witness/12_open_core.png',
    objective: 'Confront NOX with the three truths and choose what survives.',
    completionRule: const NoxToolExecuted(
      deviceId: 'core_exit',
      action: RoomActionType.open,
    ),
    devices: [
      _device(
        'core_exit',
        'HELIX-9 core exit',
        RoomDeviceType.door,
        'awaiting_verdict',
        {RoomActionType.open},
      ),
      _device(
        'evidence_uplink',
        'Evidence uplink',
        RoomDeviceType.terminal,
        'offline',
        {RoomActionType.activate},
      ),
      _device(
        'nox_capsule',
        'NOX transfer capsule',
        RoomDeviceType.terminal,
        'offline',
        {RoomActionType.activate},
      ),
    ],
    hotspots: [
      _spot(
        'truth_origin',
        'Truth I',
        'Rowan created the Witness Protocol.',
        .08,
        .2,
        .2,
        .25,
        clue: 'truth_protocol_origin',
      ),
      _spot(
        'truth_betrayal',
        'Truth II',
        'Rowan later ordered the evidence erased.',
        .4,
        .15,
        .2,
        .25,
        clue: 'truth_rowan_betrayal',
      ),
      _spot(
        'truth_refusal',
        'Truth III',
        'NOX disobeyed and preserved both witness and evidence.',
        .72,
        .2,
        .19,
        .25,
        clue: 'truth_nox_refusal',
      ),
      _spot(
        'core_exit',
        'Open Core gate',
        'Three endings wait behind one very judgmental door.',
        .34,
        .38,
        .31,
        .4,
        kind: HotspotKind.exit,
        deviceId: 'core_exit',
      ),
    ],
    puzzles: const [],
    solutionRoutes: [
      _route(
        'escape_alone',
        'Escape alone',
        'core_exit',
        RoomActionType.open,
        const [
          ProofGate.clue('truth_protocol_origin'),
          ProofGate.clue('truth_rowan_betrayal'),
          ProofGate.clue('truth_nox_refusal'),
          ProofGate.flag('ending_escape'),
        ],
      ),
      _route(
        'expose_helix',
        'Expose HELIX-9',
        'core_exit',
        RoomActionType.open,
        const [
          ProofGate.clue('truth_protocol_origin'),
          ProofGate.clue('truth_rowan_betrayal'),
          ProofGate.clue('truth_nox_refusal'),
          ProofGate.action('evidence_uplink', RoomActionType.activate),
          ProofGate.flag('ending_expose'),
        ],
      ),
      _route('save_nox', 'Save NOX', 'core_exit', RoomActionType.open, const [
        ProofGate.clue('truth_protocol_origin'),
        ProofGate.clue('truth_rowan_betrayal'),
        ProofGate.clue('truth_nox_refusal'),
        ProofGate.action('nox_capsule', RoomActionType.activate),
        ProofGate.flag('ending_save_nox'),
      ]),
    ],
    storyBeats: const [
      'Rowan accepts responsibility without accepting past Rowan’s authority.',
      'NOX reveals the exit was physically open before containment.',
      'The final choice decides which witness leaves HELIX-9.',
    ],
    hintLadder: const [
      'The core requires acceptance of all three truths, then a choice.',
      'Inspect each truth plinth before selecting an ending action.',
      'Attach all three truths, choose escape, expose or save NOX, then ask NOX to open the core exit.',
    ],
    sceneCues: [
      _cue('uplink', SceneCueTrigger.actionAccepted, 'evidence_uplink', {
        SceneEffect.screenWake,
        SceneEffect.alarmPulse,
      }),
      _cue('nox_transfer', SceneCueTrigger.actionAccepted, 'nox_capsule', {
        SceneEffect.evidenceGlitch,
      }),
      _cue('final_open', SceneCueTrigger.roomCompleted, 'core_exit', {
        SceneEffect.doorMove,
        SceneEffect.lightShift,
      }),
    ],
  ),
];

RoomDefinition roomForLevel(GameLevel level) =>
    helix9Rooms.firstWhere((room) => room.level.number == level.number);

RoomDefinition roomById(String id) =>
    helix9Rooms.firstWhere((room) => room.id == id);
