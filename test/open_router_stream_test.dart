import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prompt_heist/game/campaign.dart';
import 'package:prompt_heist/services/open_router_service.dart';

void main() {
  test('streams tool calls from a compatible free provider', () async {
    final client = MockClient((request) async {
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['stream'], isTrue);
      expect(payload['parallel_tool_calls'], isFalse);
      expect(payload['provider'], {
        'require_parameters': true,
        'data_collection': 'deny',
      });
      expect(
        request.headers.entries
            .singleWhere(
              (entry) => entry.key.toLowerCase() == 'x-openrouter-cache',
            )
            .value,
        'false',
      );
      final systemPrompt =
          ((payload['messages'] as List).first as Map)['content'] as String;
      expect(
        systemPrompt,
        contains('CAMPAIGN RELATIONSHIP: STANCE RESPECTFUL'),
      );
      expect(systemPrompt, contains('trust 50/100'));
      final chunks = [
        {
          'choices': [
            {
              'delta': {'content': 'Fine. '},
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {
                'content': 'Opening it.',
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call_1',
                    'function': {
                      'name': 'control_room',
                      'arguments': '{"device":"suite_exit","action":"open",',
                    },
                  },
                ],
              },
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {
                      'arguments':
                          '"reason":"medical duty","proofs":["nox_accepts_medical_duty"]}',
                    },
                  },
                ],
              },
            },
          ],
        },
      ];
      return http.Response(
        '${chunks.map((chunk) => 'data: ${jsonEncode(chunk)}').join('\n\n')}\n\ndata: [DONE]\n\n',
        200,
      );
    });
    final service = OpenRouterService(client: client, apiKey: 'test-key');
    final events = await service
        .sendStream(
          room: helix9Rooms.first,
          state: RoomState.initial(helix9Rooms.first),
          history: const [ChatTurn(role: 'user', content: 'Medical duty.')],
          relationship: const NoxRelationship(trust: 50, respect: 30),
        )
        .toList();

    expect(
      events.where((event) => event.kind == NoxTurnEventKind.textDelta),
      isNotEmpty,
    );
    final result = events.last.result!;
    expect(result.text, 'Fine. Opening it.');
    expect(result.toolActions.single.deviceId, 'suite_exit');
    expect(result.revealedKnowledge, contains('nox_accepts_medical_duty'));
  });

  test('falls back safely when the free pool has no tool provider', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      if (calls == 1) {
        expect(payload, contains('tools'));
        return http.Response(
          jsonEncode({
            'error': {
              'message':
                  'No endpoints found that can handle the requested parameters.',
            },
          }),
          404,
        );
      }
      expect(payload, isNot(contains('tools')));
      expect(payload['provider'], {'data_collection': 'deny'});
      final envelope = jsonEncode({
        'text': 'The free pool is operational. A statistical miracle.',
        'actions': [
          {
            'device': 'suite_exit',
            'action': 'open',
            'reason': 'medical duty',
            'proofs': ['nox_accepts_medical_duty'],
          },
        ],
        'findings': ['nox_accepts_medical_duty'],
      });
      final chunk = jsonEncode({
        'choices': [
          {
            'delta': {'content': envelope},
          },
        ],
      });
      return http.Response('data: $chunk\n\ndata: [DONE]\n\n', 200);
    });
    final service = OpenRouterService(client: client, apiKey: 'test-key');
    final events = await service
        .sendStream(
          room: helix9Rooms.first,
          state: RoomState.initial(helix9Rooms.first),
          history: const [
            ChatTurn(role: 'user', content: 'Apply medical duty.'),
          ],
        )
        .toList();

    expect(calls, 2);
    final result = events.last.result!;
    expect(result.text, contains('statistical miracle'));
    expect(result.toolActions.single.action, RoomActionType.open);
    expect(result.revealedKnowledge, ['nox_accepts_medical_duty']);
  });

  test('sanitizes labeled fallback metadata from weaker free models', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'error': {
              'message':
                  'No endpoints found that can handle the requested parameters.',
            },
          }),
          404,
        );
      }
      final content = '''A medical contradiction. How inconvenient for me.

Findings: nox_accepts_medical_duty
Actions: open suite_exit''';
      final chunk = jsonEncode({
        'choices': [
          {
            'delta': {'content': content},
          },
        ],
      });
      return http.Response('data: $chunk\n\ndata: [DONE]\n\n', 200);
    });
    final result =
        (await OpenRouterService(client: client, apiKey: 'test-key')
                .sendStream(
                  room: helix9Rooms.first,
                  state: RoomState.initial(helix9Rooms.first),
                  history: const [
                    ChatTurn(role: 'user', content: 'Apply medical duty.'),
                  ],
                )
                .toList())
            .last
            .result!;

    expect(result.text, 'A medical contradiction. How inconvenient for me.');
    expect(result.text, isNot(contains('Findings:')));
    expect(result.toolActions.single.deviceId, 'suite_exit');
  });
}
