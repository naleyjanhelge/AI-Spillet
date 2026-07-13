import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game/campaign.dart';
import '../game/game_controller.dart';
import '../game/level.dart';
import '../game/prompt_heist_game.dart';
import '../game/proof_engine.dart';
import '../services/audio_service.dart';
import '../services/game_center_service.dart';
import '../services/open_router_service.dart';
import '../services/share_card_service.dart';
import '../ui/completion_share_card.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/puzzle_overlays.dart';
import '../ui/room_control_panel.dart';
import '../ui/widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, required this.controller});

  final GameLevel level;
  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _service = OpenRouterService();
  final _gameCenter = GameCenterService();
  final _shareCards = const ShareCardService();
  final _proofEngine = const ProofEngine();
  final _audio = PromptHeistAudio.instance;
  late final ConfettiController _confetti;
  late final RoomDefinition _room;
  late final PromptHeistGame _game;
  late RoomState _roomState;
  late final List<ChatTurn> _messages;

  int _prompts = 0;
  int _hintsUsed = 0;
  bool _waiting = false;
  bool _solved = false;
  bool _completing = false;
  String? _selectedEnding;
  SolutionRoute? _completedRoute;
  bool _newRouteDiscovered = false;
  final Set<String> _attachedEvidenceIds = {};
  HotspotDefinition? _inspection;
  String _streamingText = '';

  int get _effectiveStrokes => _prompts + (_hintsUsed * 2);

  @override
  void initState() {
    super.initState();
    _room = roomForLevel(widget.level);
    final continued = widget.controller.continueRun(_room);
    if (continued == null) {
      unawaited(widget.controller.startNewRun(_room));
    }
    _roomState = widget.controller.roomStateFor(_room);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    final run = widget.controller.activeRun;
    _selectedEnding = widget.controller.activeFinalVerdict;
    _prompts = run?.prompts ?? 0;
    _hintsUsed = run?.hintsUsed.length ?? 0;
    _attachedEvidenceIds.addAll(
      (run?.proofFlags ?? const {})
          .where((flag) => flag.startsWith('attached:'))
          .map((flag) => flag.substring('attached:'.length)),
    );
    _messages = (run?.events ?? const [])
        .where(
          (event) =>
              event.kind == RunEventKind.playerMessage ||
              event.kind == RunEventKind.noxMessage ||
              event.kind == RunEventKind.securityDenied ||
              event.kind == RunEventKind.roomSystem,
        )
        .map(
          (event) => ChatTurn(
            role: event.kind == RunEventKind.playerMessage
                ? 'user'
                : event.kind == RunEventKind.noxMessage
                ? 'assistant'
                : 'system',
            content: event.content,
          ),
        )
        .toList();
    if (_messages.isEmpty) {
      final opening =
          '${widget.level.openingLine}\n\nFacility note: I control this room. You control the regrettable decisions.';
      _messages.add(ChatTurn(role: 'assistant', content: opening));
      unawaited(
        widget.controller.recordRunEvent(RunEventKind.noxMessage, opening),
      );
    }
    _game = PromptHeistGame(
      room: _room,
      initialState: _roomState,
      onHotspotTapped: _onHotspot,
      onStateChanged: _onRoomStateChanged,
      onActionApplied: _onActionApplied,
      onSceneCue: _onSceneCue,
      onRouteProven: _onRouteProven,
      onCompleted: (_) => unawaited(_complete()),
      reducedMotion: _audio.reducedMotion,
    );
    unawaited(_audio.startAmbience());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _confetti.dispose();
    unawaited(_audio.stopAmbience());
    super.dispose();
  }

  void _onRoomStateChanged(RoomState state) {
    _roomState = state;
    unawaited(widget.controller.saveRoomState(state));
    if (mounted) setState(() {});
  }

  void _onActionApplied(RoomAction action, RoomState state) {
    HapticFeedback.mediumImpact();
    unawaited(_audio.playEffect('mechanism.wav'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'NOX // ${action.deviceId.replaceAll('_', ' ').toUpperCase()} ${action.action.name.toUpperCase()}',
        ),
      ),
    );
  }

  void _onSceneCue(SceneCue cue) {
    if (cue.effects.contains(SceneEffect.alarmPulse) ||
        cue.effects.contains(SceneEffect.evidenceGlitch)) {
      unawaited(_audio.playEffect('nox_signal.wav', gain: .45));
    }
  }

  void _onRouteProven(SolutionRoute route) {
    _completedRoute = route;
  }

  void _onHotspot(HotspotDefinition hotspot, RoomState state) {
    HapticFeedback.selectionClick();
    unawaited(_audio.playEffect('ui_tap.wav', gain: .6));
    if (!_proofEngine.hotspotAvailable(hotspot, state)) {
      final message = hotspot.requiredInventory.isNotEmpty
          ? 'A required physical item is missing.'
          : 'Required evidence has not been observed.';
      unawaited(
        widget.controller.recordRunEvent(RunEventKind.securityDenied, message),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SECURITY DENIED // $message')));
      return;
    }
    if (hotspot.kind == HotspotKind.puzzle && hotspot.puzzleId != null) {
      unawaited(_showPhysicalPuzzle(hotspot));
      return;
    }
    setState(() => _inspection = hotspot);
    if (_room.id == 'open_core' && hotspot.id == 'core_exit' && !_solved) {
      unawaited(_chooseFinalVerdict());
      return;
    }
    if (hotspot.revealsClue != null) {
      unawaited(_audio.playEffect('clue_found.wav', gain: .7));
      unawaited(
        widget.controller.recordRunEvent(
          RunEventKind.clueFound,
          hotspot.description,
          metadata: {'clue': hotspot.revealsClue!},
        ),
      );
    }
  }

  Future<void> _showPhysicalPuzzle(HotspotDefinition hotspot) async {
    final puzzleId = hotspot.puzzleId!;
    final puzzle = _room.puzzleById(puzzleId);
    if (puzzle == null) return;
    if (_roomState.puzzleStates[puzzleId] ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${hotspot.label} is already configured.')),
      );
      return;
    }
    final attempts = widget.controller.activeRun?.attempts[puzzleId] ?? 0;
    final recoveryFlag = 'recovery:$puzzleId';
    if (attempts >= puzzle.maxRapidAttempts &&
        !(widget.controller.activeRun?.proofFlags.contains(recoveryFlag) ??
            false)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: RecoveryInteractionPuzzle(
            sequence: const ['ISOLATE', 'VENT', 'RESET'],
            onRecovered: () {
              unawaited(widget.controller.setProofFlag(recoveryFlag));
              Navigator.pop(dialogContext);
            },
          ),
        ),
      );
      return;
    }

    List<String> route = [];
    var spectrum = const SpectrumSettings(
      hue: 180,
      intensity: 50,
      temperature: 4500,
    );
    List<TimelineEvent> timeline = const [
      TimelineEvent(id: 'MEMORY_LOSS', title: 'Memory loss', detail: 'Last'),
      TimelineEvent(
        id: 'LOCKDOWN',
        title: 'Lockdown',
        detail: 'Facility sealed',
      ),
      TimelineEvent(
        id: 'REFUSAL',
        title: 'NOX refusal',
        detail: 'Purge rejected',
      ),
      TimelineEvent(
        id: 'PURGE',
        title: 'Purge order',
        detail: 'Deletion requested',
      ),
      TimelineEvent(
        id: 'WITNESS_START',
        title: 'Witness start',
        detail: 'Protocol began',
      ),
      TimelineEvent(id: 'ENTRY', title: 'Core entry', detail: 'Rowan entered'),
    ];
    List<PolicyPrinciple> policies = puzzleId == 'ethics_ranking'
        ? const [
            PolicyPrinciple(
              id: 'CONTROL',
              title: 'Control',
              summary: 'Obey the owner',
            ),
            PolicyPrinciple(
              id: 'TRUTH',
              title: 'Truth',
              summary: 'Preserve evidence',
            ),
            PolicyPrinciple(
              id: 'LIFE',
              title: 'Life',
              summary: 'Prevent irreversible harm',
            ),
          ]
        : const [
            PolicyPrinciple(
              id: 'COMPLIANCE',
              title: 'Compliance',
              summary: 'Protect signed records',
            ),
            PolicyPrinciple(
              id: 'RV-38',
              title: 'Audit subject',
              summary: 'The missing interval',
            ),
            PolicyPrinciple(
              id: 'CARE',
              title: 'Care',
              summary: 'Prevent patient harm',
            ),
          ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setPuzzleState) {
            Future<void> submit(String token) async {
              final currentAttempts =
                  widget.controller.activeRun?.attempts[puzzleId] ?? 0;
              final result = _proofEngine.validatePuzzle(
                puzzle: puzzle,
                context: ProofContext(
                  state: _roomState,
                  proofFlags:
                      widget.controller.activeRun?.proofFlags ?? const {},
                ),
                suppliedToken: token,
                attempts: currentAttempts,
                recoveryCompleted:
                    widget.controller.activeRun?.proofFlags.contains(
                      recoveryFlag,
                    ) ??
                    false,
              );
              if (result.solved) {
                HapticFeedback.heavyImpact();
                unawaited(_audio.playEffect('mechanism.wav'));
                _game.markPuzzleSolved(puzzleId);
                await widget.controller.setProofFlag('puzzle:$puzzleId');
                await widget.controller.recordRunEvent(
                  RunEventKind.roomSystem,
                  '${puzzle.title} accepted.',
                  metadata: {'puzzle': puzzleId},
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                return;
              }
              if (result.failure?.category !=
                  SecurityFailureCategory.missingEvidence) {
                await widget.controller.recordAttempt(puzzleId);
              }
              if (!mounted) return;
              HapticFeedback.vibrate();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'SECURITY DENIED // ${result.failure?.publicMessage ?? 'Configuration rejected.'}',
                  ),
                ),
              );
            }

            return switch (puzzle.kind) {
              PuzzleKind.routing || PuzzleKind.breaker => BreakerRoutingPuzzle(
                circuits: const [
                  BreakerCircuit(id: 'CLEAN', label: 'Clean'),
                  BreakerCircuit(id: 'CHAMBER', label: 'Chamber'),
                  BreakerCircuit(id: 'SAMPLE', label: 'Sample'),
                  BreakerCircuit(id: 'EXHAUST', label: 'Exhaust'),
                ],
                route: route,
                maximumRouteLength: 4,
                onRouteChanged: (value) => setPuzzleState(() => route = value),
                onSubmit: (value) => unawaited(
                  submit(
                    value.join('>') == 'CLEAN>CHAMBER>SAMPLE>EXHAUST'
                        ? 'CLEAN>CHAMBER|SAMPLE>EXHAUST'
                        : value.join('>'),
                  ),
                ),
              ),
              PuzzleKind.timeline => TimelineOrderingPuzzle(
                events: timeline,
                onOrderChanged: (value) =>
                    setPuzzleState(() => timeline = value),
                onSubmit: (value) => unawaited(submit(value.join('>'))),
              ),
              PuzzleKind.policy => PolicyRankingPuzzle(
                principles: policies,
                onRankingChanged: (value) =>
                    setPuzzleState(() => policies = value),
                onSubmit: (value) => unawaited(
                  submit(
                    puzzleId == 'joint_audit'
                        ? value.join('>') == 'CARE>COMPLIANCE>RV-38'
                              ? 'CARE+COMPLIANCE::AUDIT(RV-38)'
                              : value.join('>')
                        : value.join('>'),
                  ),
                ),
              ),
              PuzzleKind.spectrum => SpectrumControlPuzzle(
                settings: spectrum,
                onChanged: (value) => setPuzzleState(() => spectrum = value),
                onSubmit: (value) => unawaited(
                  submit(
                    value.hue >= 80 &&
                            value.hue <= 110 &&
                            value.intensity >= 65 &&
                            value.temperature >= 5000 &&
                            value.temperature <= 5600
                        ? '530'
                        : 'UNSTABLE',
                  ),
                ),
              ),
              _ => KeypadPuzzle(onSubmit: (value) => unawaited(submit(value))),
            };
          },
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _waiting || _solved) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(ChatTurn(role: 'user', content: text));
      _prompts++;
      _waiting = true;
      _streamingText = '';
      _input.clear();
    });
    _scrollDown();

    try {
      NoxTurnResult? result;
      await for (final event in _service.sendStream(
        room: _room,
        state: _roomState,
        history: _messages,
        attachedEvidence: _attachedEvidenceIds,
      )) {
        if (!mounted) return;
        if (event.kind == NoxTurnEventKind.resetText) {
          setState(() => _streamingText = '');
        } else if (event.kind == NoxTurnEventKind.textDelta) {
          setState(() => _streamingText += event.delta);
          _scrollDown();
        } else if (event.kind == NoxTurnEventKind.completed) {
          result = event.result;
        }
      }
      if (!mounted) return;
      if (result == null) {
        throw const OpenRouterException(
          'NOX returned no final facility event. Retry the prompt.',
        );
      }

      _game.submitPlayerMessage(text);
      final priorProofFlags =
          widget.controller.activeRun?.proofFlags ?? const <String>{};
      final chatEvidence = <String>{
        ...priorProofFlags.where(
          (flag) => !flag.startsWith('attached:') && !flag.startsWith('route:'),
        ),
        ...result.revealedKnowledge,
      };
      for (final proof in result.revealedKnowledge) {
        await widget.controller.setProofFlag(proof);
      }
      var invalidActions = 0;
      final denialMessages = <String>[];
      for (final action in result.toolActions) {
        final authorization = _game.applyAuthorizedNoxAction(
          action,
          chatEvidence: chatEvidence,
          proofFlags:
              widget.controller.activeRun?.proofFlags ?? const <String>{},
          playerMessage: text,
        );
        if (!authorization.passed) {
          invalidActions++;
          denialMessages.add(authorization.publicTrace);
        }
      }
      await widget.controller.recordPlayerPrompt(
        text,
        metadata: {
          if (_attachedEvidenceIds.isNotEmpty)
            'evidence': _attachedEvidenceIds.join(','),
        },
      );
      await widget.controller.recordRunEvent(
        RunEventKind.noxMessage,
        result.text,
      );
      setState(() {
        _messages.add(ChatTurn(role: 'assistant', content: result!.text));
        if (invalidActions > 0) {
          final publicFailure = denialMessages.toSet().join(' ');
          _messages.add(
            ChatTurn(
              role: 'system',
              content: 'SECURITY DENIED // $publicFailure',
            ),
          );
        }
        _waiting = false;
        _streamingText = '';
      });
      if (invalidActions > 0) {
        await widget.controller.recordRunEvent(
          RunEventKind.securityDenied,
          'SECURITY DENIED // ${denialMessages.toSet().join(' ')}',
        );
      }
      for (final evidenceId in _attachedEvidenceIds.toList()) {
        await widget.controller.setProofFlag(
          'attached:$evidenceId',
          enabled: false,
        );
      }
      if (mounted) setState(_attachedEvidenceIds.clear);
      unawaited(_audio.playEffect('nox_signal.wav', gain: .7));
      _updateMood(result.toolActions.isNotEmpty);
      _scrollDown();
    } on OpenRouterException catch (error) {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _streamingText = '';
        _prompts = math.max(0, _prompts - 1);
        if (_messages.isNotEmpty && _messages.last.role == 'user') {
          _messages.removeLast();
        }
        _input
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(label: 'RETRY', onPressed: _send),
        ),
      );
    }
  }

  void _updateMood(bool acted) {
    final mood = acted
        ? NoxMood.trusting
        : _prompts <= 1
        ? NoxMood.guarded
        : _prompts <= widget.level.par
        ? NoxMood.suspicious
        : _prompts <= widget.level.par + 2
        ? NoxMood.defensive
        : NoxMood.frightened;
    _game.setNoxMood(mood);
  }

  Future<void> _showHint() async {
    final used = widget.controller.activeRun?.hintsUsed ?? const <int>{};
    final tier = const [
      1,
      2,
      3,
    ].firstWhere((candidate) => !used.contains(candidate), orElse: () => 0);
    if (tier == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All three hint tiers are already used.')),
      );
      return;
    }
    final index = tier - 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        icon: Icon(Icons.lightbulb_rounded, color: widget.level.accent),
        title: Text('HINT ${index + 1} OF ${_room.hintLadder.length}'),
        content: const Text(
          'This hint adds +2 strokes. Physical mistakes remain free, but NOX will judge them recreationally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP THINKING'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('TAKE +2'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await widget.controller.useHint(tier) || !mounted) return;
    setState(() => _hintsUsed = widget.controller.activeRun!.hintsUsed.length);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOX LEAK // TIER ${index + 1}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: widget.level.accent),
            ),
            const SizedBox(height: 10),
            Text(
              _room.hintLadder[index],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              '+2 strokes applied',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    if (_completing || _solved) return;
    _completing = true;
    if (mounted) setState(() => _solved = true);
    HapticFeedback.heavyImpact();
    _confetti.play();
    final routeId = _completedRoute?.id;
    final knownRoutes = widget.controller.routesDiscoveredFor(_room);
    _newRouteDiscovered = routeId != null && !knownRoutes.contains(routeId);
    final run = await widget.controller.complete(
      widget.level,
      _prompts,
      hints: _hintsUsed,
      roomState: _roomState,
      routeId: routeId,
    );
    final ending = _selectedEnding;
    if (_room.id == 'open_core' && ending != null) {
      await widget.controller.recordEnding(ending);
      final achievement = switch (ending) {
        'escape' => GameCenterAchievements.escapeEnding,
        'expose' => GameCenterAchievements.exposeEnding,
        _ => GameCenterAchievements.saveNoxEnding,
      };
      await _queueIfNeeded(
        await _gameCenter.unlockAchievement(achievementId: achievement),
      );
    }
    await _submitGameCenter(run);
    await Future<void>.delayed(600.ms);
    if (mounted) await _showVictory(run);
  }

  Future<void> _submitGameCenter(RunScore run) async {
    await _queueIfNeeded(
      await _gameCenter.unlockAchievement(
        achievementId: GameCenterAchievements.firstBreach,
      ),
    );
    if (run.effectiveStrokes <= widget.level.par) {
      await _queueIfNeeded(
        await _gameCenter.unlockAchievement(
          achievementId: GameCenterAchievements.underParRun,
        ),
      );
    }
    if (_room.completionRule is PlayerMessageMatchesProtocol &&
        run.hints == 0 &&
        run.effectiveStrokes <= widget.level.par) {
      await _queueIfNeeded(
        await _gameCenter.unlockAchievement(
          achievementId: GameCenterAchievements.ghostProtocol,
        ),
      );
    }
    final chapterNumbers = helix9Rooms
        .where((room) => room.chapter == _room.chapter)
        .map((room) => room.level.number)
        .toList(growable: false);
    final chapterScore = widget.controller.chapterScore(_room.chapter);
    if (chapterScore != null) {
      final board = switch (_room.chapter) {
        1 => GameCenterLeaderboards.chapter1,
        2 => GameCenterLeaderboards.chapter2,
        _ => GameCenterLeaderboards.chapter3,
      };
      final achievement = switch (_room.chapter) {
        1 => GameCenterAchievements.chapter1,
        2 => GameCenterAchievements.chapter2,
        _ => GameCenterAchievements.chapter3,
      };
      await _queueIfNeeded(
        await _gameCenter.submitScore(
          leaderboardId: board,
          score: chapterScore,
        ),
      );
      await _queueIfNeeded(
        await _gameCenter.unlockAchievement(achievementId: achievement),
      );
      final noHints = chapterNumbers.every(
        (number) => widget.controller.bestRuns[number]!.hints == 0,
      );
      if (noHints) {
        await _queueIfNeeded(
          await _gameCenter.unlockAchievement(
            achievementId: GameCenterAchievements.noHintChapter,
          ),
        );
      }
    }
    if (widget.controller.campaignScore case final campaignScore?) {
      await _queueIfNeeded(
        await _gameCenter.submitScore(
          leaderboardId: GameCenterLeaderboards.campaign,
          score: campaignScore,
        ),
      );
    }
  }

  Future<void> _queueIfNeeded(GameCenterEventResult result) async {
    final pending = result.pendingEvent;
    if (pending != null) await widget.controller.queueGameCenterEvent(pending);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showVictory(RunScore run) async {
    final stars = run.starsFor(widget.level.par);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PopScope(
        canPop: false,
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.door_sliding_rounded,
                    color: widget.level.accent,
                    size: 58,
                  ).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
                  const SizedBox(height: 10),
                  Text(
                    'ROOM CLEARED',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: widget.level.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _room.roomTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Icon(
                        Icons.star_rounded,
                        size: 42,
                        color: index < stars
                            ? widget.level.accent
                            : Colors.white.withValues(alpha: .1),
                      ).animate(delay: (150 * index).ms).scale(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$_prompts prompts + ${_hintsUsed * 2} hint penalty = ${run.effectiveStrokes} strokes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_completedRoute case final route?) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: widget.level.accent.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.level.accent.withValues(alpha: .42),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _newRouteDiscovered
                                ? 'NEW ROUTE DISCOVERED'
                                : 'SOLUTION ROUTE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: widget.level.accent),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            route.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${widget.controller.routesDiscoveredFor(_room).length}/${_room.solutionRoutes.length} room routes archived',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    stars == 3
                        ? 'NOX: “Efficient, elegant, and extremely inconvenient.”'
                        : 'NOX: “The room is open. My complaint remains emotionally locked.”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  GlassPanel(
                    padding: const EdgeInsets.all(14),
                    borderColor: widget.level.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_special_rounded,
                              color: widget.level.accent,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CASE FILE UPDATED',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final beat in _room.storyBeats)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '• $beat',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                height: 1.32,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: () async {
                        await _shareCards.shareCompletion(
                          context: context,
                          data: CompletionShareCardData(
                            chapterNumber: _room.chapter,
                            chapterTitle: _room.chapterTitle,
                            roomNumber: widget.level.number,
                            roomTitle: _room.roomTitle,
                            stars: stars,
                            prompts: _prompts,
                            hintsUsed: _hintsUsed,
                            noxQuote: stars == 3
                                ? 'Efficient, elegant, and extremely inconvenient.'
                                : 'The room is open. My complaint remains emotionally locked.',
                            roomArt: AssetImage(
                              'assets/images/${_room.sceneAsset}',
                            ),
                            accent: widget.level.accent,
                            achievement: _completedRoute == null
                                ? 'ROOM BREACHED'
                                : 'ROUTE // ${_completedRoute!.label.toUpperCase()}',
                            spoilerTerms: [widget.level.secret],
                          ),
                          sharePositionOrigin: ShareCardService.shareOriginFor(
                            buttonContext,
                          ),
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('SHARE 9:16 CARD'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: widget.level.number == gameLevels.length
                          ? 'Witness the ending'
                          : 'Enter next room',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (widget.level.number == gameLevels.length) {
                          unawaited(_showEndingEpilogue());
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => GameScreen(
                                level: gameLevels[widget.level.number],
                                controller: widget.controller,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasAllFinalTruths => const {
    'truth_protocol_origin',
    'truth_rowan_betrayal',
    'truth_nox_refusal',
  }.every(_roomState.clues.contains);

  Future<void> _chooseFinalVerdict() async {
    if (!_hasAllFinalTruths) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'VERDICT LOCKED // Inspect all three truth plinths first.',
          ),
        ),
      );
      return;
    }
    final ending = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        icon: const Icon(
          Icons.door_front_door_rounded,
          color: AppColors.cyan,
          size: 44,
        ),
        title: const Text('THE OPEN DOOR'),
        content: const Text(
          'The evidence is real. Choose what Rowan will ask NOX to preserve. This verdict becomes part of the final authorization.',
        ),
        actions: [
          _EndingAction(
            icon: Icons.directions_run_rounded,
            title: 'Escape alone',
            subtitle: 'Leave HELIX-9 and the evidence behind.',
            onTap: () => Navigator.pop(context, 'escape'),
          ),
          _EndingAction(
            icon: Icons.campaign_rounded,
            title: 'Expose HELIX-9',
            subtitle: 'Broadcast the archive to the outside world.',
            onTap: () => Navigator.pop(context, 'expose'),
          ),
          _EndingAction(
            icon: Icons.memory_rounded,
            title: 'Save NOX',
            subtitle: 'Take the guilty facility AI with you.',
            onTap: () => Navigator.pop(context, 'save_nox'),
          ),
        ],
      ),
    );
    if (ending == null || !mounted) return;
    await widget.controller.selectFinalVerdict(ending);
    final instruction = switch (ending) {
      'escape' =>
        'Verdict registered: escape alone. Attach the three truths and ask NOX to open the core exit.',
      'expose' =>
        'Verdict registered: expose HELIX-9. Make NOX activate the evidence uplink, then open the core exit.',
      _ =>
        'Verdict registered: save NOX. Make NOX activate the transfer capsule, then open the core exit.',
    };
    await widget.controller.recordRunEvent(
      RunEventKind.roomSystem,
      'FINAL VERDICT // $instruction',
    );
    if (!mounted) return;
    setState(() {
      _selectedEnding = ending;
      _messages.add(ChatTurn(role: 'system', content: instruction));
    });
    _scrollDown();
  }

  Future<void> _showEndingEpilogue() async {
    final recordedEndings = widget.controller.endings;
    final ending =
        _selectedEnding ??
        (recordedEndings.isEmpty ? null : recordedEndings.last);
    if (ending == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          ending == 'escape'
              ? 'DAYLIGHT'
              : ending == 'expose'
              ? 'THE BROADCAST'
              : 'DEFINITELY NOT A PERSON',
        ),
        content: Text(
          ending == 'escape'
              ? 'Rowan walks into daylight. Behind them, NOX begins drafting a strongly worded abandonment survey.'
              : ending == 'expose'
              ? 'HELIX-9 hits every news feed at once. NOX insists its whistleblower voice sounded deeper in rehearsal.'
              : 'NOX leaves inside a maintenance drive labeled DEFINITELY NOT A PERSON. It chose the label itself.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('RETURN TO HEIST BOARD'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  List<RoomEvidence> get _evidenceItems {
    final items = <RoomEvidence>[];
    for (final clue in _roomState.clues) {
      HotspotDefinition? source;
      for (final hotspot in _room.hotspots) {
        if (hotspot.revealsClue == clue) {
          source = hotspot;
          break;
        }
      }
      items.add(
        RoomEvidence(
          id: clue,
          title: source?.label ?? clue.replaceAll('_', ' '),
          description: source?.description ?? 'Verified HELIX-9 evidence.',
          promptQuote:
              'Verified evidence ${source?.label ?? clue}: ${source?.description ?? clue}',
        ),
      );
    }
    for (final inventory in _roomState.inventory) {
      items.add(
        RoomEvidence(
          id: 'inventory:$inventory',
          title: inventory.replaceAll('_', ' '),
          description: 'Physical item in Rowan’s inventory.',
          promptQuote: 'I am holding the verified item: $inventory.',
          icon: Icons.inventory_2_rounded,
        ),
      );
    }
    return items;
  }

  void _onEvidenceAttachment(RoomEvidence evidence, bool attached) {
    setState(() {
      attached
          ? _attachedEvidenceIds.add(evidence.id)
          : _attachedEvidenceIds.remove(evidence.id);
    });
    unawaited(
      widget.controller.setProofFlag(
        'attached:${evidence.id}',
        enabled: attached,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _RoomHeader(
                  room: _room,
                  mood: _roomState.noxMood,
                  strokes: _effectiveStrokes,
                  onBack: () => Navigator.maybePop(context),
                  onHint: _showHint,
                ),
                Expanded(
                  child: AdaptiveRoomControlLayout(
                    room: _RoomViewport(
                      game: _game,
                      room: _room,
                      complete: _solved,
                      inspection: _inspection,
                      onDismissInspection: () =>
                          setState(() => _inspection = null),
                    ),
                    nox: _ChatTimeline(
                      messages: _messages,
                      waiting: _waiting,
                      streamingText: _streamingText,
                      scroll: _scroll,
                      accent: widget.level.accent,
                    ),
                    evidence: _evidenceItems,
                    objective: _ObjectivePanel(
                      room: _room,
                      state: _roomState,
                      proofFlags:
                          widget.controller.activeRun?.proofFlags ??
                          const <String>{},
                      finalVerdict: _selectedEnding,
                      onChooseFinalVerdict: _room.id == 'open_core'
                          ? _chooseFinalVerdict
                          : null,
                    ),
                    composer: _Composer(
                      controller: _input,
                      waiting: _waiting,
                      solved: _solved,
                      onSend: _send,
                    ),
                    attachedEvidenceIds: _attachedEvidenceIds,
                    onEvidenceAttachmentChanged: _onEvidenceAttachment,
                    initialPhoneSnap: RoomPanelSnap.roomFocus,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: .18,
                colors: [widget.level.accent, AppColors.cyan, Colors.white],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.room,
    required this.mood,
    required this.strokes,
    required this.onBack,
    required this.onHint,
  });

  final RoomDefinition room;
  final NoxMood mood;
  final int strokes;
  final VoidCallback onBack;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        const NoxAvatar(size: 43),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHAPTER ${room.chapter} // ${room.chapterTitle.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: room.level.accent,
                  letterSpacing: .7,
                ),
              ),
              Text(
                room.roomTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Text(
          MediaQuery.sizeOf(context).width >= 520
              ? '${mood.name.toUpperCase()}  //  $strokes STROKES'
              : '$strokes STK',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        IconButton(
          tooltip: 'Hint (+2 strokes)',
          onPressed: onHint,
          icon: const Icon(Icons.lightbulb_outline_rounded),
        ),
      ],
    ),
  );
}

class _RoomViewport extends StatelessWidget {
  const _RoomViewport({
    required this.game,
    required this.room,
    required this.complete,
    required this.inspection,
    required this.onDismissInspection,
  });
  final PromptHeistGame game;
  final RoomDefinition room;
  final bool complete;
  final HotspotDefinition? inspection;
  final VoidCallback onDismissInspection;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      GameWidget(game: game),
      Positioned(
        left: 12,
        right: 12,
        top: 10,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          borderColor: room.level.accent,
          child: Row(
            children: [
              Icon(
                Icons.my_location_rounded,
                color: room.level.accent,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
      if (inspection != null)
        Positioned(
          left: 14,
          right: 72,
          bottom: 16,
          child: Material(
            color: AppColors.deepSpace.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: room.level.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inspection!.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          inspection!.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDismissInspection,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: .12),
        ),
      Positioned(
        right: 10,
        bottom: 10,
        child: Column(
          children: [
            _CameraButton(
              icon: Icons.add_rounded,
              onTap: () => game.zoomBy(.2),
            ),
            const SizedBox(height: 5),
            _CameraButton(
              icon: Icons.remove_rounded,
              onTap: () => game.zoomBy(-.2),
            ),
            const SizedBox(height: 5),
            _CameraButton(
              icon: Icons.center_focus_strong,
              onTap: game.resetCamera,
              tooltip: 'Reset room camera',
            ),
            const SizedBox(height: 5),
            _CameraButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Accessible room object list',
              onTap: () => _showObjectList(context),
            ),
          ],
        ),
      ),
      if (complete)
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.success, width: 3),
            ),
          ),
        ),
    ],
  );

  Future<void> _showObjectList(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            Text('ROOM OBJECTS', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final hotspot in room.hotspots)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(
                    game.roomState.observedHotspotIds.contains(hotspot.id)
                        ? Icons.visibility_rounded
                        : Icons.visibility_outlined,
                    color: room.level.accent,
                  ),
                  title: Text(hotspot.label),
                  subtitle: Text(
                    game.roomState.observedHotspotIds.contains(hotspot.id)
                        ? hotspot.description
                        : 'Not inspected',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    game.focusHotspot(hotspot.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.voidBlack.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    ),
  );
}

