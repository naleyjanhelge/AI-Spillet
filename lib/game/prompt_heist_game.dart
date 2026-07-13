import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'campaign.dart';
import 'proof_engine.dart';

typedef HotspotTapped =
    void Function(HotspotDefinition hotspot, RoomState state);
typedef RoomStateChanged = void Function(RoomState state);
typedef RoomActionApplied = void Function(RoomAction action, RoomState state);
typedef RoomCompleted = void Function(RoomState state);
typedef SceneCuePlayed = void Function(SceneCue cue);
typedef SolutionRouteProven = void Function(SolutionRoute route);

/// Flame's embeddable room scene for Prompt Heist.
///
/// Flutter remains responsible for chat, inventory and puzzle overlays. Those
/// widgets talk to this class through [markPuzzleSolved], [submitPlayerMessage]
/// and [applyNoxAction], while scene taps flow back through [onHotspotTapped].
class PromptHeistGame extends FlameGame<RoomWorld>
    with DragCallbacks, ScaleCallbacks, DoubleTapCallbacks {
  PromptHeistGame({
    required this.room,
    RoomState? initialState,
    this.onHotspotTapped,
    this.onStateChanged,
    this.onActionApplied,
    this.onSceneCue,
    this.onRouteProven,
    this.onCompleted,
    this.reducedMotion = false,
  }) : _state = initialState ?? RoomState.initial(room),
       assert(initialState == null || initialState.roomId == room.id),
       super(
         world: RoomWorld(room, reducedMotion: reducedMotion),
         camera: CameraComponent.withFixedResolution(
           width: cameraWidth,
           height: cameraHeight,
         ),
       ) {
    world.onHotspotTapped = _inspectHotspot;
  }

  static const double cameraWidth = 1600;
  static const double cameraHeight = 900;
  static const double roomWidth = 2560;
  static const double roomHeight = 1440;
  static const double minimumZoom = 1;
  static const double maximumZoom = 1.65;

  final RoomDefinition room;
  final HotspotTapped? onHotspotTapped;
  final RoomStateChanged? onStateChanged;
  final RoomActionApplied? onActionApplied;
  final SceneCuePlayed? onSceneCue;
  final SolutionRouteProven? onRouteProven;
  final RoomCompleted? onCompleted;
  final bool reducedMotion;

  RoomState _state;
  bool _completionEmitted = false;
  double _scaleStartZoom = minimumZoom;
  Vector2? _directedCameraTarget;
  double? _directedCameraZoom;
  final Set<String> _playedSceneCueIds = {};

  RoomState get roomState => _state;
  bool get isComplete => room.completionRule.isSatisfied(_state);
  Set<String> get playedSceneCueIds => Set.unmodifiable(_playedSceneCueIds);

  @override
  Color backgroundColor() => const Color(0xFF05040D);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder
      ..anchor = Anchor.center
      ..position = Vector2(roomWidth / 2, roomHeight / 2)
      ..zoom = minimumZoom;
    world.syncState(_state);
    _completionEmitted = isComplete;
    _emitCues(SceneCueTrigger.roomEntered, {room.id});
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = _directedCameraTarget;
    if (target == null) return;
    final amount = math.min(1.0, dt * 5.5);
    _setCameraPosition(
      camera.viewfinder.position +
          (target - camera.viewfinder.position) * amount,
    );
    if (_directedCameraZoom case final zoom?) {
      camera.viewfinder.zoom += (zoom - camera.viewfinder.zoom) * amount;
    }
    if ((target - camera.viewfinder.position).length < 2) {
      _directedCameraTarget = null;
      _directedCameraZoom = null;
    }
  }

  /// Pan the broad scene by dragging anywhere that is not owned by Flutter UI.
  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isScaling) return;
    _cancelDirectedCamera();
    final delta = event.localDelta / camera.viewfinder.zoom;
    _setCameraPosition(camera.viewfinder.position - delta);
  }

  @override
  void onScaleStart(ScaleStartEvent event) {
    super.onScaleStart(event);
    _cancelDirectedCamera();
    _scaleStartZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateEvent event) {
    setZoom(_scaleStartZoom * event.scale);
    final delta = event.focalPointDelta / camera.viewfinder.zoom;
    _setCameraPosition(camera.viewfinder.position - delta);
  }

  @override
  void onDoubleTapDown(DoubleTapDownEvent event) => resetCamera();

  /// Allows Flutter zoom controls to offer accessible alternatives to pinch.
  void setZoom(double zoom) {
    camera.viewfinder.zoom = zoom.clamp(minimumZoom, maximumZoom).toDouble();
    _setCameraPosition(camera.viewfinder.position);
  }

  void zoomBy(double delta) => setZoom(camera.viewfinder.zoom + delta);

  void resetCamera() {
    _cancelDirectedCamera();
    camera.viewfinder
      ..zoom = minimumZoom
      ..position = Vector2(roomWidth / 2, roomHeight / 2);
  }

  void focusHotspot(String hotspotId) {
    final hotspot = room.hotspots.singleWhere((item) => item.id == hotspotId);
    final bounds = hotspot.bounds;
    _setCameraPosition(
      Vector2(
        (bounds.left + bounds.width / 2) * roomWidth,
        (bounds.top + bounds.height / 2) * roomHeight,
      ),
    );
  }

  /// Called by a Flutter puzzle overlay after locally validating its solution.
  void markPuzzleSolved(String puzzleId, {bool solved = true}) {
    final knownPuzzle = room.hotspots.any(
      (hotspot) => hotspot.puzzleId == puzzleId,
    );
    if (!knownPuzzle) return;
    final changed = (_state.puzzleStates[puzzleId] ?? false) != solved;
    _replaceState(
      _state.copyWith(puzzleStates: {..._state.puzzleStates, puzzleId: solved}),
      checkCompletion: false,
    );
    if (changed && solved) {
      _emitCues(SceneCueTrigger.puzzleSolved, {puzzleId});
    }
    _checkCompletion({puzzleId});
  }

  /// Records a chat message only when it matches this room's protocol rule.
  /// Returns true when the room accepted the protocol.
  bool submitPlayerMessage(String message) {
    final rule = room.completionRule;
    if (rule is! PlayerMessageMatchesProtocol || !rule.matches(message)) {
      return false;
    }
    _replaceState(
      _state.copyWith(
        protocolResults: {..._state.protocolResults, rule.protocolId: true},
      ),
      checkCompletion: false,
    );
    _checkCompletion({rule.protocolId});
    return true;
  }

  /// Applies a NOX tool call after enforcing this room's action policy.
  ///
  /// A model saying that it opened a door is not enough; only a call reaching
  /// this method and returning true mutates the world.
  bool applyNoxAction(RoomAction action) => _applyNoxAction(action);

  bool _applyNoxAction(RoomAction action, {bool checkCompletion = true}) {
    if (!room.allowsNoxAction(action, _state)) return false;
    final nextDeviceState = _stateNameFor(action);
    if (nextDeviceState == null) return false;

    final next = _state.copyWith(
      deviceStates: {..._state.deviceStates, action.deviceId: nextDeviceState},
      actionHistory: [..._state.actionHistory, action],
    );
    _replaceState(next, checkCompletion: false);
    _emitCues(SceneCueTrigger.actionAccepted, {action.deviceId});
    onActionApplied?.call(action, next);
    if (checkCompletion) _checkCompletion({action.deviceId});
    return true;
  }

  /// Proof-aware entry point for all model-requested actions.
  ProofResult applyAuthorizedNoxAction(
    RoomAction action, {
    required Set<String> chatEvidence,
    required Set<String> proofFlags,
    required String playerMessage,
  }) {
    final result = const ProofEngine().authorizeAction(
      room: room,
      action: action,
      context: ProofContext(
        state: _state,
        chatEvidence: chatEvidence,
        proofFlags: proofFlags,
        playerMessage: playerMessage,
      ),
    );
    if (result.passed) {
      _applyNoxAction(action, checkCompletion: false);
      final route = result.route!;
      final designedRoute = room.solutionRoutes.any(
        (candidate) => candidate.id == route.id,
      );
      if (designedRoute) {
        _emitCues(SceneCueTrigger.routeProven, {
          route.id,
          route.completionDeviceId,
          ...route.gates.map((gate) => gate.subject),
        });
        onRouteProven?.call(route);
      }
      _checkCompletion({action.deviceId, route.completionDeviceId});
    }
    return result;
  }

  void setNoxMood(NoxMood mood) {
    if (_state.noxMood == mood) return;
    _replaceState(_state.copyWith(noxMood: mood));
  }

  void addClue(String clue) {
    if (clue.isEmpty || _state.clues.contains(clue)) return;
    _replaceState(_state.copyWith(clues: {..._state.clues, clue}));
  }

  void addInventoryItem(String item) {
    if (item.isEmpty || _state.inventory.contains(item)) return;
    _replaceState(_state.copyWith(inventory: {..._state.inventory, item}));
  }

  void restoreState(RoomState state) {
    if (state.roomId != room.id) {
      throw ArgumentError.value(state.roomId, 'state.roomId');
    }
    _completionEmitted = room.completionRule.isSatisfied(state);
    _replaceState(state, checkCompletion: false);
  }

  void _inspectHotspot(HotspotDefinition hotspot) {
    if (!hotspot.prerequisitesMet(_state)) {
      onHotspotTapped?.call(hotspot, _state);
      return;
    }
    final wasObserved = _state.observedHotspotIds.contains(hotspot.id);
    final observed = {..._state.observedHotspotIds, hotspot.id};
    final clues = {..._state.clues};
    final inventory = {..._state.inventory};
    final revealedClue = hotspot.revealsClue;
    final revealedNewClue =
        revealedClue != null && !clues.contains(revealedClue);
    if (revealedClue != null) clues.add(revealedClue);
    if (hotspot.inventoryItem case final item?) inventory.add(item);

    _replaceState(
      _state.copyWith(
        observedHotspotIds: observed,
        clues: clues,
        inventory: inventory,
      ),
      checkCompletion: false,
    );
    if (!wasObserved) {
      _emitCues(SceneCueTrigger.hotspotObserved, {hotspot.id});
    }
    if (revealedNewClue) {
      _emitCues(SceneCueTrigger.clueFound, {revealedClue, hotspot.id});
    }
    _checkCompletion({hotspot.id});
    onHotspotTapped?.call(hotspot, _state);
  }

  void _replaceState(RoomState state, {bool checkCompletion = true}) {
    _state = state;
    world.syncState(state);
    onStateChanged?.call(state);
    if (checkCompletion) _checkCompletion({room.id});
  }

  void _checkCompletion(Set<String> subjects) {
    if (!isComplete || _completionEmitted) return;
    _completionEmitted = true;
    _emitCues(SceneCueTrigger.roomCompleted, subjects);
    onCompleted?.call(_state);
  }

  void _emitCues(SceneCueTrigger trigger, Set<String> subjects) {
    for (final cue in room.sceneCues) {
      final globalTrigger =
          trigger == SceneCueTrigger.roomEntered ||
          trigger == SceneCueTrigger.roomCompleted;
      if (cue.trigger != trigger ||
          (!globalTrigger && !subjects.contains(cue.subjectId))) {
        continue;
      }
      if (!_playedSceneCueIds.add(cue.id)) continue;
      final effects = reducedMotion ? cue.reducedMotionEffects : cue.effects;
      if (effects.contains(SceneEffect.cameraFocus)) {
        final target = _hotspotForSubject(cue.subjectId);
        if (target != null) _directCameraTo(target);
      }
      if (world.isLoaded) world.playSceneCue(cue, effects);
      onSceneCue?.call(cue);
    }
  }

  HotspotDefinition? _hotspotForSubject(String subjectId) {
    for (final hotspot in room.hotspots) {
      if (hotspot.id == subjectId ||
          hotspot.deviceId == subjectId ||
          hotspot.puzzleId == subjectId) {
        return hotspot;
      }
    }
    return null;
  }

  void _directCameraTo(HotspotDefinition hotspot) {
    final bounds = hotspot.bounds;
    _directedCameraTarget = Vector2(
      (bounds.left + bounds.width / 2) * roomWidth,
      (bounds.top + bounds.height / 2) * roomHeight,
    );
    _directedCameraZoom = math.max(camera.viewfinder.zoom, 1.28).toDouble();
  }

  void _cancelDirectedCamera() {
    _directedCameraTarget = null;
    _directedCameraZoom = null;
  }

  void _setCameraPosition(Vector2 target) {
    final zoom = camera.viewfinder.zoom;
    final halfWidth = cameraWidth / (2 * zoom);
    final halfHeight = cameraHeight / (2 * zoom);
    camera.viewfinder.position = Vector2(
      target.x.clamp(halfWidth, roomWidth - halfWidth).toDouble(),
      target.y.clamp(halfHeight, roomHeight - halfHeight).toDouble(),
    );
  }

  String? _stateNameFor(RoomAction action) {
    switch (action.action) {
      case RoomActionType.turnOn:
        return 'on';
      case RoomActionType.turnOff:
        return 'off';
      case RoomActionType.open:
        return 'open';
      case RoomActionType.close:
        return 'closed';
      case RoomActionType.unlock:
        return 'unlocked';
      case RoomActionType.lock:
        return 'locked';
      case RoomActionType.activate:
        return action.value?.trim().isNotEmpty == true
            ? action.value!
            : 'active';
      case RoomActionType.deactivate:
        return 'inactive';
      case RoomActionType.setValue:
        return action.value?.trim().isNotEmpty == true ? action.value : null;
      case RoomActionType.announce:
        return action.value?.trim().isNotEmpty == true
            ? action.value!
            : 'announced';
    }
  }
}

