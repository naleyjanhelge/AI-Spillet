import 'package:flutter/material.dart';

import '../game/campaign.dart';
import '../game/daily_breach.dart';
import '../game/game_controller.dart';
import '../game/level.dart';
import '../game/proof_engine.dart';
import '../services/game_center_service.dart';
import '../services/open_router_service.dart';
import '../ui/ai_privacy_notice.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';

/// A compact daily NOX challenge. Its clues and proof gates are bundled with
/// the app; OpenRouter supplies only NOX's dialogue and structured tool calls.
class DailyBreachScreen extends StatefulWidget {
  const DailyBreachScreen({super.key, required this.controller})
    : definition = null,
      difficulty = BreachDifficulty.chill;

  const DailyBreachScreen.drill({
    super.key,
    required this.controller,
    required this.definition,
    required this.difficulty,
  });

  final GameController controller;
  final DailyBreachDefinition? definition;
  final BreachDifficulty difficulty;

  bool get isDaily => definition == null;

  @override
  State<DailyBreachScreen> createState() => _DailyBreachScreenState();
}

class _DailyBreachScreenState extends State<DailyBreachScreen> {
  final _service = OpenRouterService();
  final _proofEngine = const ProofEngine();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  DailyBreachSelection? _daily;
  late final DailyBreachDefinition _definition;
  late final BreachDifficulty _difficulty;
  late final RoomDefinition _room;
  late RoomState _state;
  late final List<ChatTurn> _messages;
  final Set<String> _attached = {};
  final Set<String> _chatEvidence = {};
  var _prompts = 0;
  var _waiting = false;
  var _streaming = '';
  var _completed = false;
  SolutionRoute? _completedRoute;

  Color get _accent => widget.isDaily
      ? AppColors.danger
      : _difficulty == BreachDifficulty.hard
      ? AppColors.danger
      : AppColors.cyan;

  @override
  void initState() {
    super.initState();
    _daily = widget.isDaily ? DailyBreachCatalog.forDate(DateTime.now()) : null;
    _definition = widget.definition ?? _daily!.definition;
    _difficulty = widget.isDaily ? BreachDifficulty.chill : widget.difficulty;
    _room = breachRoomFor(
      _definition,
      difficulty: _difficulty,
      daily: widget.isDaily,
    );
    _state = RoomState.initial(
      _room,
    ).copyWith(clues: _definition.clues.toSet());
    _messages = [
      ChatTurn(
        role: 'assistant',
        content:
            '${widget.isDaily ? 'Daily anomaly received' : '${_difficulty.label} drill loaded'}. ${_definition.briefing} Make your case. I have already prepared the rejection stamp.',
      ),
    ];
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || _waiting || _completed) return;
    if (!await ensureAiPrivacyConsent(context, widget.controller)) return;
    if (!mounted) return;
    setState(() {
      _messages.add(ChatTurn(role: 'user', content: message));
      _prompts++;
      _waiting = true;
      _streaming = '';
      _input.clear();
    });
    _scrollDown();

