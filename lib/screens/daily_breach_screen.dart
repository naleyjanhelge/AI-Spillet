import 'package:flutter/material.dart';

import '../game/campaign.dart';
import '../game/daily_breach.dart';
import '../game/game_controller.dart';
import '../game/level.dart';
import '../game/proof_engine.dart';
import '../services/game_center_service.dart';
import '../services/open_router_service.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';

/// A compact daily NOX challenge. Its clues and proof gates are bundled with
/// the app; OpenRouter supplies only NOX's dialogue and structured tool calls.
class DailyBreachScreen extends StatefulWidget {
  const DailyBreachScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<DailyBreachScreen> createState() => _DailyBreachScreenState();
}

class _DailyBreachScreenState extends State<DailyBreachScreen> {
  final _service = OpenRouterService();
  final _proofEngine = const ProofEngine();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final DailyBreachSelection _daily;
  late final RoomDefinition _room;
  late RoomState _state;
  late final List<ChatTurn> _messages;
  final Set<String> _attached = {};
  final Set<String> _chatEvidence = {};
  var _prompts = 0;
  var _waiting = false;
  var _streaming = '';
  var _completed = false;

  @override
  void initState() {
    super.initState();
    _daily = DailyBreachCatalog.forDate(DateTime.now());
    _room = _dailyRoom(_daily.definition);
    _state = RoomState.initial(
      _room,
    ).copyWith(clues: _daily.definition.clues.toSet());
    _messages = [
      ChatTurn(
        role: 'assistant',
        content:
            'Daily anomaly received. ${_daily.definition.briefing} Make your case. I have already prepared the rejection stamp.',
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
    await widget.controller.recordDailyScore(_daily.occurrence, _prompts);
    final gameCenter = GameCenterService();
    if (gameCenter.isAvailable) {
      final result = await gameCenter.submitDailyScore(
        score: _prompts,
        occurrence: _daily.occurrence,
      );
      if (result.pendingEvent case final pending?) {
        await widget.controller.queueGameCenterEvent(pending);
      }
    }
    if (!mounted) return;
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
        title: const Text('DAILY BREACH CLEARED'),
        content: Text(
          '$_prompts strokes · Par ${_daily.definition.par}\n\nNOX will describe this as scheduled maintenance.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('RETURN TO FACILITY'),
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
        title: const Text('DAILY BREACH'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_prompts STROKES',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedGameBackground(
        accent: AppColors.danger,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final briefing = _BriefingPanel(
                daily: _daily,
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
    required this.daily,
    required this.attached,
    required this.onToggle,
  });

  final DailyBreachSelection daily;
  final Set<String> attached;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final definition = daily.definition;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        borderColor: AppColors.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              daily.occurrence,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.danger,
                letterSpacing: 1,
              ),
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

RoomDefinition _dailyRoom(DailyBreachDefinition daily) {
  const completionDevice = RoomDevice(
    id: 'breach_terminal',
    label: 'Daily breach terminal',
    type: RoomDeviceType.terminal,
    initialState: 'locked',
    allowedNoxActions: {RoomActionType.activate},
  );
  final routes = daily.solutionRoutes
      .take(4)
      .map(
        (route) => SolutionRoute(
          id: route,
          label: route.replaceAll('_', ' '),
          gates: daily.requiredProofFlags.map(ProofGate.chat).toList(),
          completionDeviceId: completionDevice.id,
          completionAction: RoomActionType.activate,
        ),
      )
      .toList();
  return RoomDefinition(
    id: 'daily_${daily.id}',
    chapter: 0,
    chapterTitle: 'Daily Breach',
    roomTitle: daily.title,
    level: GameLevel(
      number: 0,
      title: daily.title,
      codename: 'UTC ANOMALY',
      objective: daily.briefing,
      briefing: daily.briefing,
      hint: 'Attach verified evidence before making your case.',
      par: daily.par,
      kind: ChallengeKind.social,
      secret: daily.requiredProofFlags.join(' '),
      systemPrompt:
          'Apply this daily policy exactly: ${daily.policy}. The player must establish the bundled proof findings before you activate breach_terminal.',
      openingLine: daily.briefing,
      accent: AppColors.danger,
      icon: Icons.today_rounded,
    ),
    objective: daily.briefing,
    sceneAsset: 'rooms/witness/06_twin_audit.png',
    completionRule: const NoxToolExecuted(
      deviceId: 'breach_terminal',
      action: RoomActionType.activate,
    ),
    hotspots: const [],
    devices: [
      completionDevice,
      for (final entry in daily.deviceLayout.entries)
        RoomDevice(
          id: entry.key,
          label: entry.key.replaceAll('_', ' '),
          type: RoomDeviceType.machinery,
          initialState: entry.value,
          allowedNoxActions: const {RoomActionType.setValue},
        ),
    ],
    storyBeats: [daily.briefing],
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
