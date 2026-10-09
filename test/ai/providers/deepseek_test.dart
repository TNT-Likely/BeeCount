import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentcore/agentcore.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/ai/providers/deepseek_profile.dart';
import 'package:beecount/ai/providers/provider_models.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final deepSeek =
      AIServiceProviderConfig.deepSeekDefault.copyWith(apiKey: 'test');

  test('DeepSeek defaults and insertion preserve existing config and bindings',
      () async {
    expect(deepSeek.supportsText, isTrue);
    expect(deepSeek.supportsVision, isTrue);
    expect(deepSeek.supportsSpeech, isFalse);
    expect(deepSeek.audioModel, isEmpty);
    expect(deepSeek.dialect, AIProviderDialect.deepSeek);
    expect(deepSeek.textModel, 'deepseek-flash');
    expect(deepSeek.visionModel, 'deepseek-flash');
    final mimo = AIServiceProviderConfig.xiaomiDefault.copyWith(
        apiKey: 'saved',
        thinkingEnabled: false,
        assistantThinkingEnabled: true);
    final binding = const AICapabilityBinding(
        textProviderId: 'xiaomi_mimo',
        visionProviderId: 'zhipu_glm',
        speechProviderId: 'xiaomi_mimo');
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2': jsonEncode([mimo.toJson()]),
      'ai_capability_binding_v2': jsonEncode(binding.toJson()),
    });
    expect(
        (await AIProviderManager.getProviders())
            .where((p) => p.id == 'deepseek')
            .length,
        1);
    expect((await AIProviderManager.getProvider(mimo.id))!.toJson(),
        mimo.toJson());
    expect((await AIProviderManager.getCapabilityBinding()).toJson(),
        binding.toJson());
    expect(
        (await AIProviderManager.getProviders())
            .where((p) => p.id == 'deepseek')
            .length,
        1);
  });

  test('discovery classifies advertised modalities, never model names',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter((request) {
        expect(request.uri.toString(), 'https://api.deepseek.com/models');
        expect(request.headers['Authorization'], 'Bearer test');
        return _json({
          'data': [
            {
              'id': 'deepseek-flash',
              'input_modalities': ['text', 'image']
            },
            {
              'id': 'text-only',
              'input_modalities': ['text']
            },
            {
              'id': 'future-asr',
              'input_modalities': ['text', 'image', 'audio']
            },
            {'id': 'unknown'},
          ]
        });
      });
    final models = await DeepSeekProfile.discover('test', client: dio);
    expect(models.text, ['deepseek-flash', 'text-only', 'future-asr']);
    expect(models.vision, ['deepseek-flash', 'future-asr']);
    expect(models.speech, isEmpty);
    expect(ProviderModels.select(models.text, 'text-only', 'deepseek-flash'),
        'text-only');
    expect(ProviderModels.select(models.vision, 'text-only', 'deepseek-flash'),
        'deepseek-flash');
    expect(ProviderModels.select(['future'], 'retired', 'deepseek-flash'),
        'future');
    expect(ProviderModels.select([], 'saved', 'deepseek-flash'), isEmpty);
    dio.httpClientAdapter = _Adapter((_) => _json({'data': []}));
    expect((await DeepSeekProfile.discover('test', client: dio)).text, isEmpty);
  });
  for (final status in [401, 403, 500, null]) {
    test('discovery safely reports HTTP/network error $status', () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          if (status == null) {
            throw DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError);
          }
          return _json({'secret': 'do not display'}, status: status);
        });
      await expectLater(
          DeepSeekProfile.discover('test', client: dio),
          throwsA(isA<ProviderModelLoadException>().having(
              (e) => e.unauthorized,
              'unauthorized',
              status == 401 || status == 403)));
    });
  }

  test(
      'JSON, preferences, export/import and cloud preserve dialect and Thinking',
      () async {
    final config = deepSeek.copyWith(thinkingEnabled: false);
    expect(AIServiceProviderConfig.fromJson(config.toJson()).toJson(),
        config.toJson());
    final exported = AIConfig(providers: [config]);
    final imported = AIConfig.fromMap(exported.toMap());
    expect(imported.providers!.single.toJson(), config.toJson());
    await AIProviderManager.getProviders();
    await AIProviderManager.updateProvider(config);
    expect((await AIProviderManager.getProvider(config.id))!.thinkingEnabled,
        isFalse);
    final snapshot = await AIProviderManager.snapshotForSync();
    SharedPreferences.setMockInitialValues({});
    await AIProviderManager.applyFromServer(snapshot);
    expect((await AIProviderManager.getProvider(config.id))!.toJson(),
        config.toJson());
    expect(
        AIServiceProviderConfig.fromJson(
                config.toJson()..['dialect'] = 'future')
            .dialect,
        AIProviderDialect.openAiCompatible);
    final old = config.toJson()
      ..remove('dialect')
      ..remove('thinkingEnabled');
    final parsed = AIServiceProviderConfig.fromJson(old);
    expect(parsed.dialect, AIProviderDialect.openAiCompatible);
    expect(parsed.thinkingEnabled, isTrue);
    expect(
        AIServiceProviderConfig.fromJson(
                config.toJson()..remove('thinkingEnabled'))
            .thinkingEnabled,
        isTrue);
  });

  for (final quick in [true, false]) {
    test(
        'billing=$quick and Assistant=${!quick} use separate request parameters',
        () async {
      final config = deepSeek.copyWith(
          thinkingEnabled: quick, assistantThinkingEnabled: !quick);
      final bodies = <Map>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          bodies.add(Map.of(request.data as Map));
          if ((request.data as Map)['stream'] == true) {
            return _json({'error': 'streaming unsupported'}, status: 400);
          }
          return _json({
            'choices': [
              {
                'message': {'content': 'ok'}
              }
            ]
          });
        });
      await AIProviderFactory.validateTextCapability(config, client: dio);
      expect(
          bodies.first['thinking'], {'type': quick ? 'enabled' : 'disabled'});
      expect(bodies.first.containsKey('temperature'), !quick);
      bodies.clear();
      await AIProviderFactory.chatWithToolsStreamForConfig(
              config: config,
              messages: [
                {'role': 'user', 'content': 'test'}
              ],
              tools: [],
              client: dio)
          .toList();
      for (final body in bodies) {
        expect(body['thinking'], {'type': !quick ? 'enabled' : 'disabled'});
        expect(body.containsKey('temperature'), quick);
      }
    });
  }

  for (final enabled in [true, false]) {
    test(
        'probe uses auto and only structured tool calls with Thinking=$enabled',
        () async {
      var structured = true;
      var requests = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          requests++;
          final body = request.data as Map;
          expect(body.containsKey('reasoning_effort'), isFalse);
          expect(body['tool_choice'], 'auto');
          expect(body['thinking'], {'type': enabled ? 'enabled' : 'disabled'});
          expect(body.containsKey('temperature'), !enabled);
          return _json({
            'choices': [
              {
                'message': {
                  'content': '<DSML>beecount_agent_capability_probe</DSML>',
                  'reasoning_content':
                      'I called beecount_agent_capability_probe',
                  if (structured)
                    'tool_calls': [
                      {
                        'id': 'probe',
                        'type': 'function',
                        'function': {
                          'name': 'beecount_agent_capability_probe',
                          'arguments': '{"value":"ok"}'
                        }
                      }
                    ],
                }
              }
            ]
          });
        });
      final config = deepSeek.copyWith(assistantThinkingEnabled: enabled);
      final result = await AIProviderFactory.probeAgentCapabilities(config,
          client: dio, probeStreaming: false);
      expect(result.nativeToolCalls, AgentCapabilitySupport.supported);
      expect(requests, 1);
      structured = false;
      final prose = await AIProviderFactory.probeAgentCapabilities(config,
          client: dio, probeStreaming: false);
      expect(prose.nativeToolCalls, AgentCapabilitySupport.unsupported);
    });
  }

  for (final streaming in [false, true]) {
    test(
        'two tool rounds replay all reasoning/tool calls and finalization uses none streaming=$streaming',
        () async {
      var round = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          final body = request.data as Map;
          // Exercise the existing fallback and serialization boundary as well.
          if (!streaming && body['stream'] == true) {
            return _json({'error': 'streaming unsupported'}, status: 400);
          }
          round++;
          final history = (body['messages'] as List)
              .where((m) => m['role'] == 'assistant')
              .toList();
          expect(history.length, round - 1);
          expect(
              (body['messages'] as List)
                  .where((m) => m['role'] == 'assistant' || m['role'] == 'tool')
                  .map((m) => m['role']),
              [
                for (var i = 0; i < round - 1; i++) ...['assistant', 'tool']
              ]);
          for (var i = 0; i < history.length; i++) {
            expect(history[i]['content'], isNull);
            expect(history[i]['reasoning_content'], 'reasoning ${i + 1}');
            expect(history[i]['tool_calls'][0]['id'], 'call${i + 1}');
          }
          final tools = (body['messages'] as List)
              .where((m) => m['role'] == 'tool')
              .toList();
          expect(tools.length, round - 1);
          for (var i = 0; i < tools.length; i++) {
            expect(tools[i]['tool_call_id'], 'call${i + 1}');
          }
          expect(body.containsKey('reasoning_effort'), isFalse);
          expect(body['tool_choice'], round == 3 ? 'none' : 'auto');
          expect(body.containsKey('tools'), round != 3);
          final reply = <String, dynamic>{
            'choices': [
              {
                if (streaming)
                  'delta': {
                    'reasoning_content': 'reasoning $round',
                    'content': round == 3 ? 'final answer' : null,
                    if (round < 3)
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'call$round',
                          'type': 'function',
                          'function': {'name': 'read', 'arguments': '{}'}
                        }
                      ],
                  },
                if (!streaming)
                  'message': {
                    'reasoning_content': 'reasoning $round',
                    'content': round == 3 ? 'final answer' : null,
                    if (round < 3)
                      'tool_calls': [
                        {
                          'id': 'call$round',
                          'type': 'function',
                          'function': {'name': 'read', 'arguments': '{}'}
                        }
                      ],
                  },
                'finish_reason': round == 3 ? 'stop' : 'tool_calls'
              }
            ]
          };
          return streaming
              ? ResponseBody.fromString(
                  'data: ${jsonEncode(reply)}\n\ndata: [DONE]\n\n', 200,
                  headers: {
                      Headers.contentTypeHeader: ['text/event-stream']
                    })
              : _json(reply);
        });
      final transport = OpenAiCompatibleNativeToolTransport(
          systemPrompt: '',
          toolDefinitions: const [
            AgentNativeToolDefinition(
                name: 'read',
                description: 'safe read',
                parameters: {'type': 'object'})
          ],
          toolStream: ({required messages, required tools, logTag}) =>
              AIProviderFactory.chatWithToolsStreamForConfig(
                  config: deepSeek,
                  messages: messages,
                  tools: tools,
                  client: dio));
      final events = <AgentNativeStreamEvent>[];
      AgentNativeModelResponse? result;
      for (var i = 0; i < 3; i++) {
        result = await transport.complete(
            AgentNativeToolRequest(
                runId: 'deepseek',
                userPrompt: 'test',
                allowToolCalls: i < 2,
                toolResults: [
                  if (i > 0)
                    AgentNativeToolResult(
                        toolCallId: 'call$i', content: 'safe result')
                ]),
            onEvent: events.add);
      }
      expect(
          result,
          isA<AgentNativeFinalTextResponse>()
              .having((r) => r.text, 'text', 'final answer'));
      expect(round, 3);
      expect(events.whereType<AgentNativeReasoningDelta>().map((e) => e.text),
          ['reasoning 1', 'reasoning 2', 'reasoning 3']);
    });
  }

  for (final thinking in [false, true]) {
    test('single image vision honors quick billing Thinking=$thinking',
        () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          expect(request.path, '/chat/completions');
          final body = request.data as Map;
          expect(body['model'], 'deepseek-flash');
          expect(body['thinking'], {'type': thinking ? 'enabled' : 'disabled'});
          final parts = body['messages'][0]['content'] as List;
          expect(parts.length, 2);
          expect(parts[1]['type'], 'image_url');
          expect(parts[1]['image_url']['url'],
              startsWith('data:image/jpeg;base64,'));
          return _json({
            'choices': [
              {
                'message': {'content': 'image context'}
              }
            ]
          });
        });
      expect(
          await AIProviderFactory.validateVisionCapability(
              deepSeek.copyWith(thinkingEnabled: thinking),
              client: dio),
          (true, null));
    });
  }

  test('DeepSeek never makes speech requests even with an invalid audio model',
      () async {
    final dio = Dio()
      ..httpClientAdapter =
          _Adapter((_) => throw StateError('must not request ASR'));
    await expectLater(
        AIProviderFactory.speechToTextForConfig(
            deepSeek.copyWith(audioModel: 'deepseek-flash'), File('unused.wav'),
            client: dio),
        throwsA(isA<Exception>()));
    expect(deepSeek.copyWith(audioModel: 'deepseek-flash').supportsSpeech,
        isFalse);
  });

  test('custom DeepSeek-looking config keeps generic payload semantics',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter((request) {
        final body = request.data as Map;
        expect(body.containsKey('thinking'), isFalse);
        expect(body.containsKey('reasoning_effort'), isFalse);
        expect(body['temperature'], 0.1);
        return _json({
          'choices': [
            {
              'message': {'content': 'ok'}
            }
          ]
        });
      });
    await AIProviderFactory.chatWithToolsStreamForConfig(
            config: deepSeek.copyWith(
                dialect: AIProviderDialect.openAiCompatible, isBuiltIn: false),
            messages: [],
            tools: [],
            client: dio)
        .toList();
  });
}

ResponseBody _json(Object data, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await requestStream?.drain<void>();
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