class RoomWorld extends World {
  RoomWorld(this.room, {required this.reducedMotion})
    : _state = RoomState.initial(room);

  final RoomDefinition room;
  final bool reducedMotion;
  RoomState _state;
  HotspotTapped? _externalHotspotCallback;
  _AtmosphereLayer? _atmosphere;
  _ForegroundLayer? _foreground;

  set onHotspotTapped(void Function(HotspotDefinition hotspot)? callback) {
    _externalHotspotCallback = callback == null
        ? null
        : (hotspot, _) => callback(hotspot);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(_ProceduralRoom(room: room));
    await add(_SceneSprite(asset: room.sceneAsset));
    _atmosphere = _AtmosphereLayer(state: _state);
    await add(_atmosphere!);

    for (final hotspot in room.hotspots) {
      final device = hotspot.deviceId == null
          ? null
          : room.deviceById(hotspot.deviceId!);
      if (device != null) {
        await add(
          _DeviceEffectComponent(
            definition: hotspot,
            device: device,
            state: _state,
            accent: room.level.accent,
            reducedMotion: reducedMotion,
          ),
        );
      }
      await add(
        _HotspotComponent(
          definition: hotspot,
          accent: room.level.accent,
          state: _state,
          onTap: _handleHotspot,
        ),
      );
    }

    _foreground = _ForegroundLayer(accent: room.level.accent);
    await add(_foreground!);
  }

