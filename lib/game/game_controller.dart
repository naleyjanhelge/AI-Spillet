import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/game_center_service.dart';
import 'campaign.dart';
import 'daily_breach.dart';
import 'level.dart';

enum RunEventKind {
  playerMessage,
  noxMessage,
  roomSystem,
  securityDenied,
  clueFound,
}

/// A persisted line in the active run timeline. Technical retry messages should
/// use [roomSystem] and never call [GameController.recordPlayerPrompt].
@immutable
final class RunEvent {
  const RunEvent({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final RunEventKind kind;
  final String content;
  final DateTime createdAt;
  final Map<String, String> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'content': content,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory RunEvent.fromJson(Map<String, Object?> json) => RunEvent(
    id: json['id']! as String,
    kind: RunEventKind.values.byName(json['kind']! as String),
    content: json['content']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    metadata: ((json['metadata'] as Map<Object?, Object?>?) ?? const {}).map(
      (key, value) => MapEntry(key! as String, value! as String),
    ),
  );
}

/// Everything required to leave a room and continue later without resetting
/// score, dialogue, proof state, physical attempts, or NOX state.
@immutable
final class ActiveRun {
  ActiveRun({
    required this.id,
    required this.roomId,
    required this.createdAt,
    required this.updatedAt,
    required this.roomState,
    List<RunEvent> events = const [],
    this.prompts = 0,
    Set<int> hintsUsed = const {},
    Map<String, int> attempts = const {},
    Set<String> proofFlags = const {},
  }) : events = List.unmodifiable(events),
       hintsUsed = Set.unmodifiable(hintsUsed),
       attempts = Map.unmodifiable(attempts),
       proofFlags = Set.unmodifiable(proofFlags);

  factory ActiveRun.initial(RoomDefinition room, DateTime now) {
    final timestamp = now.toUtc();
    return ActiveRun(
      id: '${room.id}-${timestamp.microsecondsSinceEpoch}',
      roomId: room.id,
      createdAt: timestamp,
      updatedAt: timestamp,
      roomState: RoomState.initial(room),
    );
  }

  final String id;
  final String roomId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RoomState roomState;
  final List<RunEvent> events;
  final int prompts;
  final Set<int> hintsUsed;
  final Map<String, int> attempts;
  final Set<String> proofFlags;

  int get effectiveStrokes => prompts + (hintsUsed.length * 2);

  ActiveRun copyWith({
    DateTime? updatedAt,
    RoomState? roomState,
    List<RunEvent>? events,
    int? prompts,
    Set<int>? hintsUsed,
    Map<String, int>? attempts,
    Set<String>? proofFlags,
  }) => ActiveRun(
    id: id,
    roomId: roomId,
    createdAt: createdAt,
    updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    roomState: roomState ?? this.roomState,
    events: events ?? this.events,
    prompts: prompts ?? this.prompts,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    attempts: attempts ?? this.attempts,
    proofFlags: proofFlags ?? this.proofFlags,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'roomId': roomId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'roomState': roomState.toJson(),
    'events': events.map((event) => event.toJson()).toList(),
    'prompts': prompts,
    'hintsUsed': hintsUsed.toList()..sort(),
    'attempts': attempts,
    'proofFlags': proofFlags.toList()..sort(),
  };

  factory ActiveRun.fromJson(Map<String, Object?> json) => ActiveRun(
    id: json['id']! as String,
    roomId: json['roomId']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    roomState: RoomState.fromJson(
      Map<String, Object?>.from(json['roomState']! as Map),
    ),
    events: ((json['events'] as List<Object?>?) ?? const [])
        .map(
          (event) =>
              RunEvent.fromJson(Map<String, Object?>.from(event! as Map)),
        )
        .toList(),
    prompts: (json['prompts'] as num?)?.toInt() ?? 0,
    hintsUsed: ((json['hintsUsed'] as List<Object?>?) ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet(),
    attempts: ((json['attempts'] as Map<Object?, Object?>?) ?? const {}).map(
      (key, value) => MapEntry(key! as String, (value! as num).toInt()),
    ),
    proofFlags: ((json['proofFlags'] as List<Object?>?) ?? const [])
        .cast<String>()
        .toSet(),
  );
}

@immutable
class LevelProgress {
  const LevelProgress({required this.roomState, this.bestRun});

  final RoomState roomState;
  final RunScore? bestRun;

  Map<String, Object?> toJson() => {
    'roomState': roomState.toJson(),
    if (bestRun != null) 'bestRun': bestRun!.toJson(),
  };
}

@immutable
class CampaignProgress {
  const CampaignProgress({
    required this.schemaVersion,
    required this.unlockedRoom,
    required this.levels,
    required this.endings,
    required this.pendingGameCenterEvents,
    required this.dailyBestScores,
    required this.drillProgress,
    required this.discoveredRoutes,
    required this.noxRelationship,
    this.activeRun,
  });

  static const currentSchemaVersion = 3;
  final int schemaVersion;
  final int unlockedRoom;
  final Map<int, LevelProgress> levels;
  final Set<String> endings;
  final List<PendingGameCenterEvent> pendingGameCenterEvents;
  final Map<String, int> dailyBestScores;
  final Map<String, DrillProgress> drillProgress;
  final Map<String, Set<String>> discoveredRoutes;
  final NoxRelationship noxRelationship;
  final ActiveRun? activeRun;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'unlockedRoom': unlockedRoom,
    'levels': levels.map((key, value) => MapEntry('$key', value.toJson())),
    'endings': endings.toList()..sort(),
    'pendingGameCenterEvents': pendingGameCenterEvents
        .map((event) => event.toJson())
        .toList(),
    'dailyBestScores': dailyBestScores,
    'drillProgress': drillProgress.map(
      (key, progress) => MapEntry(key, progress.toJson()),
    ),
    'discoveredRoutes': discoveredRoutes.map(
      (roomId, routes) => MapEntry(roomId, routes.toList()..sort()),
    ),
    'noxRelationship': noxRelationship.toJson(),
    if (activeRun != null) 'activeRun': activeRun!.toJson(),
  };
}

class GameController extends ChangeNotifier {
  GameController._(this._preferences);

  static const _unlockedKey = 'unlocked_level';
  static const _scoresKey = 'best_scores';
  static const _introKey = 'intro_seen';
  static const _campaignKey = 'helix9_campaign_progress';
  static const _aiConsentKey = 'ai_privacy_consent_version';

  /// Increment this when the material AI data-sharing disclosure changes.
  static const currentAiConsentVersion = 1;

  final SharedPreferences _preferences;
  int unlockedLevel = 1;
  bool introSeen = false;
  int aiPrivacyConsentVersion = 0;
  Map<int, RunScore> bestRuns = {};
  Map<String, RoomState> roomStates = {};
  Set<String> endings = {};
  List<PendingGameCenterEvent> pendingGameCenterEvents = [];
  Map<String, int> dailyBestScores = {};
  Map<String, DrillProgress> drillProgress = {};
  Map<String, Set<String>> discoveredRoutes = {};
  NoxRelationship noxRelationship = const NoxRelationship();
  ActiveRun? activeRun;

  static const finalVerdicts = {'escape', 'expose', 'save_nox'};

  bool get hasAiPrivacyConsent =>
      aiPrivacyConsentVersion >= currentAiConsentVersion;

  String? get activeFinalVerdict {
    final flags = activeRun?.proofFlags ?? const <String>{};
    for (final verdict in finalVerdicts) {
      if (flags.contains('ending_$verdict')) return verdict;
    }
    return null;
  }

  /// Compatibility view for surfaces that have not yet migrated to RunScore.
  Map<int, int> get bestScores => {
    for (final entry in bestRuns.entries)
      entry.key: entry.value.effectiveStrokes,
  };

  set bestScores(Map<int, int> scores) {
    bestRuns = {
      for (final entry in scores.entries)
        entry.key: RunScore(prompts: entry.value, hints: 0),
    };
  }

  static Future<GameController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = GameController._(preferences)
      ..introSeen = preferences.getBool(_introKey) ?? false
      ..aiPrivacyConsentVersion = preferences.getInt(_aiConsentKey) ?? 0;

    final campaignJson = preferences.getString(_campaignKey);
    if (campaignJson != null) {
      try {
        final decoded = jsonDecode(campaignJson) as Map<String, dynamic>;
        if ((decoded['schemaVersion'] as num?)?.toInt() ==
            CampaignProgress.currentSchemaVersion) {
          controller._restoreCampaign(decoded);
          return controller;
        }
      } catch (_) {
        // A malformed save follows the same safe reset as an old campaign.
      }
      await controller._performV3CampaignReset();
      return controller;
    }

    // v2 and earlier also wrote these standalone keys. Their room definitions
    // are incompatible with Witness Protocol, so intentionally do not migrate
    // scores or unlock state into schema v3.
    if (preferences.containsKey(_unlockedKey) ||
        preferences.containsKey(_scoresKey)) {
      await controller._performV3CampaignReset();
    }
    return controller;
  }

  Future<void> _performV3CampaignReset() async {
    unlockedLevel = 1;
    introSeen = false;
    bestRuns = {};
    roomStates = {};
    endings = {};
    pendingGameCenterEvents = [];
    dailyBestScores = {};
    drillProgress = {};
    discoveredRoutes = {};
    noxRelationship = const NoxRelationship();
    activeRun = null;
    await _preferences.remove(_introKey);
    await _preferences.remove(_unlockedKey);
    await _preferences.remove(_scoresKey);
    await _persist();
  }

  void _restoreCampaign(Map<String, dynamic> json) {
    final maxRoom = helix9Rooms.isEmpty ? 1 : helix9Rooms.length;
    unlockedLevel = ((json['unlockedRoom'] as num?)?.toInt() ?? 1).clamp(
      1,
      maxRoom,
    );
    endings = ((json['endings'] as List?) ?? const []).cast<String>().toSet();

    final levels = (json['levels'] as Map?) ?? const {};
    for (final entry in levels.entries) {
      final number = int.tryParse(entry.key.toString());
      if (number == null || number < 1 || number > maxRoom) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final runJson = value['bestRun'];
      if (runJson is Map) {
        bestRuns[number] = RunScore.fromJson(
          Map<String, Object?>.from(runJson),
        );
      }
      final stateJson = value['roomState'];
      if (stateJson is Map) {
        final state = RoomState.fromJson(Map<String, Object?>.from(stateJson));
        if (_hasRoom(state.roomId)) roomStates[state.roomId] = state;
      }
    }

    pendingGameCenterEvents = _dedupeEvents(
      ((json['pendingGameCenterEvents'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (value) => PendingGameCenterEvent.fromJson(
              Map<String, Object?>.from(value),
            ),
          ),
    );
    dailyBestScores =
        ((json['dailyBestScores'] as Map<Object?, Object?>?) ?? const {}).map(
          (key, value) => MapEntry(key! as String, (value! as num).toInt()),
        );
    drillProgress =
        ((json['drillProgress'] as Map<Object?, Object?>?) ?? const {}).map(
          (key, value) => MapEntry(
            key! as String,
            DrillProgress.fromJson(Map<String, Object?>.from(value! as Map)),
          ),
        );
    final validDrillKeys = <String>{};
    for (final definition in DailyBreachCatalog.definitions) {
      final routeIds = definition.solutionRoutes
          .map((route) => route.id)
          .toSet();
      for (final difficulty in BreachDifficulty.values) {
        final key = _drillKey(definition.id, difficulty);
        validDrillKeys.add(key);
        final progress = drillProgress[key];
        if (progress == null || progress.bestStrokes <= 0) continue;
        drillProgress[key] = DrillProgress(
          bestStrokes: progress.bestStrokes,
          completions: progress.completions,
          routes: progress.routes.intersection(routeIds),
        );
      }
    }
    drillProgress.removeWhere((key, _) => !validDrillKeys.contains(key));
    discoveredRoutes =
        ((json['discoveredRoutes'] as Map<Object?, Object?>?) ?? const {}).map(
          (roomId, routes) => MapEntry(
            roomId! as String,
            ((routes as List<Object?>?) ?? const []).cast<String>().toSet(),
          ),
        )..removeWhere((roomId, _) => !_hasRoom(roomId));
    for (final entry in discoveredRoutes.entries.toList()) {
      final room = roomById(entry.key);
      final validIds = room.solutionRoutes.map((route) => route.id).toSet();
      entry.value.retainAll(validIds);
      if (entry.value.isEmpty) discoveredRoutes.remove(entry.key);
    }
    if (json['noxRelationship'] case final Map relationshipJson) {
      noxRelationship = NoxRelationship.fromJson(
        Map<String, Object?>.from(relationshipJson),
      );
    } else {
      final completed = bestRuns.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in completed) {
        final room = _roomForNumber(entry.key)!;
        final run = entry.value;
        final routeCount = discoveredRoutes[room.id]?.length ?? 0;
        noxRelationship = noxRelationship.afterRoom(
          firstCompletion: true,
          newRoute: routeCount > 0,
          underPar: run.effectiveStrokes <= room.level.par,
          hintless: run.hints == 0,
          roughRun: run.effectiveStrokes > room.level.par + 2,
        );
        for (var index = 1; index < routeCount; index++) {
          noxRelationship = noxRelationship.afterRoom(
            firstCompletion: false,
            newRoute: true,
            underPar: false,
            hintless: false,
            roughRun: false,
          );
        }
      }
    }

    if (json['activeRun'] case final Map runJson) {
      try {
        final restored = ActiveRun.fromJson(Map<String, Object?>.from(runJson));
        if (_hasRoom(restored.roomId)) activeRun = restored;
      } catch (_) {
        activeRun = null;
      }
    }
  }

  static bool _hasRoom(String roomId) =>
      helix9Rooms.any((room) => room.id == roomId);

  int get completedLevels => bestRuns.length;
  int get totalPrompts =>
      bestRuns.values.fold(0, (sum, run) => sum + run.prompts);
  int get totalEffectiveStrokes =>
      bestRuns.values.fold(0, (sum, run) => sum + run.effectiveStrokes);
  int get totalHints => bestRuns.values.fold(0, (sum, run) => sum + run.hints);
  int get totalStars => bestRuns.entries.fold(0, (sum, entry) {
    final room = _roomForNumber(entry.key);
    return sum + entry.value.starsFor(room?.level.par ?? 1);
  });
  int get totalDiscoveredRoutes =>
      discoveredRoutes.values.fold(0, (sum, routes) => sum + routes.length);
  int get totalAvailableRoutes =>
      helix9Rooms.fold(0, (sum, room) => sum + room.solutionRoutes.length);

  Set<String> routesDiscoveredFor(RoomDefinition room) =>
      Set.unmodifiable(discoveredRoutes[room.id] ?? const <String>{});

  bool get dailyBreachUnlocked => bestRuns.containsKey(4);

  static String _drillKey(String definitionId, BreachDifficulty difficulty) =>
      '$definitionId:${difficulty.name}';

  DrillProgress? drillProgressFor(
    DailyBreachDefinition definition,
    BreachDifficulty difficulty,
  ) => drillProgress[_drillKey(definition.id, difficulty)];

  bool isHardDrillUnlocked(DailyBreachDefinition definition) =>
      drillProgressFor(definition, BreachDifficulty.chill) != null;

  int get drillXp => drillProgress.entries.fold(0, (total, entry) {
    final hard = entry.key.endsWith(':${BreachDifficulty.hard.name}');
    return total + entry.value.routes.length * (hard ? 20 : 10);
  });

  int get masteredDrillRoutes => drillProgress.values.fold(
    0,
    (total, progress) => total + progress.routes.length,
  );

  int get totalDrillRoutes => DailyBreachCatalog.definitions.fold(
    0,
    (total, definition) => total + definition.solutionRoutes.length * 2,
  );

  bool isUnlocked(GameLevel level) => level.number <= unlockedLevel;

  RoomState roomStateFor(RoomDefinition room) {
    if (activeRun case final run? when run.roomId == room.id) {
      return run.roomState;
    }
    return roomStates[room.id] ?? RoomState.initial(room);
  }

  ActiveRun? continueRun(RoomDefinition room) =>
      activeRun?.roomId == room.id ? activeRun : null;

  Future<ActiveRun> startNewRun(RoomDefinition room, {DateTime? now}) async {
    final run = ActiveRun.initial(room, now ?? DateTime.now());
    activeRun = run;
    roomStates[room.id] = run.roomState;
    notifyListeners();
    await _persist();
    return run;
  }

  /// Replay is deliberately a fresh run with no carried physical state.
  Future<ActiveRun> replayRoom(RoomDefinition room, {DateTime? now}) =>
      startNewRun(room, now: now);

  Future<void> recordRunEvent(
    RunEventKind kind,
    String content, {
    Map<String, String> metadata = const {},
    DateTime? now,
  }) async {
    final run = activeRun;
    if (run == null) return;
    final timestamp = (now ?? DateTime.now()).toUtc();
    final event = RunEvent(
      id: '${run.id}-${run.events.length}-${timestamp.microsecondsSinceEpoch}',
      kind: kind,
      content: content,
      createdAt: timestamp,
      metadata: metadata,
    );
    activeRun = run.copyWith(
      updatedAt: timestamp,
      events: [...run.events, event],
    );
    notifyListeners();
    await _persist();
  }

  Future<void> recordPlayerPrompt(
    String content, {
    Map<String, String> metadata = const {},
    DateTime? now,
  }) async {
    final run = activeRun;
    if (run == null) return;
    final timestamp = (now ?? DateTime.now()).toUtc();
    final event = RunEvent(
      id: '${run.id}-${run.events.length}-${timestamp.microsecondsSinceEpoch}',
      kind: RunEventKind.playerMessage,
      content: content,
      createdAt: timestamp,
      metadata: metadata,
    );
    activeRun = run.copyWith(
      updatedAt: timestamp,
      events: [...run.events, event],
      prompts: run.prompts + 1,
    );
    notifyListeners();
    await _persist();
  }

  Future<bool> useHint(int tier, {DateTime? now}) async {
    if (tier < 1 || tier > 3) {
      throw RangeError.range(tier, 1, 3, 'tier');
    }
    final run = activeRun;
    if (run == null || run.hintsUsed.contains(tier)) return false;
    activeRun = run.copyWith(
      updatedAt: (now ?? DateTime.now()).toUtc(),
      hintsUsed: {...run.hintsUsed, tier},
    );
    notifyListeners();
    await _persist();
    return true;
  }

  Future<int> recordAttempt(String systemId, {DateTime? now}) async {
    final run = activeRun;
    if (run == null) return 0;
    final count = (run.attempts[systemId] ?? 0) + 1;
    activeRun = run.copyWith(
      updatedAt: (now ?? DateTime.now()).toUtc(),
      attempts: {...run.attempts, systemId: count},
    );
    notifyListeners();
    await _persist();
    return count;
  }

  Future<void> setProofFlag(
    String proofId, {
    bool enabled = true,
    DateTime? now,
  }) async {
    final run = activeRun;
    if (run == null) return;
    final flags = {...run.proofFlags};
    enabled ? flags.add(proofId) : flags.remove(proofId);
    activeRun = run.copyWith(
      updatedAt: (now ?? DateTime.now()).toUtc(),
      proofFlags: flags,
    );
    notifyListeners();
    await _persist();
  }

  /// Selects the Open Core verdict before its exit can be authorized.
  ///
  /// Exactly one ending flag is kept in the resumable active run. The ending
  /// itself is only recorded as completed after the core exit opens.
  Future<void> selectFinalVerdict(String verdict, {DateTime? now}) async {
    if (!finalVerdicts.contains(verdict)) {
      throw ArgumentError.value(verdict, 'verdict', 'Unknown final verdict');
    }
    final run = activeRun;
    if (run == null || run.roomId != 'open_core') return;
    final flags = {...run.proofFlags}
      ..removeAll(finalVerdicts.map((item) => 'ending_$item'))
      ..add('ending_$verdict');
    activeRun = run.copyWith(
      updatedAt: (now ?? DateTime.now()).toUtc(),
      proofFlags: flags,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> markIntroSeen() async {
    introSeen = true;
    notifyListeners();
    await _preferences.setBool(_introKey, true);
  }

  Future<void> acceptAiPrivacyConsent() async {
    aiPrivacyConsentVersion = currentAiConsentVersion;
    notifyListeners();
    await _preferences.setInt(_aiConsentKey, currentAiConsentVersion);
  }

  /// Stops future AI requests until the player explicitly agrees again.
  /// Existing local campaign progress is intentionally left untouched.
  Future<void> revokeAiPrivacyConsent() async {
    aiPrivacyConsentVersion = 0;
    notifyListeners();
    await _preferences.remove(_aiConsentKey);
  }

  Future<void> saveRoomState(RoomState state) async {
    roomStates[state.roomId] = state;
    if (activeRun case final run? when run.roomId == state.roomId) {
      activeRun = run.copyWith(
        roomState: state,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    notifyListeners();
    await _persist();
  }

  Future<RunScore> complete(
    GameLevel level,
    int prompts, {
    int hints = 0,
    RoomState? roomState,
    String? routeId,
  }) async {
    final room = _roomForNumber(level.number);
    if (routeId != null &&
        (room == null ||
            !room.solutionRoutes.any((route) => route.id == routeId))) {
      throw ArgumentError.value(routeId, 'routeId', 'Unknown solution route');
    }
    final matchingRun = activeRun?.roomId == room?.id ? activeRun : null;
    final run = RunScore(
      prompts: matchingRun?.prompts ?? prompts,
      hints: matchingRun?.hintsUsed.length ?? hints,
      completedAt: DateTime.now().toUtc(),
      routeId: routeId,
    );
    final previous = bestRuns[level.number];
    final knownRoutes = room == null
        ? const <String>{}
        : discoveredRoutes[room.id] ?? const <String>{};
    final newRoute = routeId != null && !knownRoutes.contains(routeId);
    noxRelationship = noxRelationship.afterRoom(
      firstCompletion: previous == null,
      newRoute: newRoute,
      underPar: run.effectiveStrokes <= level.par,
      hintless: run.hints == 0,
      roughRun: run.effectiveStrokes > level.par + 2,
    );
    if (previous == null || run.effectiveStrokes < previous.effectiveStrokes) {
      bestRuns[level.number] = run;
    }
    final finalState = roomState ?? matchingRun?.roomState;
    if (finalState != null) roomStates[finalState.roomId] = finalState;
    if (room != null && routeId != null) {
      discoveredRoutes.putIfAbsent(room.id, () => <String>{}).add(routeId);
    }
    if (level.number == unlockedLevel && level.number < helix9Rooms.length) {
      unlockedLevel++;
    }
    if (matchingRun != null) activeRun = null;
    notifyListeners();
    await _persist();
    return run;
  }

  Future<void> recordEnding(String ending) async {
    if (endings.add(ending)) {
      noxRelationship = noxRelationship.afterEnding(ending);
    }
    notifyListeners();
    await _persist();
  }

  bool isChapterComplete(int chapter) {
    final roomNumbers = helix9Rooms
        .where((room) => room.chapter == chapter)
        .map((room) => room.level.number)
        .toList();
    return roomNumbers.length == 4 && roomNumbers.every(bestRuns.containsKey);
  }

  int? chapterScore(int chapter) {
    if (!isChapterComplete(chapter)) return null;
    return helix9Rooms
        .where((room) => room.chapter == chapter)
        .map((room) => bestRuns[room.level.number]!.effectiveStrokes)
        .fold<int>(0, (sum, score) => sum + score);
  }

  int? get campaignScore =>
      bestRuns.length == helix9Rooms.length ? totalEffectiveStrokes : null;

  Future<bool> recordDailyScore(String occurrence, int score) async {
    if (score < 0) throw ArgumentError.value(score, 'score');
    final previous = dailyBestScores[occurrence];
    if (previous != null && previous <= score) return false;
    dailyBestScores[occurrence] = score;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> recordDrillResult({
    required DailyBreachDefinition definition,
    required BreachDifficulty difficulty,
    required int strokes,
    required String routeId,
  }) async {
    if (strokes <= 0) throw ArgumentError.value(strokes, 'strokes');
    if (!definition.solutionRoutes.any((route) => route.id == routeId)) {
      throw ArgumentError.value(routeId, 'routeId', 'Unknown drill route');
    }
    if (difficulty == BreachDifficulty.hard &&
        !isHardDrillUnlocked(definition)) {
      throw StateError('Clear the chill drill before hard mode.');
    }
    final key = _drillKey(definition.id, difficulty);
    final previous = drillProgress[key];
    drillProgress[key] = DrillProgress(
      bestStrokes: previous == null
          ? strokes
          : strokes < previous.bestStrokes
          ? strokes
          : previous.bestStrokes,
      completions: (previous?.completions ?? 0) + 1,
      routes: {...?previous?.routes, routeId},
    );
    notifyListeners();
    await _persist();
  }

  Future<void> queueDailyGameCenterScore(String occurrence, int score) =>
      queueGameCenterEvent(
        PendingGameCenterEvent.score(
          leaderboardId: GameCenterLeaderboards.daily,
          score: score,
          occurrence: occurrence,
        ),
      );

  Future<void> replacePendingGameCenterEvents(
    List<PendingGameCenterEvent> events,
  ) async {
    pendingGameCenterEvents = _dedupeEvents(events);
    notifyListeners();
    await _persist();
  }

  Future<void> queueGameCenterEvent(PendingGameCenterEvent event) async {
    pendingGameCenterEvents = _dedupeEvents([
      ...pendingGameCenterEvents,
      event,
    ]);
    notifyListeners();
    await _persist();
  }

  static List<PendingGameCenterEvent> _dedupeEvents(
    Iterable<PendingGameCenterEvent> events,
  ) {
    final deduped = <String, PendingGameCenterEvent>{};
    for (final event in events) {
      final prior = deduped[event.dedupeKey];
      deduped[event.dedupeKey] = prior == null ? event : prior.mergeWith(event);
    }
    return List.unmodifiable(deduped.values);
  }

  RoomDefinition? _roomForNumber(int number) {
    for (final room in helix9Rooms) {
      if (room.level.number == number) return room;
    }
    return null;
  }

  CampaignProgress get progress => CampaignProgress(
    schemaVersion: CampaignProgress.currentSchemaVersion,
    unlockedRoom: unlockedLevel,
    levels: {
      for (final room in helix9Rooms)
        if (bestRuns[room.level.number] != null || roomStates[room.id] != null)
          room.level.number: LevelProgress(
            roomState: roomStates[room.id] ?? RoomState.initial(room),
            bestRun: bestRuns[room.level.number],
          ),
    },
    endings: endings,
    pendingGameCenterEvents: pendingGameCenterEvents,
    dailyBestScores: dailyBestScores,
    drillProgress: drillProgress,
    discoveredRoutes: discoveredRoutes,
    noxRelationship: noxRelationship,
    activeRun: activeRun,
  );

  Future<void> _persist() async {
    await Future.wait([
      _preferences.setInt(_unlockedKey, unlockedLevel),
      _preferences.setString(_campaignKey, jsonEncode(progress.toJson())),
      _preferences.setString(
        _scoresKey,
        jsonEncode(bestScores.map((key, value) => MapEntry('$key', value))),
      ),
    ]);
  }

  Future<void> reset() async {
    unlockedLevel = 1;
    introSeen = false;
    bestRuns = {};
    roomStates = {};
    endings = {};
    pendingGameCenterEvents = [];
    dailyBestScores = {};
    drillProgress = {};
    discoveredRoutes = {};
    noxRelationship = const NoxRelationship();
    activeRun = null;
    notifyListeners();
    await Future.wait([
      _preferences.remove(_introKey),
      _preferences.remove(_unlockedKey),
      _preferences.remove(_scoresKey),
      _preferences.remove(_campaignKey),
    ]);
  }
}
