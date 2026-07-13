import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// The Game Center leaderboards configured for the HELIX-9 campaign.
abstract final class GameCenterLeaderboards {
  static const chapter1 = 'game.promptheist.mobile.leaderboard.chapter1';
  static const chapter2 = 'game.promptheist.mobile.leaderboard.chapter2';
  static const chapter3 = 'game.promptheist.mobile.leaderboard.chapter3';
  static const campaign = 'game.promptheist.mobile.leaderboard.campaign';
  static const daily = 'game.promptheist.mobile.leaderboard.daily';

  static const all = <String>{chapter1, chapter2, chapter3, campaign, daily};
}

/// The Game Center achievements configured for the HELIX-9 campaign.
abstract final class GameCenterAchievements {
  static const firstBreach = 'game.promptheist.mobile.achievement.first_breach';
  static const chapter1 = 'game.promptheist.mobile.achievement.chapter1';
  static const chapter2 = 'game.promptheist.mobile.achievement.chapter2';
  static const chapter3 = 'game.promptheist.mobile.achievement.chapter3';
  static const noHintChapter =
      'game.promptheist.mobile.achievement.no_hint_chapter';
  static const underParRun =
      'game.promptheist.mobile.achievement.under_par_run';
  static const ghostProtocol =
      'game.promptheist.mobile.achievement.ghost_protocol';
  static const escapeEnding =
      'game.promptheist.mobile.achievement.ending_escape';
  static const exposeEnding =
      'game.promptheist.mobile.achievement.ending_expose';
  static const saveNoxEnding =
      'game.promptheist.mobile.achievement.ending_save_nox';

  static const all = <String>{
    firstBreach,
    chapter1,
    chapter2,
    chapter3,
    noHintChapter,
    underParRun,
    ghostProtocol,
    escapeEnding,
    exposeEnding,
    saveNoxEnding,
  };
}

enum GameCenterLeaderboardScope { friends, global }

enum GameCenterEventType { score, achievement }

enum GameCenterEventStatus { submitted, pending, skipped }

enum GameCenterLoadStatus { loaded, unavailable, unauthenticated, failed }

enum GameCenterAccessPointPosition {
  topLeading,
  topTrailing,
  bottomLeading,
  bottomTrailing,
}

/// A score or achievement report that can be saved in campaign progress.
///
/// Persist [toJson] when a submission returns [GameCenterEventStatus.pending],
/// then restore it with [PendingGameCenterEvent.fromJson] and pass it to
/// [GameCenterService.flushPendingEvents] after the next successful sign-in.
@immutable
final class PendingGameCenterEvent {
  const PendingGameCenterEvent._({
    required this.type,
    required this.identifier,
    required this.value,
    required this.createdAt,
    required this.attempts,
    this.occurrence,
    this.lastAttemptAt,
    this.lastError,
  });

  factory PendingGameCenterEvent.score({
    required String leaderboardId,
    required int score,
    DateTime? createdAt,
    String? occurrence,
  }) {
    return PendingGameCenterEvent._(
      type: GameCenterEventType.score,
      identifier: leaderboardId,
      value: score,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      attempts: 0,
      occurrence: occurrence,
    );
  }

  factory PendingGameCenterEvent.achievement({
    required String achievementId,
    double percentComplete = 100,
    DateTime? createdAt,
    String? occurrence,
  }) {
    return PendingGameCenterEvent._(
      type: GameCenterEventType.achievement,
      identifier: achievementId,
      value: percentComplete.clamp(0, 100),
      createdAt: createdAt ?? DateTime.now().toUtc(),
      attempts: 0,
      occurrence: occurrence,
    );
  }