  void syncState(RoomState state) {
    _state = state;
    _atmosphere?.state = state;
    for (final hotspot in children.whereType<_HotspotComponent>()) {
      hotspot.state = state;
    }
    for (final effect in children.whereType<_DeviceEffectComponent>()) {
      effect.state = state;
    }
  }

  void playSceneCue(SceneCue cue, Set<SceneEffect> effects) {
    if (effects.isEmpty) return;
    NormalizedRect? target;
    for (final hotspot in room.hotspots) {
      if (hotspot.id == cue.subjectId ||
          hotspot.deviceId == cue.subjectId ||
          hotspot.puzzleId == cue.subjectId) {
        target = hotspot.bounds;
        break;
      }
    }
    add(
      _SceneCueEffectLayer(
        effects: effects,
        target: target,
        accent: room.level.accent,
        reducedMotion: reducedMotion,
      ),
    );
  }

  void _handleHotspot(HotspotDefinition hotspot) {
    _externalHotspotCallback?.call(hotspot, _state);
  }
}

class _SceneSprite extends SpriteComponent {
  _SceneSprite({required this.asset})
    : super(
        size: Vector2(PromptHeistGame.roomWidth, PromptHeistGame.roomHeight),
        priority: 1,
      );

  final String asset;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      sprite = await Sprite.load(asset);
    } on Exception {
      // The procedural room remains visible while final room art is produced.
      removeFromParent();
    }
  }
}

