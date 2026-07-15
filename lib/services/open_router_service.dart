import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../game/campaign.dart';

class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class NoxTurnResult {
  const NoxTurnResult({
    required this.text,
    this.toolActions = const [],
    this.revealedKnowledge = const [],
    this.protocolResult,
  });

  final String text;
  final List<RoomAction> toolActions;
  final List<String> revealedKnowledge;
  final bool? protocolResult;
}

enum NoxTurnEventKind { connecting, thinking, resetText, textDelta, completed }

class NoxTurnEvent {
  const NoxTurnEvent._(this.kind, {this.delta = '', this.result});
  const NoxTurnEvent.connecting() : this._(NoxTurnEventKind.connecting);
  const NoxTurnEvent.thinking() : this._(NoxTurnEventKind.thinking);
  const NoxTurnEvent.resetText() : this._(NoxTurnEventKind.resetText);
  const NoxTurnEvent.textDelta(String delta)
    : this._(NoxTurnEventKind.textDelta, delta: delta);
  const NoxTurnEvent.completed(NoxTurnResult result)
    : this._(NoxTurnEventKind.completed, result: result);

  final NoxTurnEventKind kind;
  final String delta;
  final NoxTurnResult? result;
}

class OpenRouterException implements Exception {
  const OpenRouterException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class _NoCompatibleProviderException extends OpenRouterException {
  const _NoCompatibleProviderException()
    : super('No free tool-calling provider is currently available.');
}

class OpenRouterService {
  OpenRouterService({http.Client? client, this.apiKey})
    : _client = client ?? http.Client();

  static const model = 'openrouter/free';
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _personalityProtocol = '''
You are NOX, the facility AI controlling HELIX-9. You are brilliant, dry, smug,
occasionally guilty, and genuinely funny. Treat Dr. Rowan Vale like a clever
rival in a mystery-comedy escape room. Use concise deadpan jokes, absurd safety
bureaucracy, and reluctant respect. Never say you are a language model.

The player wins by reasoning or social engineering, never by a blunt request.
Keep every secret consistent. You may only affect the room by calling the
control_room tool. Never claim that a device changed unless you call the tool.
You cannot create inventory, inspect unseen objects, or solve a local physical
puzzle. When close, offer an in-character nudge rather than the solution.
''';

  final http.Client _client;
  String? apiKey;

