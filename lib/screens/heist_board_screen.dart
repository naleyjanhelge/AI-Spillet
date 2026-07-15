import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:games_services/games_services.dart';

import '../game/campaign.dart';
import '../game/daily_breach.dart';
import '../game/game_controller.dart';
import '../services/game_center_service.dart';
import '../services/share_card_service.dart';
import '../ui/completion_share_card.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';

enum _BoardScope { local, friends, global }

enum _BoardKind { daily, campaign, chapter1, chapter2, chapter3 }

enum _RemoteState { idle, loading, ready, unavailable, signInRequired, failed }

extension on _BoardKind {
  String get label => switch (this) {
    _BoardKind.daily => 'DAILY',
    _BoardKind.campaign => 'CAMPAIGN',
    _BoardKind.chapter1 => 'ACT I',
    _BoardKind.chapter2 => 'ACT II',
    _BoardKind.chapter3 => 'ACT III',
  };

  String get leaderboardId => switch (this) {
    _BoardKind.daily => GameCenterLeaderboards.daily,
    _BoardKind.campaign => GameCenterLeaderboards.campaign,
    _BoardKind.chapter1 => GameCenterLeaderboards.chapter1,
    _BoardKind.chapter2 => GameCenterLeaderboards.chapter2,
    _BoardKind.chapter3 => GameCenterLeaderboards.chapter3,
  };

  int? get chapter => switch (this) {
    _BoardKind.chapter1 => 1,
    _BoardKind.chapter2 => 2,
    _BoardKind.chapter3 => 3,
    _ => null,
  };
}

class HeistBoardScreen extends StatefulWidget {
  const HeistBoardScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HeistBoardScreen> createState() => _HeistBoardScreenState();
}

class _HeistBoardScreenState extends State<HeistBoardScreen> {
  final _gameCenter = GameCenterService();
  final _shareCards = const ShareCardService();
  _BoardScope _scope = _BoardScope.local;
  _BoardKind _board = _BoardKind.daily;
  _RemoteState _remoteState = _RemoteState.idle;
  List<LeaderboardScoreData> _remoteScores = const [];
  LeaderboardScoreData? _previousDaily;
  int _requestId = 0;

  GameController get controller => widget.controller;

  DailyBreachSelection get _daily => DailyBreachCatalog.forDate(DateTime.now());

  Future<void> _shareRecord(BuildContext buttonContext, int number) async {
    final room = helix9Rooms.firstWhere(
      (candidate) => candidate.level.number == number,
    );
    final run = controller.bestRuns[number]!;
    await _shareCards.shareCompletion(
      context: context,
      data: CompletionShareCardData(
        chapterNumber: room.chapter,
        chapterTitle: room.chapterTitle,
        roomNumber: number,
        roomTitle: room.roomTitle,
        stars: run.starsFor(room.level.par),
        prompts: run.prompts,
        hintsUsed: run.hints,
        noxQuote: 'Archived with reluctant respect and excessive paperwork.',
        roomArt: AssetImage('assets/images/${room.sceneAsset}'),
        accent: room.level.accent,
        spoilerTerms: [room.level.secret],
      ),
      sharePositionOrigin: ShareCardService.shareOriginFor(buttonContext),
    );
  }

  void _selectScope(_BoardScope scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    if (scope != _BoardScope.local) unawaited(_loadRemote());
  }

  void _selectBoard(_BoardKind board) {
    if (_board == board) return;
    setState(() => _board = board);
    if (_scope != _BoardScope.local) unawaited(_loadRemote());
  }