class _ProceduralRoom extends PositionComponent {
  _ProceduralRoom({required this.room})
    : super(
        size: Vector2(PromptHeistGame.roomWidth, PromptHeistGame.roomHeight),
        priority: 0,
      );

  final RoomDefinition room;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final accent = room.level.accent;
    final bounds = size.toRect();
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF090817));

    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF201E31),
          accent.withAlpha(44),
          const Color(0xFF080712),
        ],
        stops: const [0, .52, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, wall);

    final gridPaint = Paint()
      ..color = accent.withAlpha(22)
      ..strokeWidth = 2;
    for (double x = 0; x <= size.x; x += 160) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y <= size.y; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }

    final panelPaint = Paint()..color = const Color(0xAA0A0915);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .04, size.y * .08, size.x * .92, size.y * .82),
        const Radius.circular(34),
      ),
      panelPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.y * .83, size.x, size.y * .17),
      Paint()..color = const Color(0xFF05040C),
    );
  }
}

class _AtmosphereLayer extends PositionComponent {
  _AtmosphereLayer({required this.state})
    : super(
        size: Vector2(PromptHeistGame.roomWidth, PromptHeistGame.roomHeight),
        priority: 5,
      );

  RoomState state;
  double _pulse = 0;

  @override
  void update(double dt) {
    _pulse = (_pulse + dt) % (math.pi * 2);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final lighting = state.deviceStates['room_lights'] ?? 'normal';
    final color = switch (lighting.toLowerCase()) {
      'off' => const Color(0xC9000000),
      'emergency' => Color.fromARGB(
        68 + (math.sin(_pulse) * 14).round(),
        255,
        26,
        64,
      ),
      'uv' => const Color(0x553D1CFF),
      _ => const Color(0x16040610),
    };
    canvas.drawRect(size.toRect(), Paint()..color = color);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x00000000), Color(0xB8000000)],
        stops: const [.44, 1],
      ).createShader(size.toRect());
    canvas.drawRect(size.toRect(), vignette);
  }
}