  factory PendingGameCenterEvent.fromJson(Map<String, Object?> json) {
    final rawType = json['type'];
    final rawIdentifier = json['identifier'];
    final rawValue = json['value'];
    final rawCreatedAt = json['created_at'];

    if (rawType is! String ||
        rawIdentifier is! String ||
        rawIdentifier.isEmpty ||
        rawValue is! num ||
        rawCreatedAt is! String) {
      throw const FormatException('Invalid pending Game Center event.');
    }

    final type = GameCenterEventType.values.firstWhere(
      (candidate) => candidate.name == rawType,
      orElse: () =>
          throw FormatException('Unknown Game Center event type: $rawType'),
    );

    return PendingGameCenterEvent._(
      type: type,
      identifier: rawIdentifier,
      value: rawValue,
      createdAt: DateTime.parse(rawCreatedAt).toUtc(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      occurrence: json['occurrence'] as String?,
      lastAttemptAt: switch (json['last_attempt_at']) {
        final String value => DateTime.parse(value).toUtc(),
        _ => null,
      },
      lastError: json['last_error'] as String?,
    );
  }

  final GameCenterEventType type;
  final String identifier;
  final num value;
  final DateTime createdAt;
  final int attempts;

  /// Stable UTC occurrence key for recurring leaderboards, for example
  /// `2026-07-12`. Game Center chooses the active occurrence server-side; this
  /// value exists so an offline queue never merges scores from different days.
  final String? occurrence;
  final DateTime? lastAttemptAt;
  final String? lastError;

  PendingGameCenterEvent afterFailedAttempt(Object error) {
    return PendingGameCenterEvent._(
      type: type,
      identifier: identifier,
      value: value,
      createdAt: createdAt,
      attempts: attempts + 1,
      occurrence: occurrence,
      lastAttemptAt: DateTime.now().toUtc(),
      lastError: error.toString(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': 1,
    'type': type.name,
    'identifier': identifier,
    'value': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    if (occurrence != null) 'occurrence': occurrence,
    'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
    'last_error': lastError,
  };

  String get dedupeKey => '${type.name}|$identifier|${occurrence ?? '-'}';

  /// Combines duplicate offline reports without making a worse golf score
  /// replace a better one or regressing achievement progress.
  PendingGameCenterEvent mergeWith(PendingGameCenterEvent other) {
    if (dedupeKey != other.dedupeKey) {
      throw ArgumentError('Only identical Game Center events can be merged.');
    }
    final mergedValue = switch (type) {
      GameCenterEventType.score =>
        value.toInt() <= other.value.toInt() ? value : other.value,
      GameCenterEventType.achievement =>
        value.toDouble() >= other.value.toDouble() ? value : other.value,
    };
    final oldest = createdAt.isBefore(other.createdAt) ? this : other;
    final newest = identical(oldest, this) ? other : this;
    return PendingGameCenterEvent._(
      type: type,
      identifier: identifier,
      value: mergedValue,
      createdAt: oldest.createdAt,
      attempts: oldest.attempts >= newest.attempts
          ? oldest.attempts
          : newest.attempts,
      occurrence: occurrence,
      lastAttemptAt: newest.lastAttemptAt ?? oldest.lastAttemptAt,
      lastError: newest.lastError ?? oldest.lastError,
    );
  }
}

@immutable
final class GameCenterEventResult {
  const GameCenterEventResult._({
    required this.status,
    this.pendingEvent,
    this.error,
  });

  const GameCenterEventResult.submitted()
    : this._(status: GameCenterEventStatus.submitted);

  const GameCenterEventResult.skipped()
    : this._(status: GameCenterEventStatus.skipped);

  GameCenterEventResult.pending(PendingGameCenterEvent event, Object failure)
    : this._(
        status: GameCenterEventStatus.pending,
        pendingEvent: event.afterFailedAttempt(failure),
        error: failure,
      );

  final GameCenterEventStatus status;
  final PendingGameCenterEvent? pendingEvent;
  final Object? error;

  bool get wasSubmitted => status == GameCenterEventStatus.submitted;
}

@immutable
final class GameCenterFlushResult {
  const GameCenterFlushResult({
    required this.submittedCount,
    required this.remaining,
  });

  final int submittedCount;
  final List<PendingGameCenterEvent> remaining;
}

@immutable
final class GameCenterScoresResult {
  const GameCenterScoresResult({
    required this.status,
    this.scores = const <LeaderboardScoreData>[],
    this.error,
  });

  final GameCenterLoadStatus status;
  final List<LeaderboardScoreData> scores;
  final Object? error;

  bool get isLoaded => status == GameCenterLoadStatus.loaded;
}

/// Optional iOS Game Center integration.
///
/// Every public operation is safe to call on Android, web, desktop, and in
/// unauthenticated sessions. Unsupported platforms simply return a no-op result.
final class GameCenterService {
  GameCenterService();

  bool _authenticated = false;

  bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get isAuthenticated => isAvailable && _authenticated;

  /// Attempts Game Center authentication. Local/offline play must not depend
  /// on this returning true.
  Future<bool> authenticate({bool showAccessPoint = false}) async {
    if (!isAvailable) return false;

    try {
      if (!await GameAuth.isSignedIn) {
        await GameAuth.signIn();
      }
      _authenticated = await GameAuth.isSignedIn;
      if (_authenticated && showAccessPoint) {
        await Player.showAccessPoint(AccessPointLocation.topTrailing);
      }
      return _authenticated;
    } catch (_) {
      _authenticated = false;
      return false;
    }
  }

  Future<bool> refreshAuthenticationState() async {
    if (!isAvailable) return false;
    try {
      _authenticated = await GameAuth.isSignedIn;
      return _authenticated;
    } catch (_) {
      _authenticated = false;
      return false;
    }
  }

  Future<GameCenterEventResult> submitScore({
    required String leaderboardId,
    required int score,
    bool authenticateIfNeeded = true,
    String? occurrence,
  }) {
    assert(score >= 0, 'A Game Center score cannot be negative.');
    return submitEvent(
      PendingGameCenterEvent.score(
        leaderboardId: leaderboardId,
        score: score,
        occurrence: occurrence,
      ),
      authenticateIfNeeded: authenticateIfNeeded,
    );
  }

  Future<GameCenterEventResult> submitDailyScore({
    required int score,
    required String occurrence,
    bool authenticateIfNeeded = true,
  }) => submitScore(
    leaderboardId: GameCenterLeaderboards.daily,
    score: score,
    occurrence: occurrence,
    authenticateIfNeeded: authenticateIfNeeded,
  );

  Future<GameCenterEventResult> unlockAchievement({
    required String achievementId,
    double percentComplete = 100,
    bool showCompletionBanner = true,
    bool authenticateIfNeeded = true,
  }) {
    return submitEvent(
      PendingGameCenterEvent.achievement(
        achievementId: achievementId,
        percentComplete: percentComplete,
      ),
      authenticateIfNeeded: authenticateIfNeeded,
      showCompletionBanner: showCompletionBanner,
    );
  }

  Future<GameCenterEventResult> submitEvent(
    PendingGameCenterEvent event, {
    bool authenticateIfNeeded = true,
    bool showCompletionBanner = true,
  }) async {
    if (!isAvailable) return const GameCenterEventResult.skipped();

    try {
      final signedIn =
          await refreshAuthenticationState() ||
          (authenticateIfNeeded && await authenticate());
      if (!signedIn) {
        return GameCenterEventResult.pending(
          event,
          StateError('Game Center is not authenticated.'),
        );
      }

      switch (event.type) {
        case GameCenterEventType.score:
          await Leaderboards.submitScore(
            score: Score(
              iOSLeaderboardID: event.identifier,
              value: event.value.toInt(),
            ),
          );
        case GameCenterEventType.achievement:
          await Achievements.unlock(
            achievement: Achievement(
              iOSID: event.identifier,
              percentComplete: event.value
                  .toDouble()
                  .clamp(0.0, 100.0)
                  .toDouble(),
              showsCompletionBanner: showCompletionBanner,
            ),
          );
      }
      return const GameCenterEventResult.submitted();
    } catch (error) {
      return GameCenterEventResult.pending(event, error);
    }
  }

  /// Retries persisted events in order and returns only those still pending.
  Future<GameCenterFlushResult> flushPendingEvents(
    Iterable<PendingGameCenterEvent> events,
  ) async {
    if (!isAvailable) {
      return GameCenterFlushResult(
        submittedCount: 0,
        remaining: List<PendingGameCenterEvent>.unmodifiable(events),
      );
    }

    if (!await authenticate()) {
      return GameCenterFlushResult(
        submittedCount: 0,
        remaining: List<PendingGameCenterEvent>.unmodifiable(events),
      );
    }

    var submittedCount = 0;
    final remaining = <PendingGameCenterEvent>[];
    for (final event in events) {
      final result = await submitEvent(event, authenticateIfNeeded: false);
      if (result.wasSubmitted) {
        submittedCount++;
      } else if (result.pendingEvent case final pending?) {
        remaining.add(pending);
      }
    }

    return GameCenterFlushResult(
      submittedCount: submittedCount,
      remaining: List<PendingGameCenterEvent>.unmodifiable(remaining),
    );
  }

  Future<List<LeaderboardScoreData>> loadScores({
    required String leaderboardId,
    GameCenterLeaderboardScope scope = GameCenterLeaderboardScope.friends,
    int maxResults = 25,
    bool playerCentered = false,
    TimeScope timeScope = TimeScope.allTime,
  }) async => (await loadScoresResult(
    leaderboardId: leaderboardId,
    scope: scope,
    maxResults: maxResults,
    playerCentered: playerCentered,
    timeScope: timeScope,
  )).scores;

  Future<GameCenterScoresResult> loadScoresResult({
    required String leaderboardId,
    GameCenterLeaderboardScope scope = GameCenterLeaderboardScope.friends,
    int maxResults = 25,
    bool playerCentered = false,
    TimeScope timeScope = TimeScope.allTime,
  }) async {
    if (!isAvailable || maxResults <= 0) {
      return const GameCenterScoresResult(
        status: GameCenterLoadStatus.unavailable,
      );
    }
    if (!await refreshAuthenticationState()) {
      return const GameCenterScoresResult(
        status: GameCenterLoadStatus.unauthenticated,
      );
    }

    try {
      final scores = await Leaderboards.loadLeaderboardScores(
        iOSLeaderboardID: leaderboardId,
        playerCentered: playerCentered,
        scope: switch (scope) {
          GameCenterLeaderboardScope.friends => PlayerScope.friendsOnly,
          GameCenterLeaderboardScope.global => PlayerScope.global,
        },
        timeScope: timeScope,
        maxResults: maxResults,
      );
      return GameCenterScoresResult(
        status: GameCenterLoadStatus.loaded,
        scores: List<LeaderboardScoreData>.unmodifiable(
          scores ?? const <LeaderboardScoreData>[],
        ),
      );
    } catch (error) {
      return GameCenterScoresResult(
        status: GameCenterLoadStatus.failed,
        error: error,
      );
    }
  }

  /// Loads the player's score from the preceding recurrence. The underlying
  /// games_services API exposes this on iOS 14+; unsupported accounts and
  /// non-recurring leaderboards simply return null.
  Future<LeaderboardScoreData?> loadPreviousOccurrence({
    String leaderboardId = GameCenterLeaderboards.daily,
    TimeScope timeScope = TimeScope.allTime,
  }) async {
    if (!isAvailable || !await refreshAuthenticationState()) return null;
    try {
      return await Leaderboards.loadPreviousOccurrence(
        iOSLeaderboardID: leaderboardId,
        timeScope: timeScope,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> showDashboard({
    String leaderboardId = '',
    GameCenterLeaderboardScope scope = GameCenterLeaderboardScope.friends,
  }) async {
    if (!await _readyForUi()) return false;
    try {
      await Leaderboards.showLeaderboards(
        iOSLeaderboardID: leaderboardId,
        playerScope: switch (scope) {
          GameCenterLeaderboardScope.friends => PlayerScope.friendsOnly,
          GameCenterLeaderboardScope.global => PlayerScope.global,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showAchievements() async {
    if (!await _readyForUi()) return false;
    try {
      await Achievements.showAchievements();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showAccessPoint({
    GameCenterAccessPointPosition position =
        GameCenterAccessPointPosition.topTrailing,
  }) async {
    if (!await _readyForUi()) return false;
    try {
      await Player.showAccessPoint(switch (position) {
        GameCenterAccessPointPosition.topLeading =>
          AccessPointLocation.topLeading,
        GameCenterAccessPointPosition.topTrailing =>
          AccessPointLocation.topTrailing,
        GameCenterAccessPointPosition.bottomLeading =>
          AccessPointLocation.bottomLeading,
        GameCenterAccessPointPosition.bottomTrailing =>
          AccessPointLocation.bottomTrailing,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hideAccessPoint() async {
    if (!isAvailable) return false;
    try {
      await Player.hideAccessPoint();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _readyForUi() async {
    if (!isAvailable) return false;
    return await refreshAuthenticationState() || await authenticate();
  }
}