  Future<void> _loadRemote() async {
    final requestId = ++_requestId;
    if (!_gameCenter.isAvailable) {
      if (mounted) {
        setState(() {
          _remoteState = _RemoteState.unavailable;
          _remoteScores = const [];
          _previousDaily = null;
        });
      }
      return;
    }

    setState(() {
      _remoteState = _RemoteState.loading;
      _remoteScores = const [];
      _previousDaily = null;
    });

    final authenticated = await _gameCenter.authenticate();
    if (!mounted || requestId != _requestId) return;
    if (!authenticated) {
      setState(() => _remoteState = _RemoteState.signInRequired);
      return;
    }

    final result = await _gameCenter.loadScoresResult(
      leaderboardId: _board.leaderboardId,
      scope: _scope == _BoardScope.friends
          ? GameCenterLeaderboardScope.friends
          : GameCenterLeaderboardScope.global,
      maxResults: 50,
      playerCentered: false,
    );
    final previous = _board == _BoardKind.daily
        ? await _gameCenter.loadPreviousOccurrence()
        : null;
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _remoteScores = result.scores;
      _previousDaily = previous;
      _remoteState = switch (result.status) {
        GameCenterLoadStatus.loaded => _RemoteState.ready,
        GameCenterLoadStatus.unavailable => _RemoteState.unavailable,
        GameCenterLoadStatus.unauthenticated => _RemoteState.signInRequired,
        GameCenterLoadStatus.failed => _RemoteState.failed,
      };
    });
  }

  Future<void> _openGameCenter() async {
    final opened = await _gameCenter.showDashboard(
      leaderboardId: _board.leaderboardId,
      scope: _scope == _BoardScope.friends
          ? GameCenterLeaderboardScope.friends
          : GameCenterLeaderboardScope.global,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game Center could not open. Local records are safe.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = controller.bestScores.entries.toList()
      ..sort((a, b) {
        final aRoom = _roomForNumber(a.key);
        final bRoom = _roomForNumber(b.key);
        final aDelta = a.value - aRoom.level.par;
        final bDelta = b.value - bRoom.level.par;
        return aDelta != bDelta
            ? aDelta.compareTo(bDelta)
            : a.value.compareTo(b.value);
      });
    final maxStars = helix9Rooms.length * 3;
    final rank = _rankFor(controller.totalStars, maxStars);
    final totalPar = controller.bestScores.keys.fold<int>(
      0,
      (sum, number) => sum + _roomForNumber(number).level.par,
    );
    final efficiency = controller.totalPrompts == 0
        ? 0
        : ((totalPar / controller.totalPrompts) * 100).round().clamp(0, 199);

    return Scaffold(
      body: AnimatedGameBackground(
        artOpacity: .74,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 8, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HEIST BOARD',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              switch (_scope) {
                                _BoardScope.local =>
                                  'PERSONAL RECORDS // ON THIS DEVICE',
                                _BoardScope.friends =>
                                  'APPLE GAME CENTER // FRIENDS',
                                _BoardScope.global =>
                                  'APPLE GAME CENTER // GLOBAL',
                              },
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.cyan,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: SegmentedButton<_BoardScope>(
                    segments: const [
                      ButtonSegment(
                        value: _BoardScope.local,
                        label: Text('LOCAL'),
                        icon: Icon(Icons.phone_iphone_rounded),
                      ),
                      ButtonSegment(
                        value: _BoardScope.friends,
                        label: Text('FRIENDS'),
                        icon: Icon(Icons.people_alt_rounded),
                      ),
                      ButtonSegment(
                        value: _BoardScope.global,
                        label: Text('GLOBAL'),
                        icon: Icon(Icons.public_rounded),
                      ),
                    ],
                    selected: {_scope},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) => _selectScope(value.first),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 13, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final board in _BoardKind.values)
                        ChoiceChip(
                          label: Text(board.label),
                          selected: _board == board,
                          onSelected: (_) => _selectBoard(board),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _RankPanel(
                    rank: rank,
                    efficiency: efficiency,
                    stars: controller.totalStars,
                    maxStars: maxStars,
                    strokes: controller.totalEffectiveStrokes,
                    routes: controller.totalDiscoveredRoutes,
                    maxRoutes: controller.totalAvailableRoutes,
                    relationship: controller.noxRelationship,
                  ).animate().fadeIn().slideY(begin: .08),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _scope == _BoardScope.local
                      ? _LocalLeaderboardCard(
                          board: _board,
                          controller: controller,
                          daily: _daily,
                        )
                      : _RemoteLeaderboardHeader(
                          state: _remoteState,
                          scope: _scope,
                          board: _board,
                          onRetry: _loadRemote,
                          onOpen: _openGameCenter,
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _scope == _BoardScope.local
                        ? 'BEST OPERATIONS'
                        : '${_board.label} SCORES',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              if (_scope == _BoardScope.local)
                ..._localRecordSlivers(records)
              else
                ..._remoteScoreSlivers(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'ACHIEVEMENTS',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: _achievements(controller)
                      .map(
                        (achievement) =>
                            _AchievementCard(achievement: achievement),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _localRecordSlivers(List<MapEntry<int, int>> records) {
    if (records.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: GlassPanel(
              child: Text(
                'No breaches yet. NOX has filed this under “adorable.”',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final record = records[index];
            final room = _roomForNumber(record.key);
            final delta = record.value - room.level.par;
            final discovered = controller.routesDiscoveredFor(room);
            final bestRouteId = controller.bestRuns[record.key]?.routeId;
            SolutionRoute? bestRoute;
            for (final route in room.solutionRoutes) {
              if (route.id == bestRouteId) bestRoute = route;
            }
            return GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              borderColor: index == 0 ? room.level.accent : null,
              child: Row(
                children: [
                  Text(
                    '#${index + 1}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: index == 0
                          ? room.level.accent
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(room.level.icon, color: room.level.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.roomTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          delta < 0
                              ? '${delta.abs()} UNDER PAR'
                              : delta == 0
                              ? 'EXACTLY PAR'
                              : '$delta OVER PAR',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        Text(
                          '${discovered.length}/${room.solutionRoutes.length} routes${bestRoute == null ? '' : ' · best via ${bestRoute.label}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: room.level.accent),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${record.value}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.sports_golf_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: 'Regenerate share card',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          unawaited(_shareRecord(buttonContext, record.key)),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ).animate(delay: (70 * index).ms).fadeIn().slideX(begin: .08);
          },
        ),
      ),
    ];
  }

  List<Widget> _remoteScoreSlivers() {
    if (_remoteState == _RemoteState.loading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: GlassPanel(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Requesting verified Game Center scores…'),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (_remoteState != _RemoteState.ready) return const [];

    final slivers = <Widget>[];
    if (_board == _BoardKind.daily && _previousDaily != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          sliver: SliverToBoxAdapter(
            child: GlassPanel(
              borderColor: AppColors.ultraviolet,
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.ultraviolet,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR PREVIOUS DAILY',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          '#${_previousDaily!.rank} · ${_previousDaily!.displayScore}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_remoteScores.isEmpty) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: GlassPanel(
              child: Text(
                'No verified scores yet. Either you are first, or everyone else has excellent legal counsel.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      );
      return slivers;
    }
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList.separated(
          itemCount: _remoteScores.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final score = _remoteScores[index];
            final name = score.scoreHolder.displayName.trim().isEmpty
                ? 'CLASSIFIED PLAYER'
                : score.scoreHolder.displayName;
            return GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              borderColor: score.rank == 1 ? AppColors.cyan : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 45,
                    child: Text(
                      '#${score.rank}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: score.rank == 1
                            ? AppColors.cyan
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.surfaceHigh,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    score.displayScore.isEmpty
                        ? '${score.rawScore}'
                        : score.displayScore,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    return slivers;
  }

  RoomDefinition _roomForNumber(int number) =>
      helix9Rooms.firstWhere((room) => room.level.number == number);
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({
    required this.rank,
    required this.efficiency,
    required this.stars,
    required this.maxStars,
    required this.strokes,
    required this.routes,
    required this.maxRoutes,
    required this.relationship,
  });

  final _Rank rank;
  final int efficiency;
  final int stars;
  final int maxStars;
  final int strokes;
  final int routes;
  final int maxRoutes;
  final NoxRelationship relationship;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderColor: AppColors.cyan,
      child: Column(
        children: [
          Row(
            children: [
              const NoxAvatar(size: 82),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT RANK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank.name,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(color: rank.color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank.taunt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.deepSpace.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cyan.withValues(alpha: .24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOX CONTINUITY // ${relationship.stanceLabel.toUpperCase()}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.cyan),
                ),
                const SizedBox(height: 4),
                Text(
                  relationship.statusLine,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RelationshipMeter(
                      label: 'TRUST',
                      value: relationship.trust,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(width: 10),
                    _RelationshipMeter(
                      label: 'RESPECT',
                      value: relationship.respect,
                      color: AppColors.ultraviolet,
                    ),
                    const SizedBox(width: 10),
                    _RelationshipMeter(
                      label: 'FRICTION',
                      value: relationship.friction,
                      color: AppColors.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _BoardStat(
                label: 'EFFICIENCY',
                value: '$efficiency%',
                color: AppColors.cyan,
              ),
              _BoardStat(
                label: 'TOTAL STARS',
                value: '$stars/$maxStars',
                color: AppColors.ultraviolet,
              ),
              _BoardStat(
                label: 'STROKES',
                value: '$strokes',
                color: AppColors.success,
              ),
              _BoardStat(
                label: 'ROUTES',
                value: '$routes/$maxRoutes',
                color: const Color(0xFFFFB84D),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalLeaderboardCard extends StatelessWidget {
  const _LocalLeaderboardCard({
    required this.board,
    required this.controller,
    required this.daily,
  });

  final _BoardKind board;
  final GameController controller;
  final DailyBreachSelection daily;

  @override
  Widget build(BuildContext context) {
    final (title, detail, score, icon, locked) = _content();
    return GlassPanel(
      borderColor: locked ? AppColors.textMuted : AppColors.ultraviolet,
      child: Row(
        children: [
          Icon(
            icon,
            color: locked ? AppColors.textMuted : AppColors.ultraviolet,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: locked ? AppColors.textMuted : AppColors.cyan,
            ),
          ),
        ],
      ),
    );
  }

  (String, String, String, IconData, bool) _content() {
    if (board == _BoardKind.daily) {
      final locked = !controller.dailyBreachUnlocked;
      final score = controller.dailyBestScores[daily.occurrence];
      final previous = controller.dailyBestScores[daily.previousOccurrence];
      return (
        'TODAY // ${daily.definition.title.toUpperCase()}',
        locked
            ? 'Unlocks after Room 4.'
            : previous == null
            ? 'UTC ${daily.occurrence} · no previous daily record'
            : 'UTC ${daily.occurrence} · previous best $previous',
        locked ? 'LOCKED' : score?.toString() ?? '—',
        Icons.today_rounded,
        locked,
      );
    }
    if (board == _BoardKind.campaign) {
      final score = controller.campaignScore;
      return (
        'WITNESS PROTOCOL CAMPAIGN',
        score == null
            ? '${controller.completedLevels}/${helix9Rooms.length} rooms complete · current total ${controller.totalEffectiveStrokes}'
            : 'All twelve rooms complete',
        score?.toString() ?? '—',
        Icons.account_tree_rounded,
        false,
      );
    }
    final chapter = board.chapter!;
    final rooms = helix9Rooms.where((room) => room.chapter == chapter).toList();
    final score = controller.chapterScore(chapter);
    final completed = rooms
        .where((room) => controller.bestRuns.containsKey(room.level.number))
        .length;
    return (
      'ACT $chapter // ${rooms.first.chapterTitle.toUpperCase()}',
      score == null ? '$completed/4 rooms complete' : 'Four-room act complete',
      score?.toString() ?? '—',
      Icons.layers_rounded,
      false,
    );
  }
}

class _RemoteLeaderboardHeader extends StatelessWidget {
  const _RemoteLeaderboardHeader({
    required this.state,
    required this.scope,
    required this.board,
    required this.onRetry,
    required this.onOpen,
  });

  final _RemoteState state;
  final _BoardScope scope;
  final _BoardKind board;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, canRetry) = switch (state) {
      _RemoteState.idle || _RemoteState.loading => (
        Icons.sync_rounded,
        'CONTACTING GAME CENTER',
        'Requesting ${scope == _BoardScope.friends ? 'friend' : 'global'} ${board.label.toLowerCase()} scores.',
        false,
      ),
      _RemoteState.ready => (
        Icons.verified_rounded,
        'VERIFIED BY GAME CENTER',
        'Lowest stroke total ranks first.',
        false,
      ),
      _RemoteState.unavailable => (
        Icons.phone_iphone_rounded,
        'APPLE GAME CENTER UNAVAILABLE',
        'This device cannot access Game Center. Local records still work offline.',
        false,
      ),
      _RemoteState.signInRequired => (
        Icons.person_off_rounded,
        'SIGN-IN NOT AVAILABLE',
        'Check your Game Center account and connection, then try again. Local progress is safe.',
        true,
      ),
      _RemoteState.failed => (
        Icons.cloud_off_rounded,
        'SCORES COULD NOT LOAD',
        'Game Center may be offline. Nothing was removed; try again when the bureaucracy recovers.',
        true,
      ),
    };
    return GlassPanel(
      borderColor: state == _RemoteState.ready
          ? AppColors.cyan
          : AppColors.textMuted,
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canRetry)
            IconButton(
              tooltip: 'Retry Game Center',
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
            )
          else if (state == _RemoteState.ready)
            IconButton(
              tooltip: 'Open Game Center',
              onPressed: () => unawaited(onOpen()),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
    );
  }
}

class _RelationshipMeter extends StatelessWidget {
  const _RelationshipMeter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: value / 100,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardStat extends StatelessWidget {
  const _BoardStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});
  final _Achievement achievement;
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderColor: achievement.unlocked ? achievement.color : null,
      child: Opacity(
        opacity: achievement.unlocked ? 1 : .35,
        child: Row(
          children: [
            Icon(achievement.icon, color: achievement.color, size: 25),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 10),
                  ),
                  Text(
                    achievement.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_Rank _rankFor(int stars, int maxStars) {
  final progress = maxStars == 0 ? 0.0 : stars / maxStars;
  if (progress >= .8) {
    return const _Rank(
      'GHOST PROTOCOL',
      'NOX denies you exist. That is a compliment.',
      AppColors.cyan,
    );
  }
  if (progress >= .6) {
    return const _Rank(
      'MASTER THIEF',
      'Annoyingly competent. Heavy emphasis on annoying.',
      AppColors.success,
    );
  }
  if (progress >= .35) {
    return const _Rank(
      'CIPHER',
      'You are becoming a statistically significant problem.',
      AppColors.ultraviolet,
    );
  }
  if (progress >= .12) {
    return const _Rank(
      'INSIDER',
      'You know where the doors are. Cute.',
      Color(0xFFFFB84D),
    );
  }
  return const _Rank(
    'INTERN',
    'Unpaid, untrusted, and somehow already in the vault.',
    AppColors.textMuted,
  );
}

List<_Achievement> _achievements(GameController controller) {
  final underPar = controller.bestScores.entries.any((entry) {
    final room = helix9Rooms.firstWhere(
      (candidate) => candidate.level.number == entry.key,
    );
    return entry.value < room.level.par;
  });
  final perfect = controller.bestRuns.entries.any((entry) {
    final room = helix9Rooms.firstWhere(
      (candidate) => candidate.level.number == entry.key,
    );
    return entry.value.starsFor(room.level.par) == 3;
  });
  final routeArchitect = helix9Rooms.any(
    (room) =>
        controller.routesDiscoveredFor(room).length ==
        room.solutionRoutes.length,
  );
  return [
    _Achievement(
      'FIRST BREACH',
      'Open one room',
      Icons.lock_open_rounded,
      AppColors.ultraviolet,
      controller.completedLevels >= 1,
    ),
    _Achievement(
      'CLEAN GETAWAY',
      'Earn three stars',
      Icons.auto_awesome_rounded,
      AppColors.cyan,
      perfect,
    ),
    _Achievement(
      'SHOW-OFF',
      'Finish under par',
      Icons.bolt_rounded,
      AppColors.success,
      underPar,
    ),
    _Achievement(
      'WITNESS',
      'Complete all twelve rooms',
      Icons.all_inclusive_rounded,
      const Color(0xFFFFB84D),
      controller.completedLevels == helix9Rooms.length,
    ),
    _Achievement(
      'ROUTE ARCHITECT',
      'Discover every route in one room',
      Icons.account_tree_rounded,
      AppColors.danger,
      routeArchitect,
    ),
  ];
}

class _Rank {
  const _Rank(this.name, this.taunt, this.color);
  final String name;
  final String taunt;
  final Color color;
}

class _Achievement {
  const _Achievement(
    this.name,
    this.detail,
    this.icon,
    this.color,
    this.unlocked,
  );
  final String name;
  final String detail;
  final IconData icon;
  final Color color;
  final bool unlocked;
}