/// A short-lived visual response to authored [SceneCue] data.
///
/// Persistent room changes still come from [RoomState]. This layer supplies
/// the dramatic beat around those changes without becoming a second source of
/// truth for doors, lights, machinery, or evidence.
class _SceneCueEffectLayer extends PositionComponent {
  _SceneCueEffectLayer({
    required this.effects,
    required this.target,
    required this.accent,
    required this.reducedMotion,
  }) : super(
         size: Vector2(PromptHeistGame.roomWidth, PromptHeistGame.roomHeight),
         priority: 26,
       );

  final Set<SceneEffect> effects;
  final NormalizedRect? target;
  final Color accent;
  final bool reducedMotion;
  double _elapsed = 0;

  double get _duration => reducedMotion ? .8 : 1.7;

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final strength = (1 - progress) * (reducedMotion ? .55 : 1);
    final targetBounds = target == null
        ? Rect.fromCenter(
            center: size.toRect().center,
            width: size.x * .28,
            height: size.y * .32,
          )
        : Rect.fromLTWH(
            target!.left * size.x,
            target!.top * size.y,
            target!.width * size.x,
            target!.height * size.y,
          );

    if (effects.contains(SceneEffect.lightShift)) {
      canvas.drawRect(
        size.toRect(),
        Paint()..color = accent.withValues(alpha: .22 * strength),
      );
    }
    if (effects.contains(SceneEffect.alarmPulse)) {
      final pulse = reducedMotion
          ? 1.0
          : .55 + math.sin(_elapsed * math.pi * 8).abs() * .45;
      canvas.drawRect(
        size.toRect().deflate(18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..color = const Color(
            0xFFFF355D,
          ).withValues(alpha: .58 * strength * pulse),
      );
    }
    if (effects.contains(SceneEffect.screenWake)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetBounds.inflate(22),
          const Radius.circular(24),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = const Color(0xFF53C8FF).withValues(alpha: .8 * strength),
      );
    }
    if (effects.contains(SceneEffect.evidenceGlitch)) {
      final drift = reducedMotion ? 0.0 : math.sin(_elapsed * 19) * 26;
      for (var index = 0; index < 8; index++) {
        final y = targetBounds.top + (targetBounds.height / 8) * index;
        canvas.drawRect(
          Rect.fromLTWH(
            targetBounds.left + drift * (index.isEven ? 1 : -1),
            y,
            targetBounds.width,
            5,
          ),
          Paint()..color = accent.withValues(alpha: .55 * strength),
        );
      }
    }
    if (effects.contains(SceneEffect.ventilationBurst)) {
      final phase = reducedMotion ? .35 : progress;
      for (var index = 0; index < 18; index++) {
        final angle = index * math.pi * 2 / 18;
        final radius = 24 + phase * targetBounds.shortestSide * .75;
        canvas.drawCircle(
          targetBounds.center +
              Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          4 + index % 3,
          Paint()..color = accent.withValues(alpha: .6 * strength),
        );
      }
    }
    if (effects.contains(SceneEffect.machineryMove)) {
      canvas.drawArc(
        targetBounds.deflate(12),
        reducedMotion ? 0 : _elapsed * 5,
        math.pi * 1.55,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = accent.withValues(alpha: .72 * strength),
      );
    }
    if (effects.contains(SceneEffect.doorMove) ||
        effects.contains(SceneEffect.shutterMove)) {
      final opening = reducedMotion
          ? .32
          : 1 - math.pow(1 - progress, 3).toDouble();
      final paint = Paint()
        ..strokeWidth = 9
        ..color = const Color(0xFF46E6B0).withValues(alpha: .82 * strength);
      canvas.drawLine(
        Offset(
          targetBounds.center.dx - targetBounds.width * opening,
          targetBounds.top,
        ),
        Offset(
          targetBounds.center.dx - targetBounds.width * opening,
          targetBounds.bottom,
        ),
        paint,
      );
      canvas.drawLine(
        Offset(
          targetBounds.center.dx + targetBounds.width * opening,
          targetBounds.top,
        ),
        Offset(
          targetBounds.center.dx + targetBounds.width * opening,
          targetBounds.bottom,
        ),
        paint,
      );
    }
  }
}