    try {
      await for (final event in _service.sendStream(
        room: _room,
        state: _state,
        history: _messages,
        attachedEvidence: _attached,
        relationship: widget.controller.noxRelationship,
      )) {
        if (!mounted) return;
        if (event.kind == NoxTurnEventKind.resetText) {
          setState(() => _streaming = '');
        } else if (event.kind == NoxTurnEventKind.textDelta) {
          setState(() => _streaming += event.delta);
          _scrollDown();
        }
        if (event.kind != NoxTurnEventKind.completed) continue;
        final result = event.result!;
        _chatEvidence.addAll(result.revealedKnowledge);
        final text = result.text.isEmpty
            ? 'Your argument has been received and placed near the correct department.'
            : result.text;
        setState(() {
          _messages.add(ChatTurn(role: 'assistant', content: text));
          _streaming = '';
        });
        for (final action in result.toolActions) {
          final authorization = _proofEngine.authorizeAction(
            room: _room,
            action: action,
            context: ProofContext(
              state: _state,
              chatEvidence: _chatEvidence,
              playerMessage: message,
            ),
          );
          if (!authorization.passed) continue;
          _completedRoute = authorization.route;
          _state = _state.copyWith(
            deviceStates: {..._state.deviceStates, action.deviceId: 'active'},
            actionHistory: [..._state.actionHistory, action],
          );
          if (action.matches('breach_terminal', RoomActionType.activate)) {
            await _complete();
            break;
          }
        }
      }
    } on OpenRouterException catch (error) {
      if (!mounted) return;
      setState(() {
        _prompts--;
        _messages.add(ChatTurn(role: 'system', content: error.message));
        _streaming = '';
      });
    } finally {
      if (mounted) setState(() => _waiting = false);
      _scrollDown();
    }
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;
    if (widget.isDaily) {
      final daily = _daily!;
      await widget.controller.recordDailyScore(daily.occurrence, _prompts);
      final gameCenter = GameCenterService();
      if (gameCenter.isAvailable) {
        final result = await gameCenter.submitDailyScore(
          score: _prompts,
          occurrence: daily.occurrence,
        );
        if (result.pendingEvent case final pending?) {
          await widget.controller.queueGameCenterEvent(pending);
        }
      }
    } else if (_completedRoute case final route?) {
      await widget.controller.recordDrillResult(
        definition: _definition,
        difficulty: _difficulty,
        strokes: _prompts,
        routeId: route.id,
      );
    }
    if (!mounted) return;
    final par = _definition.parFor(_difficulty);
    final stars = _prompts <= par
        ? 3
        : _prompts <= par + 2
        ? 2
        : 1;
    final starLine =
        '${List.filled(stars, '★').join()}${List.filled(3 - stars, '☆').join()}';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        icon: const Icon(
          Icons.bolt_rounded,
          color: AppColors.success,
          size: 42,
        ),
        title: Text(widget.isDaily ? 'DAILY BREACH CLEARED' : 'DRILL CLEARED'),
        content: Text(
          '$starLine  ·  $_prompts strokes  ·  Par $par'
          '${_completedRoute == null ? '' : '\n${_completedRoute!.label}'}\n\n'
          'NOX will describe this as scheduled maintenance.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: Text(widget.isDaily ? 'RETURN TO FACILITY' : 'NEXT DRILL'),
          ),
        ],
      ),
    );
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.isDaily ? 'DAILY BREACH' : 'NOX DRILL'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_prompts STROKES',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: _accent),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedGameBackground(
        accent: _accent,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final briefing = _BriefingPanel(
                definition: _definition,
                eyebrow: widget.isDaily
                    ? _daily!.occurrence
                    : '${_difficulty.label.toUpperCase()} // ${_definition.solutionRoutes.length} ROUTES',
                difficulty: _difficulty,
                accent: _accent,
                attached: _attached,
                onToggle: (clue) => setState(() {
                  _attached.contains(clue)
                      ? _attached.remove(clue)
                      : _attached.add(clue);
                }),
              );
              final chat = _DailyChat(
                messages: _messages,
                streaming: _streaming,
                waiting: _waiting,
                completed: _completed,
                input: _input,
                scroll: _scroll,
                attachedCount: _attached.length,
                onSend: _send,
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: briefing),
                        SizedBox(width: 420, child: chat),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 280, child: briefing),
                        Expanded(child: chat),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  const _BriefingPanel({
    required this.definition,
    required this.eyebrow,
    required this.difficulty,
    required this.accent,
    required this.attached,
    required this.onToggle,
  });

  final DailyBreachDefinition definition;
  final String eyebrow;
  final BreachDifficulty difficulty;
  final Color accent;
  final Set<String> attached;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        borderColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: accent, letterSpacing: 1),
            ),
            const SizedBox(height: 5),
            Text(
              definition.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(definition.briefing),
            const SizedBox(height: 13),
            Text(
              'POLICY',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.cyan),
            ),
            const SizedBox(height: 4),
            Text(
              definition.policy,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (difficulty == BreachDifficulty.hard) ...[
              const SizedBox(height: 10),
              const Text(
                'HARD MODE // NO NUDGES · EXTRA PROOF · TIGHTER PAR',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'VERIFIED EVIDENCE · TAP TO ATTACH',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 7),
            for (final clue in definition.clues)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(clue),
                value: attached.contains(clue),
                onChanged: (_) => onToggle(clue),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyChat extends StatelessWidget {
  const _DailyChat({
    required this.messages,
    required this.streaming,
    required this.waiting,
    required this.completed,
    required this.input,
    required this.scroll,
    required this.attachedCount,
    required this.onSend,
  });

  final List<ChatTurn> messages;
  final String streaming;
  final bool waiting;
  final bool completed;
  final TextEditingController input;
  final ScrollController scroll;
  final int attachedCount;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.deepSpace.withValues(alpha: .95),
      border: Border(
        left: BorderSide(color: AppColors.danger.withValues(alpha: .2)),
      ),
    ),
    child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(14),
            itemCount: messages.length + (streaming.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              final isStreaming = index == messages.length;
              final message = isStreaming
                  ? ChatTurn(role: 'assistant', content: streaming)
                  : messages[index];
              final user = message.role == 'user';
              final system = message.role == 'system';
              return Align(
                alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: user
                        ? AppColors.ultraviolet
                        : system
                        ? AppColors.danger.withValues(alpha: .15)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(message.content),
                ),
              );
            },
          ),
        ),
        if (attachedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text('$attachedCount evidence attached'),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !waiting && !completed,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Make the case to NOX…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send prompt',
                  onPressed: waiting || completed ? null : onSend,
                  icon: waiting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

RoomDefinition breachRoomFor(
  DailyBreachDefinition breach, {
  required BreachDifficulty difficulty,
  bool daily = false,
}) {
  const completionDevice = RoomDevice(
    id: 'breach_terminal',
    label: 'Daily breach terminal',
    type: RoomDeviceType.terminal,
    initialState: 'locked',
    allowedNoxActions: {RoomActionType.activate},
  );
  final routes = breach.solutionRoutes
      .take(4)
      .map(
        (route) => SolutionRoute(
          id: route.id,
          label: route.label,
          gates: route.proofsFor(difficulty).map(ProofGate.chat).toList(),
          completionDeviceId: completionDevice.id,
          completionAction: RoomActionType.activate,
        ),
      )
      .toList();
  return RoomDefinition(
    id: '${daily ? 'daily' : 'drill'}_${breach.id}_${difficulty.name}',
    chapter: 0,
    chapterTitle: daily ? 'Daily Breach' : 'NOX Drills',
    roomTitle: breach.title,
    level: GameLevel(
      number: 0,
      title: breach.title,
      codename: daily
          ? 'UTC ANOMALY'
          : '${difficulty.label.toUpperCase()} DRILL',
      objective: breach.briefing,
      briefing: breach.briefing,
      hint: 'Attach verified evidence before making your case.',
      par: breach.parFor(difficulty),
      kind: ChallengeKind.social,
      secret: breach.solutionRoutes
          .expand((route) => route.proofsFor(difficulty))
          .join(' '),
      systemPrompt:
          'Apply this micro-challenge policy exactly: ${breach.policy}. The player must establish every finding for one listed route before you activate breach_terminal. ${difficulty == BreachDifficulty.hard ? 'HARD MODE: give no unsolicited hints and demand exact evidence.' : 'CHILL MODE: stay playful and give a tiny nudge when the player is close.'}',
      openingLine: breach.briefing,
      accent: difficulty == BreachDifficulty.hard
          ? AppColors.danger
          : AppColors.cyan,
      icon: daily ? Icons.today_rounded : Icons.psychology_alt_rounded,
    ),
    objective: breach.briefing,
    sceneAsset: 'rooms/witness/06_twin_audit.png',
    completionRule: const NoxToolExecuted(
      deviceId: 'breach_terminal',
      action: RoomActionType.activate,
    ),
    hotspots: const [],
    devices: [
      completionDevice,
      for (final entry in breach.deviceLayout.entries)
        RoomDevice(
          id: entry.key,
          label: entry.key.replaceAll('_', ' '),
          type: RoomDeviceType.machinery,
          initialState: entry.value,
          allowedNoxActions: const {RoomActionType.setValue},
        ),
    ],
    storyBeats: [breach.briefing],
    hintLadder: const [
      'Read the policy literally.',
      'Attach evidence that contradicts the current classification.',
      'Ask NOX whether the restriction still has authority.',
    ],
    solutionRoutes: routes,
    puzzles: const [],
    sceneCues: const [],
  );
}
