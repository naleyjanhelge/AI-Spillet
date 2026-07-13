import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game/campaign.dart';
import '../game/daily_breach.dart';
import '../game/game_controller.dart';
import '../services/audio_service.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';
import 'daily_breach_screen.dart';
import 'game_screen.dart';
import 'heist_board_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _audio = PromptHeistAudio.instance;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _audio.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _audio.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  RoomDefinition? _roomById(String id) {
    for (final room in helix9Rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  Future<void> _openRoom(
    RoomDefinition room, {
    bool startNewRun = false,
  }) async {
    if (!widget.controller.isUnlocked(room.level)) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clear the previous room first.')),
      );
      return;
    }

    final active = widget.controller.activeRun;
    final replacesDifferentRun =
        active != null && active.roomId != room.id && !startNewRun;
    if (replacesDifferentRun) {
      final replace = await _confirmNewRun(
        title: 'Leave the active breach?',
        message:
            'Starting ${room.roomTitle} replaces your unfinished run in ${_roomById(active.roomId)?.roomTitle ?? 'another room'}.',
      );
      if (!replace) return;
      startNewRun = true;
    }

    if (startNewRun) {
      await widget.controller.startNewRun(room);
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: _audio.reducedMotion ? Duration.zero : 420.ms,
        pageBuilder: (_, animation, _) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: GameScreen(level: room.level, controller: widget.controller),
        ),
      ),
    );
  }

  Future<void> _startFresh(RoomDefinition room) async {
    final active = widget.controller.activeRun;
    if (active != null) {
      final replace = await _confirmNewRun(
        title: 'Start a fresh run?',
        message:
            'Your current ${_roomById(active.roomId)?.roomTitle ?? 'room'} dialogue, evidence and score will be replaced.',
      );
      if (!replace) return;
    }
    await _openRoom(room, startNewRun: true);
  }

  Future<bool> _confirmNewRun({
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP CURRENT'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('START NEW'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openDailyBreach() async {
    if (!widget.controller.dailyBreachUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily Breach unlocks after Freight Spine.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyBreachScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            MediaQuery.paddingOf(context).bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'HELIX-9 SYSTEMS',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.cyan),
                ),
                const SizedBox(height: 5),
                Text(
                  'Audio & accessibility',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    _audio.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: AppColors.ultraviolet,
                  ),
                  title: const Text('Mute all audio'),
                  subtitle: const Text('Silence ambience and effects.'),
                  value: _audio.muted,
                  onChanged: (value) {
                    unawaited(_audio.setMuted(value));
                    setSheetState(() {});
                  },
                ),
                _VolumeControl(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Ambience',
                  value: _audio.ambienceVolume,
                  enabled: !_audio.muted,
                  onChanged: (value) {
                    unawaited(_audio.setAmbienceVolume(value));
                    setSheetState(() {});
                  },
                ),
                _VolumeControl(
                  icon: Icons.bolt_rounded,
                  label: 'Effects',
                  value: _audio.effectsVolume,
                  enabled: !_audio.muted,
                  onChanged: (value) {
                    unawaited(_audio.setEffectsVolume(value));
                    setSheetState(() {});
                  },
                ),
                const Divider(height: 26),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.motion_photos_off_rounded,
                    color: AppColors.cyan,
                  ),
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Removes camera sweeps and shortens transitions.',
                  ),
                  value: _audio.reducedMotion,
                  onChanged: (value) {
                    unawaited(_audio.setReducedMotion(value));
                    setSheetState(() {});
                  },
                ),
                const Divider(height: 26),
                const Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.smart_toy_outlined,
                      color: AppColors.ultraviolet,
                    ),
                    title: Text('NOX uplink'),
                    subtitle: Text(
                      'openrouter/free · direct from this device',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.restart_alt_rounded,
                      color: AppColors.danger,
                    ),
                    title: const Text('Reset campaign'),
                    subtitle: const Text(
                      'Erase active run, evidence and every score.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final confirmed = await showDialog<bool>(
                        context: this.context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.surfaceHigh,
                          title: const Text('Reset The Witness Protocol?'),
                          content: const Text(
                            'Campaign progress will be erased. Audio and accessibility settings remain on this device.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('RESET'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await widget.controller.reset();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These settings are stored locally and never require an account.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHeistBoard() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: _audio.reducedMotion ? Duration.zero : 420.ms,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: HeistBoardScreen(controller: widget.controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRoom = widget.controller.activeRun == null
        ? null
        : _roomById(widget.controller.activeRun!.roomId);
    final nextRoom =
        helix9Rooms[(widget.controller.unlockedLevel - 1).clamp(
          0,
          helix9Rooms.length - 1,
        )];
    final acts = <int, List<RoomDefinition>>{
      for (var act = 1; act <= 3; act++)
        act: helix9Rooms.where((room) => room.chapter == act).toList(),
    };

    return Scaffold(
      body: AnimatedGameBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    onSettings: _showSettings,
                    onBoard: _openHeistBoard,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _CommandCard(
                    controller: widget.controller,
                    activeRoom: activeRoom,
                    nextRoom: nextRoom,
                    onContinue: () => _openRoom(activeRoom ?? nextRoom),
                    onNewRun: () => _startFresh(activeRoom ?? nextRoom),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _DailyBreachCard(
                    controller: widget.controller,
                    onTap: _openDailyBreach,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'HELIX-9 FACILITY MAP',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        '${widget.controller.completedLevels}/12 CLEARED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.paddingOf(context).bottom + 30,
                ),
                sliver: SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) => _FacilityAct(
                    act: index + 1,
                    rooms: acts[index + 1]!,
                    controller: widget.controller,
                    activeRoomId: widget.controller.activeRun?.roomId,
                    onRoomTap: _openRoom,
                    reducedMotion: _audio.reducedMotion,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings, required this.onBoard});
  final VoidCallback onSettings;
  final VoidCallback onBoard;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              fontSize: 24,
            ),
            children: [
              TextSpan(text: 'PROMPT'),
              TextSpan(
                text: 'HEIST',
                style: TextStyle(color: AppColors.ultraviolet),
              ),
              TextSpan(
                text: ' // 2.0',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
      IconButton.filledTonal(
        onPressed: onBoard,
        tooltip: 'Heist Board',
        icon: const Icon(Icons.emoji_events_rounded, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.deepSpace,
          backgroundColor: AppColors.cyan,
        ),
      ),
      const SizedBox(width: 6),
      IconButton.filledTonal(
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.tune_rounded, size: 20),
      ),
    ],
  );
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.controller,
    required this.activeRoom,
    required this.nextRoom,
    required this.onContinue,
    required this.onNewRun,
  });

  final GameController controller;
  final RoomDefinition? activeRoom;
  final RoomDefinition nextRoom;
  final VoidCallback onContinue;
  final VoidCallback onNewRun;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeRun;
    final room = activeRoom ?? nextRoom;
    return GlassPanel(
      borderColor: room.level.accent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/${room.sceneAsset}',
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.deepSpace],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Row(
                    children: [
                      const NoxAvatar(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active == null
                                  ? 'NEXT ASSIGNMENT'
                                  : 'ACTIVE BREACH // ${active.effectiveStrokes} STROKES',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.success,
                                    letterSpacing: .9,
                                  ),
                            ),
                            Text(
                              room.roomTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active == null
                      ? 'The missing thirty-eight minutes begin here.'
                      : '${active.events.length} timeline events, ${active.hintsUsed.length} hints. Your evidence is exactly where you left it.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onContinue,
                        icon: Icon(
                          active == null
                              ? Icons.play_arrow_rounded
                              : Icons.fast_forward_rounded,
                        ),
                        label: Text(active == null ? 'BEGIN' : 'CONTINUE'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNewRun,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('NEW RUN'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBreachCard extends StatelessWidget {
  const _DailyBreachCard({required this.controller, required this.onTap});
  final GameController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.dailyBreachUnlocked;
    final daily = DailyBreachCatalog.forDate(DateTime.now());
    final best = controller.dailyBestScores[daily.occurrence];
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      borderColor: unlocked ? AppColors.danger : AppColors.textMuted,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: unlocked
                    ? [AppColors.danger, AppColors.ultraviolet]
                    : [AppColors.surfaceHigh, AppColors.deepSpace],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? Icons.today_rounded : Icons.lock_clock_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY BREACH // ${daily.occurrence}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: unlocked ? AppColors.danger : AppColors.textMuted,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? daily.definition.title : 'CLASSIFIED ANOMALY',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? best == null
                            ? 'Same breach worldwide · Par ${daily.definition.par}'
                            : 'Personal best · $best strokes'
                      : 'Clear Room 4 · Freight Spine to unlock',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.chevron_right_rounded : Icons.lock_rounded,
            color: unlocked ? AppColors.danger : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _FacilityAct extends StatelessWidget {
  const _FacilityAct({
    required this.act,
    required this.rooms,
    required this.controller,
    required this.activeRoomId,
    required this.onRoomTap,
    required this.reducedMotion,
  });

  final int act;
  final List<RoomDefinition> rooms;
  final GameController controller;
  final String? activeRoomId;
  final ValueChanged<RoomDefinition> onRoomTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final cleared = rooms.where(
      (room) => controller.bestRuns.containsKey(room.level.number),
    );
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      borderColor: cleared.length == 4
          ? AppColors.success
          : rooms.first.level.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rooms.first.level.accent.withValues(alpha: .16),
                  shape: BoxShape.circle,
                  border: Border.all(color: rooms.first.level.accent),
                ),
                child: Text('$act'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACT $act // FLOOR ${4 - act}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: rooms.first.level.accent,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      rooms.first.chapterTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '${cleared.length}/4',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < rooms.length; index++)
                    SizedBox(
                          width: width,
                          child: _MapRoomNode(
                            room: rooms[index],
                            unlocked: controller.isUnlocked(rooms[index].level),
                            active: rooms[index].id == activeRoomId,
                            best:
                                controller.bestRuns[rooms[index].level.number],
                            isLast: index == rooms.length - 1,
                            onTap: () => onRoomTap(rooms[index]),
                          ),
                        )
                        .animate(
                          delay: reducedMotion
                              ? Duration.zero
                              : (60 * index).ms,
                        )
                        .fadeIn(duration: reducedMotion ? 1.ms : 250.ms),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapRoomNode extends StatelessWidget {
  const _MapRoomNode({
    required this.room,
    required this.unlocked,
    required this.active,
    required this.best,
    required this.isLast,
    required this.onTap,
  });

  final RoomDefinition room;
  final bool unlocked;
  final bool active;
  final RunScore? best;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Room ${room.level.number}, ${room.roomTitle}, ${unlocked
            ? best == null
                  ? 'available'
                  : 'cleared'
            : 'locked'}',
    child: Material(
      color: active
          ? room.level.accent.withValues(alpha: .16)
          : AppColors.surfaceHigh.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            )
                          : const ColorFilter.mode(
                              Color(0xFF36343D),
                              BlendMode.saturation,
                            ),
                      child: Image.asset(
                        'assets/images/${room.sceneAsset}',
                        fit: BoxFit.cover,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.deepSpace.withValues(alpha: .8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.voidBlack.withValues(alpha: .8),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${room.level.number}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: unlocked ? 1 : .48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (active)
                          Text(
                            'RUN ACTIVE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.success),
                          ),
                        Text(
                          room.roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          !unlocked
                              ? 'ACCESS SEALED'
                              : best == null
                              ? '${room.level.codename} · PAR ${room.level.par}'
                              : 'BEST ${best!.effectiveStrokes} · ${best!.starsFor(room.level.par)} STARS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 9),
                child: Icon(
                  unlocked
                      ? active
                            ? Icons.fast_forward_rounded
                            : best == null
                            ? Icons.chevron_right_rounded
                            : Icons.check_circle_rounded
                      : Icons.lock_rounded,
                  size: 19,
                  color: unlocked ? room.level.accent : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: enabled ? AppColors.cyan : AppColors.textMuted),
      const SizedBox(width: 12),
      SizedBox(width: 76, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          onChanged: enabled ? onChanged : null,
          divisions: 10,
          label: '${(value * 100).round()}%',
        ),
      ),
      SizedBox(
        width: 38,
        child: Text(
          '${(value * 100).round()}',
          textAlign: TextAlign.end,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    ],
  );
}