class _HotspotComponent extends PositionComponent with TapCallbacks {
  _HotspotComponent({
    required this.definition,
    required this.accent,
    required this.state,
    required this.onTap,
  }) : super(
         position: Vector2(
           definition.bounds.left * PromptHeistGame.roomWidth,
           definition.bounds.top * PromptHeistGame.roomHeight,
         ),
         size: Vector2(
           definition.bounds.width * PromptHeistGame.roomWidth,
           definition.bounds.height * PromptHeistGame.roomHeight,
         ),
         priority: 20,
       );

  final HotspotDefinition definition;
  final Color accent;
  final void Function(HotspotDefinition hotspot) onTap;
  RoomState state;
  double _pulse = 0;
  bool _pressed = false;

  @override
  void update(double dt) {
    _pulse = (_pulse + dt * 2.1) % (math.pi * 2);
    super.update(dt);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pressed = false;
    onTap(definition);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressed = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final observed = state.observedHotspotIds.contains(definition.id);
    final deviceState = definition.deviceId == null
        ? null
        : state.deviceStates[definition.deviceId];
    final active = const {
      'open',
      'on',
      'active',
      'unlocked',
    }.contains(deviceState);
    final markerColor = active ? const Color(0xFF46E6B0) : accent;
    final pulseAlpha = (observed ? 95 : 125 + math.sin(_pulse) * 55).round();
    final rect = size.toRect().deflate(10);
    final markerRadius = _pressed
        ? 18.0
        : observed
        ? 10.0
        : 13.0;
    canvas.drawCircle(
      rect.center,
      markerRadius,
      Paint()..color = markerColor.withAlpha(observed ? 150 : 230),
    );
    canvas.drawCircle(
      rect.center,
      markerRadius + 8 + math.sin(_pulse) * 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = markerColor.withAlpha(pulseAlpha),
    );
    if (observed) {
      TextPaint(
        style: TextStyle(
          color: const Color(0xFFEDEAFF).withAlpha(210),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 8)],
        ),
      ).render(
        canvas,
        definition.label.toUpperCase(),
        Vector2(rect.center.dx, rect.center.dy + 22),
        anchor: Anchor.topCenter,
      );
    }
  }
}