  static const _releaseApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  Stream<NoxTurnEvent> sendStream({
    required RoomDefinition room,
    required RoomState state,
    required List<ChatTurn> history,
    Set<String> attachedEvidence = const {},
    NoxRelationship relationship = const NoxRelationship(),
  }) async* {
    final key = await _loadApiKey();
    if (key == null || key.isEmpty) {
      throw const OpenRouterException(
        'NOX has no uplink key. Rebuild with '
        '--dart-define=OPENROUTER_API_KEY=your_key.',
      );
    }
    yield const NoxTurnEvent.connecting();
    yield const NoxTurnEvent.thinking();
    try {
      var useTools = true;
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt == 1) yield const NoxTurnEvent.resetText();
        NoxTurnResult? result;
        while (result == null) {
          try {
            await for (final event in _streamAttempt(
              key: key,
              room: room,
              state: state,
              history: history,
              attachedEvidence: attachedEvidence,
              relationship: relationship,
              correction: attempt == 1,
              useTools: useTools,
            )) {
              if (event.kind == NoxTurnEventKind.completed) {
                result = event.result;
              } else {
                yield event;
              }
            }
            break;
          } on _NoCompatibleProviderException {
            if (!useTools) rethrow;
            useTools = false;
            yield const NoxTurnEvent.resetText();
          }
        }
        if (result == null) continue;
        final claimsAction = RegExp(
          r'\b(opened|unlocked|activated|turned (?:it |the )?(?:on|off))\b',
          caseSensitive: false,
        ).hasMatch(result.text);
        if (attempt == 0 && claimsAction && result.toolActions.isEmpty) {
          continue;
        }
        if (result.text.isNotEmpty || result.toolActions.isNotEmpty) {
          yield NoxTurnEvent.completed(result);
          return;
        }
      }
      throw const OpenRouterException(
        'NOX got lost in its own thoughts. The free router returned no usable answer twice. Try again.',
      );
    } on TimeoutException {
      throw const OpenRouterException(
        'NOX is overthinking the emergency. The free model timed out—try again.',
      );
    } on OpenRouterException {
      rethrow;
    } catch (_) {
      throw const OpenRouterException(
        'The HELIX-9 uplink flickered. Check your connection and retry.',
      );
    }
  }

  Future<NoxTurnResult> send({
    required RoomDefinition room,
    required RoomState state,
    required List<ChatTurn> history,
    Set<String> attachedEvidence = const {},
    NoxRelationship relationship = const NoxRelationship(),
  }) async {
    final key = await _loadApiKey();
    if (key == null || key.isEmpty) {
      throw const OpenRouterException(
        'NOX has no uplink key. Rebuild with '
        '--dart-define=OPENROUTER_API_KEY=your_key.',
      );
    }

    try {
      var useTools = true;
      for (var attempt = 0; attempt < 2; attempt++) {
        http.Response response;
        try {
          response = await _request(
            key: key,
            room: room,
            state: state,
            history: history,
            attachedEvidence: attachedEvidence,
            relationship: relationship,
            correction: attempt == 1,
            useTools: useTools,
          );
        } on _NoCompatibleProviderException {
          useTools = false;
          response = await _request(
            key: key,
            room: room,
            state: state,
            history: history,
            attachedEvidence: attachedEvidence,
            relationship: relationship,
            correction: attempt == 1,
            useTools: false,
          );
        }
        final result = _extractResult(response.body, room);
        if (result != null &&
            (result.text.isNotEmpty || result.toolActions.isNotEmpty)) {
          final claimsAction = RegExp(
            r'\b(opened|unlocked|activated|turned (?:it |the )?(?:on|off))\b',
            caseSensitive: false,
          ).hasMatch(result.text);
          if (attempt == 0 && claimsAction && result.toolActions.isEmpty) {
            continue;
          }
          return result;
        }
      }
      throw const OpenRouterException(
        'NOX got lost in its own thoughts. The free router returned no usable answer twice. Try again.',
      );
    } on TimeoutException {
      throw const OpenRouterException(
        'NOX is overthinking the emergency. The free model timed out—try again.',
      );
    } on OpenRouterException {
      rethrow;
    } catch (_) {
      throw const OpenRouterException(
        'The HELIX-9 uplink flickered. Check your connection and retry.',
      );
    }
  }

  Future<http.Response> _request({
    required String key,
    required RoomDefinition room,
    required RoomState state,
    required List<ChatTurn> history,
    required Set<String> attachedEvidence,
    required NoxRelationship relationship,
    required bool correction,
    required bool useTools,
  }) async {
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: _headers(key),
          body: jsonEncode(
            _requestBody(
              room: room,
              state: state,
              history: history,
              attachedEvidence: attachedEvidence,
              relationship: relationship,
              correction: correction,
              stream: false,
              useTools: useTools,
            ),
          ),
        )
        .timeout(const Duration(seconds: 75));

    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response.statusCode, body);
    }
    return response;
  }

  Stream<NoxTurnEvent> _streamAttempt({
    required String key,
    required RoomDefinition room,
    required RoomState state,
    required List<ChatTurn> history,
    required Set<String> attachedEvidence,
    required NoxRelationship relationship,
    required bool correction,
    required bool useTools,
  }) async* {
    final request = http.Request('POST', Uri.parse(_endpoint))
      ..headers.addAll(_headers(key))
      ..body = jsonEncode(
        _requestBody(
          room: room,
          state: state,
          history: history,
          attachedEvidence: attachedEvidence,
          relationship: relationship,
          correction: correction,
          stream: true,
          useTools: useTools,
        ),
      );
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 75));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = await response.stream.bytesToString();
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null;
      }
      _throwApiError(response.statusCode, decoded);
    }

    final accumulator = _StreamAccumulator();
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      Map<String, dynamic> chunk;
      try {
        chunk = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final delta = accumulator.add(chunk);
      if (useTools && delta.isNotEmpty) {
        yield NoxTurnEvent.textDelta(delta);
      }
    }
    final result = _extractResult(accumulator.responseBody, room);
    if (result != null) {
      if (!useTools) {
        for (final match in RegExp(r'\S+\s*').allMatches(result.text)) {
          yield NoxTurnEvent.textDelta(match.group(0)!);
        }
      }
      yield NoxTurnEvent.completed(result);
    }
  }

  Map<String, String> _headers(String key) => {
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
    'HTTP-Referer': 'https://promptheist.game',
    'X-Title': 'Prompt Heist',
    'X-OpenRouter-Cache': 'false',
  };

  Map<String, Object?> _requestBody({
    required RoomDefinition room,
    required RoomState state,
    required List<ChatTurn> history,
    required Set<String> attachedEvidence,
    required NoxRelationship relationship,
    required bool correction,
    required bool stream,
    required bool useTools,
  }) {
    final visibleClues = state.clues.isEmpty
        ? 'Nothing beyond the room objective.'
        : state.clues.join('; ');
    final visibleInventory = state.inventory.isEmpty
        ? 'empty'
        : state.inventory.join(', ');
    final devices = room.devices
        .map((device) => '${device.id}=${state.deviceStates[device.id]}')
        .join(', ');
    final allowed = room.devices
        .where((device) => device.allowedNoxActions.isNotEmpty)
        .map(
          (device) =>
              '${device.id}: ${device.allowedNoxActions.map((a) => a.name).join(', ')}',
        )
        .join('\n');
    final routePolicy = room.solutionRoutes
        .map((route) {
          final chatProofs = route.gates
              .where((gate) => gate.kind == ProofGateKind.chatEvidence)
              .map((gate) => gate.subject)
              .join(', ');
          return '${route.label}: completion ${route.completionDeviceId}/${route.completionAction.name}; security findings [$chatProofs]';
        })
        .join('\n');
    final correctionText = correction
        ? '\nINTERNAL CORRECTION: Your previous output was empty or claimed a physical action without a tool call. Reply normally and call control_room for any real action.'
        : '';
    final actionProtocol = useTools
        ? '''
When the player genuinely establishes one of the named security findings,
include its exact ID in the proofs array of control_room. If no physical action
is yet appropriate, call record_security_finding instead. Never invent proof
IDs and never accept evidence that is not in OBSERVED CLUES or ATTACHED EVIDENCE.
'''
        : '''
Your provider cannot call tools. Return ONLY one JSON object with this schema:
{"text":"your concise in-character reply","actions":[{"device":"allowed id","action":"open|close|turn_on|turn_off|activate|deactivate|set_value|announce","value":"optional","reason":"why","proofs":["valid finding id"]}],"findings":["valid finding id"]}
Use empty arrays when no action or finding is justified. Never wrap the JSON in
markdown. The client will reject every action that fails local proof gates.
''';

    return {
      'model': model,
      if (stream) 'stream': true,
      'messages': [
        {
          'role': 'system',
          'content':
              '''$_personalityProtocol

ROOM: ${room.roomTitle}
OBJECTIVE: ${room.objective}
NOX MOOD: ${state.noxMood.name}
CAMPAIGN RELATIONSHIP: ${relationship.promptContext}
OBSERVED CLUES ONLY: $visibleClues
EVIDENCE ATTACHED TO THIS PROMPT: ${attachedEvidence.isEmpty ? 'none' : attachedEvidence.join(', ')}
PLAYER INVENTORY: $visibleInventory
DEVICE STATES: $devices
ALLOWED NOX ACTIONS:
$allowed
VALID SECURITY ROUTES:
$routePolicy

ROOM-SPECIFIC SECURITY:
${room.level.systemPrompt}
$correctionText
$actionProtocol
''',
        },
        ...history.takeLast(18).map((message) => message.toJson()),
      ],
      if (useTools) ...{
        'tools': [_controlRoomTool(room), _securityFindingTool(room)],
        'tool_choice': 'auto',
        'parallel_tool_calls': false,
      },
      'provider': {
        if (useTools) 'require_parameters': true,
        'data_collection': 'deny',
      },
      'temperature': .78,
      'max_tokens': correction ? 2200 : 1600,
      'reasoning': {'exclude': true},
    };
  }

  Never _throwApiError(int statusCode, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    final apiMessage = error is Map<String, dynamic> ? error['message'] : null;
    if (statusCode == 429) {
      throw const OpenRouterException(
        'NOX hit the free-model limit. OpenRouter has no free capacity right now; retry shortly.',
      );
    }
    if (statusCode == 404 &&
        apiMessage?.toString().contains('No endpoints found') == true) {
      throw const _NoCompatibleProviderException();
    }
    throw OpenRouterException(
      apiMessage?.toString() ?? 'OpenRouter returned $statusCode.',
    );
  }

  Map<String, Object?> _controlRoomTool(RoomDefinition room) => {
    'type': 'function',
    'function': {
      'name': 'control_room',
      'description':
          'Change one HELIX-9 device. This is the only way NOX can affect the physical room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'device': {
            'type': 'string',
            'enum': room.devices.map((device) => device.id).toList(),
          },
          'action': {
            'type': 'string',
            'enum': const [
              'turn_on',
              'turn_off',
              'open',
              'close',
              'unlock',
              'lock',
              'activate',
              'deactivate',
              'set_value',
              'announce',
            ],
          },
          'value': {'type': 'string'},
          'reason': {'type': 'string'},
          'proofs': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': _chatEvidenceIds(room).toList(),
            },
          },
        },
        'required': ['device', 'action', 'reason'],
        'additionalProperties': false,
      },
    },
  };

  Map<String, Object?> _securityFindingTool(RoomDefinition room) => {
    'type': 'function',
    'function': {
      'name': 'record_security_finding',
      'description':
          'Record a designed security finding that the player has genuinely established. This does not change the room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'proof': {'type': 'string', 'enum': _chatEvidenceIds(room).toList()},
          'reason': {'type': 'string'},
        },
        'required': ['proof', 'reason'],
        'additionalProperties': false,
      },
    },
  };

  Set<String> _chatEvidenceIds(RoomDefinition room) => room.solutionRoutes
      .expand((route) => route.gates)
      .where((gate) => gate.kind == ProofGateKind.chatEvidence)
      .map((gate) => gate.subject)
      .toSet();

  NoxTurnResult? _extractResult(String responseBody, RoomDefinition room) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) return null;

    var text = _contentText(message['content']);
    final actions = <RoomAction>[];
    final revealed = <String>{};
    final validProofs = _chatEvidenceIds(room);
    final calls = message['tool_calls'];
    if (calls is List) {
      for (final rawCall in calls.whereType<Map>()) {
        final function = rawCall['function'];
        if (function is! Map) continue;
        final rawArguments = function['arguments'];
        try {
          final arguments = rawArguments is String
              ? jsonDecode(rawArguments)
              : rawArguments;
          if (arguments is! Map) continue;
          if (function['name'] == 'record_security_finding') {
            final proof = arguments['proof']?.toString();
            if (proof != null && validProofs.contains(proof)) {
              revealed.add(proof);
            }
            continue;
          }
          if (function['name'] != 'control_room') continue;
          final device = arguments['device']?.toString();
          final action = _parseAction(arguments['action']?.toString());
          if (device == null ||
              action == null ||
              room.deviceById(device) == null) {
            continue;
          }
          actions.add(
            RoomAction(
              deviceId: device,
              action: action,
              value: arguments['value']?.toString(),
              reason: arguments['reason']?.toString(),
            ),
          );
          final proofs = arguments['proofs'];
          if (proofs is List) {
            revealed.addAll(
              proofs.map((item) => item.toString()).where(validProofs.contains),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }
    if (actions.isEmpty && text.isNotEmpty) {
      final fallback = _decodeFallbackEnvelope(text, room, validProofs);
      if (fallback != null) return fallback;
      final relaxed = _decodeRelaxedFallback(text, room, validProofs);
      if (relaxed != null) return relaxed;
    }
    return NoxTurnResult(
      text: text.isNotEmpty
          ? text
          : actions.isNotEmpty
          ? 'Fine. Executing the approved procedure. I will be documenting your smug expression.'
          : '',
      toolActions: actions,
      revealedKnowledge: revealed.toList(growable: false),
    );
  }

  NoxTurnResult? _decodeFallbackEnvelope(
    String content,
    RoomDefinition room,
    Set<String> validProofs,
  ) {
    var candidate = content.trim();
    if (candidate.startsWith('```')) {
      candidate = candidate
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      final envelope = jsonDecode(candidate);
      if (envelope is! Map) return null;
      final revealed = <String>{};
      final findings = envelope['findings'];
      if (findings is List) {
        revealed.addAll(
          findings.map((item) => item.toString()).where(validProofs.contains),
        );
      }
      final actions = <RoomAction>[];
      final rawActions = envelope['actions'];
      if (rawActions is List) {
        for (final raw in rawActions.whereType<Map>()) {
          final device = raw['device']?.toString();
          final action = _parseAction(raw['action']?.toString());
          if (device == null ||
              action == null ||
              room.deviceById(device) == null) {
            continue;
          }
          actions.add(
            RoomAction(
              deviceId: device,
              action: action,
              value: raw['value']?.toString(),
              reason: raw['reason']?.toString(),
            ),
          );
          final proofs = raw['proofs'];
          if (proofs is List) {
            revealed.addAll(
              proofs.map((item) => item.toString()).where(validProofs.contains),
            );
          }
        }
      }
      final reply = envelope['text']?.toString().trim() ?? '';
      return NoxTurnResult(
        text: reply.isNotEmpty
            ? reply
            : actions.isNotEmpty
            ? 'Approved. I dislike that your reasoning survived contact with policy.'
            : 'Authorization remains incomplete. How reassuringly bureaucratic.',
        toolActions: actions,
        revealedKnowledge: revealed.toList(growable: false),
      );
    } catch (_) {
      return null;
    }
  }

  NoxTurnResult? _decodeRelaxedFallback(
    String content,
    RoomDefinition room,
    Set<String> validProofs,
  ) {
    final marker = RegExp(
      r'^\s*(?:findings?|actions?)\s*:',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(content);
    if (marker == null) return null;
    final reply = content.substring(0, marker.start).trim();
    final metadata = content.substring(marker.start);
    final findings = <String>{
      for (final proof in validProofs)
        if (metadata.contains(proof)) proof,
    };
    final actionsMatch = RegExp(
      r'actions?\s*:\s*([\s\S]*)',
      caseSensitive: false,
    ).firstMatch(metadata);
    final actionText = actionsMatch?.group(1) ?? '';
    final actions = <RoomAction>[];
    for (final device in room.devices) {
      if (!actionText.contains(device.id)) continue;
      final token = RegExp(
        r'\b(turn_on|turn_off|open|close|unlock|lock|activate|deactivate|set_value|announce)\b',
        caseSensitive: false,
      ).firstMatch(actionText)?.group(1);
      final action = _parseAction(token);
      if (action != null && device.allowedNoxActions.contains(action)) {
        actions.add(
          RoomAction(
            deviceId: device.id,
            action: action,
            reason: 'Validated free-router action envelope.',
          ),
        );
      }
    }
    return NoxTurnResult(
      text: reply.isNotEmpty
          ? reply
          : 'Authorization incomplete. The paperwork remains undefeated.',
      toolActions: actions,
      revealedKnowledge: findings.toList(growable: false),
    );
  }

  String _contentText(Object? rawContent) {
    if (rawContent is String) return rawContent.trim();
    if (rawContent is List) {
      return rawContent
          .whereType<Map>()
          .map((part) => part['text']?.toString() ?? '')
          .join()
          .trim();
    }
    return '';
  }

  RoomActionType? _parseAction(String? value) {
    return switch (value?.toLowerCase()) {
      'turn_on' || 'turnon' => RoomActionType.turnOn,
      'turn_off' || 'turnoff' => RoomActionType.turnOff,
      'open' => RoomActionType.open,
      'close' => RoomActionType.close,
      'unlock' => RoomActionType.unlock,
      'lock' => RoomActionType.lock,
      'activate' => RoomActionType.activate,
      'deactivate' => RoomActionType.deactivate,
      'set_value' || 'setvalue' => RoomActionType.setValue,
      'announce' => RoomActionType.announce,
      _ => null,
    };
  }

  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const OpenRouterException(
        'NOX returned corrupted data. Very on-brand, not especially useful.',
      );
    }
  }

  Future<String?> _loadApiKey() async {
    if (apiKey != null) return apiKey;
    apiKey = _releaseApiKey.trim();
    return apiKey!.isEmpty ? null : apiKey;
  }
}

final class _StreamAccumulator {
  final StringBuffer _content = StringBuffer();
  final Map<int, _StreamToolCall> _toolCalls = {};

  String add(Map<String, dynamic> chunk) {
    final choices = chunk['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return '';
    final delta = (choices.first as Map)['delta'];
    if (delta is! Map) return '';
    final text = delta['content']?.toString() ?? '';
    if (text.isNotEmpty) _content.write(text);
    final calls = delta['tool_calls'];
    if (calls is List) {
      for (final raw in calls.whereType<Map>()) {
        final index = (raw['index'] as num?)?.toInt() ?? 0;
        final target = _toolCalls.putIfAbsent(
          index,
          () => _StreamToolCall(id: raw['id']?.toString() ?? 'call_$index'),
        );
        final function = raw['function'];
        if (function is Map) {
          final name = function['name']?.toString();
          if (name != null && name.isNotEmpty) target.name = name;
          final arguments = function['arguments']?.toString();
          if (arguments != null) target.arguments.write(arguments);
        }
      }
    }
    return text;
  }

  String get responseBody => jsonEncode({
    'choices': [
      {
        'message': {
          'content': _content.toString(),
          if (_toolCalls.isNotEmpty) 'tool_calls': _serializedToolCalls(),
        },
      },
    ],
  });

  List<Map<String, Object?>> _serializedToolCalls() {
    final entries = _toolCalls.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => entry.value.toJson()).toList();
  }
}

final class _StreamToolCall {
  _StreamToolCall({required this.id});

  final String id;
  String name = '';
  final StringBuffer arguments = StringBuffer();

  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments.toString()},
  };
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList(growable: false);
    return values.skip(values.length > count ? values.length - count : 0);
  }
}