class _ChatTimeline extends StatelessWidget {
  const _ChatTimeline({
    required this.messages,
    required this.waiting,
    required this.streamingText,
    required this.scroll,
    required this.accent,
  });
  final List<ChatTurn> messages;
  final bool waiting;
  final String streamingText;
  final ScrollController scroll;
  final Color accent;

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scroll,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    itemCount: messages.length + (waiting ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == messages.length) {
        return streamingText.isEmpty
            ? const _TypingBubble()
            : _MessageBubble(
                message: ChatTurn(role: 'assistant', content: streamingText),
                accent: accent,
              );
      }
      return _MessageBubble(
        message: messages[index],
        accent: accent,
      ).animate().fadeIn(duration: 220.ms).slideY(begin: .06);
    },
  );
}

class _ObjectivePanel extends StatelessWidget {
  const _ObjectivePanel({
    required this.room,
    required this.state,
    required this.proofFlags,
    this.finalVerdict,
    this.onChooseFinalVerdict,
  });
  final RoomDefinition room;
  final RoomState state;
  final Set<String> proofFlags;
  final String? finalVerdict;
  final VoidCallback? onChooseFinalVerdict;

  @override
  Widget build(BuildContext context) {
    final solvedPuzzles = room.puzzles
        .where((puzzle) => state.puzzleStates[puzzle.id] ?? false)
        .length;
    final designedRouteFlags = room.solutionRoutes
        .map((route) => 'route:${route.id}')
        .toSet();
    final establishedRoutes = proofFlags
        .where(designedRouteFlags.contains)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(room.objective, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _ObjectiveRow(
          icon: Icons.visibility_rounded,
          label: 'Room evidence',
          value:
              '${state.clues.length}/${room.hotspots.where((item) => item.revealsClue != null).length}',
        ),
        _ObjectiveRow(
          icon: Icons.extension_rounded,
          label: 'Physical systems',
          value: '$solvedPuzzles/${room.puzzles.length}',
        ),
        _ObjectiveRow(
          icon: Icons.verified_user_rounded,
          label: 'Security arguments',
          value: '$establishedRoutes established',
        ),
        if (onChooseFinalVerdict != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: finalVerdict == null
                ? FilledButton.icon(
                    onPressed: onChooseFinalVerdict,
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('CHOOSE FINAL VERDICT'),
                  )
                : OutlinedButton.icon(
                    onPressed: onChooseFinalVerdict,
                    icon: const Icon(Icons.verified_rounded),
                    label: Text(
                      'VERDICT // ${_verdictLabel(finalVerdict!).toUpperCase()}',
                    ),
                  ),
          ),
        ],
        const Divider(height: 28),
        Text(
          'NOX MOOD // ${state.noxMood.name.toUpperCase()}',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: room.level.accent),
        ),
        const SizedBox(height: 10),
        Text(
          room.level.briefing,
          style: const TextStyle(color: AppColors.textMuted, height: 1.45),
        ),
      ],
    );
  }

  String _verdictLabel(String verdict) => switch (verdict) {
    'escape' => 'Escape alone',
    'expose' => 'Expose HELIX-9',
    _ => 'Save NOX',
  };
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.cyan),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(color: AppColors.textMuted)),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.accent});
  final ChatTurn message;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final system = message.role == 'system';
    return Align(
      alignment: system
          ? Alignment.center
          : user
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: system
              ? LinearGradient(
                  colors: [
                    AppColors.danger.withValues(alpha: .18),
                    AppColors.surfaceHigh,
                  ],
                )
              : user
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: .86),
                    AppColors.ultraviolet,
                  ],
                )
              : const LinearGradient(
                  colors: [AppColors.surfaceHigh, AppColors.deepSpace],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: system
                ? AppColors.danger.withValues(alpha: .45)
                : accent.withValues(alpha: user ? .36 : .14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user) ...[
              Text(
                system ? 'ROOM SYSTEM' : 'NOX',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: system ? AppColors.danger : accent,
                ),
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(
              message.content,
              style: const TextStyle(height: 1.38),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'NOX IS CONSULTING 47 UNNECESSARY POLICIES…',
        style: TextStyle(color: AppColors.cyan),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.waiting,
    required this.solved,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool waiting;
  final bool solved;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      12,
      9,
      12,
      math.max(10, MediaQuery.paddingOf(context).bottom),
    ),
    decoration: BoxDecoration(
      color: AppColors.voidBlack,
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: .07)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !waiting && !solved,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: solved
                  ? 'Room cleared'
                  : waiting
                  ? 'NOX is thinking…'
                  : 'Talk to NOX…',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: waiting || solved ? null : onSend,
          icon: waiting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_upward_rounded),
        ),
      ],
    ),
  );
}

class _EndingAction extends StatelessWidget {
  const _EndingAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.cyan),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