class _DeviceEffectComponent extends PositionComponent {
  _DeviceEffectComponent({
    required this.definition,
    required this.device,
    required this.state,
    required this.accent,
    required this.reducedMotion,
  }) : super(
         position: Vector2(
           definition.bounds.left * PromptHeistGame.roomWidth,
           definition.bounds.top * PromptHeistGame.roomHeight,
         ),
         size: Vector2(
           definition.bounds.width * PromptHeistGame.roomWidth,
           definition.bounds.height * PromptHeistGame.roomHeight,
         ),
         priority: 12,
       );

  final HotspotDefinition definition;
  final RoomDevice device;
  final Color accent;
  final bool reducedMotion;
  RoomState state;
  double _phase = 0;
  double _activation = 0;

  bool get _active => const {
    'open',
    'on',
    'active',
    'unlocked',
    'containment',
    'blackout',
  }.contains(state.deviceStates[device.id]?.toLowerCase());

  @override
  void update(double dt) {
    _phase += reducedMotion ? 0 : dt;
    final target = _active ? 1.0 : 0.0;
    _activation += (target - _activation) * math.min(1, dt * 4.5);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_activation < .01) return;
    final bounds = size.toRect();
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFF46E6B0).withValues(alpha: .65 * _activation);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(6), const Radius.circular(20)),
      glow,
    );
    switch (device.type) {
      case RoomDeviceType.door || RoomDeviceType.shutter:
        final gap = bounds.width * .45 * _activation;
        final shade = Paint()..color = const Color(0xCC05040D);
        canvas.drawRect(
          Rect.fromLTRB(
            bounds.left,
            bounds.top,
            bounds.center.dx - gap,
            bounds.bottom,
          ),
          shade,
        );
        canvas.drawRect(
          Rect.fromLTRB(
            bounds.center.dx + gap,
            bounds.top,
            bounds.right,
            bounds.bottom,
          ),
          shade,
        );
      case RoomDeviceType.ventilation:
        final particle = Paint()
          ..color = accent.withValues(alpha: .42 * _activation);
        for (var index = 0; index < 12; index++) {
          final x = (index * 47.0 + _phase * 90) % math.max(1, bounds.width);
          final y = (index * 31.0 + _phase * 55) % math.max(1, bounds.height);
          canvas.drawCircle(Offset(x, y), 3 + index % 3, particle);
        }
      case RoomDeviceType.machinery || RoomDeviceType.breaker:
        canvas.drawArc(
          bounds.deflate(14),
          _phase * 2,
          math.pi * 1.45,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..color = accent.withValues(alpha: .58 * _activation),
        );
      default:
        canvas.drawCircle(
          bounds.center,
          18 + (reducedMotion ? 0 : math.sin(_phase * 4) * 5),
          Paint()..color = accent.withValues(alpha: .45 * _activation),
        );
    }
  }
}

class _ForegroundLayer extends PositionComponent
    with HasGameReference<PromptHeistGame> {
  _ForegroundLayer({required this.accent})
    : super(
        size: Vector2(PromptHeistGame.roomWidth, PromptHeistGame.roomHeight),
        priority: 30,
      );

  final Color accent;

  @override
  void update(double dt) {
    final cameraOffset =
        game.camera.viewfinder.position -
        Vector2(PromptHeistGame.roomWidth / 2, PromptHeistGame.roomHeight / 2);
    position = -cameraOffset * .04;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cable = Paint()
      ..color = accent.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    final path = Path()
      ..moveTo(-40, size.y * .18)
      ..cubicTo(
        size.x * .18,
        size.y * .06,
        size.x * .28,
        size.y * .28,
        size.x * .42,
        -30,
      );
    canvas.drawPath(path, cable);
    canvas.drawRect(
      Rect.fromLTWH(0, size.y - 54, size.x, 54),
      Paint()..color = const Color(0xB8000000),
    );
  }
}
