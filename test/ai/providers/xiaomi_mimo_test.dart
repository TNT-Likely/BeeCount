import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentcore/agentcore.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/ai/providers/xiaomi_mimo_profile.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final xiaomi = AIServiceProviderConfig.xiaomiDefault.copyWith(apiKey: 'test');

  test(
      'fresh install adds optional providers and keeps all capabilities on GLM',
      () async {
    final bindings = await Future.wait([
      AIProviderManager.getCapabilityBinding(),
      AIProviderManager.getCapabilityBinding(),
    ]);
    for (final binding in bindings) {
      expect(binding.toJson().values, everyElement('zhipu_glm'));
    }
    final providers = await AIProviderManager.getProviders();
    expect(
        providers.map((p) => p.id), ['zhipu_glm', 'xiaomi_mimo', 'deepseek']);
    expect(providers.first.apiKey, isEmpty);
    expect(providers.first.thinkingEnabled, isTrue);
  });

  for (final legacy in [false, true]) {
    test('legacy ${legacy ? 'custom' : 'GLM'} keeps selection/key/models',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_service_provider': legacy ? 'custom' : 'zhipuGLM',
        'ai_glm_api_key': 'glm-key',
        'ai_glm_model': 'glm-saved',
        'ai_custom_api_key': 'custom-key',
        'ai_custom_base_url': 'https://custom/v1',
        'ai_custom_text_model': 'custom-saved',
      });
      final binding = await AIProviderManager.getCapabilityBinding();
      expect(binding.toJson().values,
          everyElement(legacy ? 'custom_migrated' : 'zhipu_glm'));
      final provider =
          await AIProviderManager.getProvider(binding.textProviderId!);
      expect(provider!.apiKey, legacy ? 'custom-key' : 'glm-key');
      expect(provider.textModel, legacy ? 'custom-saved' : 'glm-saved');
    });
  }

  test('v2 upgrade adds Xiaomi without altering custom provider or binding',
      () async {
    final custom = xiaomi.copyWith(
        id: 'custom',
        isBuiltIn: false,
        dialect: AIProviderDialect.openAiCompatible,
        textModel: 'saved');
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2': jsonEncode([custom.toJson()]),
      'ai_capability_binding_v2': jsonEncode(const AICapabilityBinding(
              textProviderId: 'custom',
              visionProviderId: 'custom',
              speechProviderId: 'custom')
          .toJson()),
    });
    expect((await AIProviderManager.getCapabilityBinding()).textProviderId,
        'custom');
    expect((await AIProviderManager.getProvider('custom'))!.toJson(),
        custom.toJson());
    expect((await AIProviderManager.getProviders()).map((p) => p.id),
        contains('xiaomi_mimo'));
  });

  test('missing binding on an existing v2 installation stays on GLM', () async {
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2':
          jsonEncode([AIServiceProviderConfig.zhipuDefault.toJson()]),
    });
    expect((await AIProviderManager.getCapabilityBinding()).textProviderId,
        'zhipu_glm');
  });

  test(
      'JSON, preferences, export/import and cloud preserve dialect and Thinking',
      () async {
    final config = xiaomi.copyWith(thinkingEnabled: false);
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

  test(
      'models authenticate and classify IDs; defaults preserve available saved choice',
      () async {
    final adapter = _Adapter((request) {
      expect(request.method, 'GET');
      expect(request.uri.toString(), '${XiaomiMiMoProfile.baseUrl}/models');
      expect(request.headers['Authorization'], 'Bearer test');
      expect(request.data, isNull);
      return _json({
        'data': [
          for (final id in [
            'mimo-v2.6-pro',
            'mimo-v2.6-flash',
            'mimo-v2.6-pro-ultraspeed',
            'mimo-v2.5-asr',
            'mimo-v2.5-tts',
            'mimo-future',
          ])
            {'id': id}
        ]
      });
    });
    final models = await XiaomiMiMoProfile.discover('test',
        client: Dio()..httpClientAdapter = adapter);
    expect(models.speech, ['mimo-v2.5-asr']);
    expect(models.generation, contains('mimo-future'));
    expect(models.generation, isNot(contains('mimo-v2.5-tts')));
    expect(
        XiaomiMiMoModels.select(
            models.generation, '', XiaomiMiMoProfile.generationModel),
        'mimo-v2.6-flash');
    expect(
        XiaomiMiMoModels.select(models.generation, 'mimo-v2.6-pro',
            XiaomiMiMoProfile.generationModel),
        'mimo-v2.6-pro');
    expect(
        XiaomiMiMoModels.select(
            models.generation, 'retired', XiaomiMiMoProfile.generationModel),
        'mimo-v2.6-flash');
    expect(XiaomiMiMoModels.select([], 'retired', 'preferred'), isEmpty);
    expect(
        XiaomiMiMoModels.select(['future'], 'retired', 'preferred'), 'future');
  });

  for (final status in [401, 403, 500]) {
    test('discovery handles $status without exposing credentials', () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_) => _json({}, status: status));
      await expectLater(
          XiaomiMiMoProfile.discover('test', client: dio),
          throwsA(isA<XiaomiMiMoModelLoadException>()
              .having((e) => e.unauthorized, 'unauthorized', status != 500)));
    });
  }
  test('discovery supports empty model lists and network failure', () async {
    final dio = Dio()..httpClientAdapter = _Adapter((_) => _json({'data': []}));
    expect(
        (await XiaomiMiMoProfile.discover('test', client: dio)).ids, isEmpty);
    dio.httpClientAdapter = _Adapter((request) => throw DioException(
        requestOptions: request, type: DioExceptionType.connectionError));
    await expectLater(XiaomiMiMoProfile.discover('test', client: dio),
        throwsA(isA<XiaomiMiMoModelLoadException>()));
  });

  test(
      'legacy Thinking config initializes both settings and independent values round-trip',
      () {
    for (final value in [false, true]) {
      final legacy = xiaomi.toJson()..remove('assistantThinkingEnabled');
      legacy['thinkingEnabled'] = value;
      final parsed = AIServiceProviderConfig.fromJson(legacy);
      expect(parsed.thinkingEnabled, value);
      expect(parsed.assistantThinkingEnabled, value);
      final split = parsed.copyWith(assistantThinkingEnabled: !value);
      final restored = AIServiceProviderConfig.fromJson(split.toJson());
      expect(restored.thinkingEnabled, value);
      expect(restored.assistantThinkingEnabled, !value);
      expect(
          restored.copyWith(thinkingEnabled: !value).assistantThinkingEnabled,
          !value);
    }
  });

  for (final quick in [true, false]) {
    test(
        'billing=$quick and Assistant=${!quick} use separate request parameters',
        () async {
      final config = xiaomi.copyWith(
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
    test('generation, native probe and tool fallback honor Thinking=$enabled',
        () async {
      final config = xiaomi.copyWith(
          thinkingEnabled: enabled, assistantThinkingEnabled: enabled);
      final requests = <Map>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          final payload = request.data as Map;
          requests.add(Map.of(payload));
          expect(
              payload['thinking'], {'type': enabled ? 'enabled' : 'disabled'});
          expect(payload.containsKey('temperature'), !enabled);
          if (payload['stream'] == true) {
            return _json({'error': 'streaming unsupported'}, status: 400);
          }
          if (payload['tools'] == null) {
            return _json({
              'choices': [
                {
                  'message': {'content': 'hi'}
                }
              ]
            });
          }
          expect(payload['tool_choice'], 'auto');
          return _json({
            'choices': [
              {
                'message': {
                  'reasoning_content': 'reasoning',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'one',
                      'type': 'function',
                      'function': {
                        'name': 'beecount_agent_capability_probe',
                        'arguments': '{"value":"ok"}'
                      }
                    }
                  ],
                },
                'finish_reason': 'tool_calls'
              }
            ]
          });
        });
      final result =
          await AIProviderFactory.validateTextCapability(config, client: dio);
      expect(result.$1, isTrue);
      final capabilities =
          await AIProviderFactory.probeAgentCapabilities(config, client: dio);
      expect(capabilities.nativeToolCalls, AgentCapabilitySupport.supported);
      expect(capabilities.forcedToolChoice, AgentCapabilitySupport.unknown);
      final events = <AgentNativeStreamEvent>[];
      var turn = 0;
      final transport = OpenAiCompatibleNativeToolTransport(
          systemPrompt: '',
          toolDefinitions: const [
            AgentNativeToolDefinition(
                name: 'beecount_agent_capability_probe',
                description: 'probe',
                parameters: {'type': 'object'})
          ],
          toolStream: ({required messages, required tools, logTag}) async* {
            turn++;
            if (turn == 2) {
              expect(messages[2]['reasoning_content'], 'reasoning');
              expect(messages[3]['role'], 'tool');
            }
            yield* AIProviderFactory.chatWithToolsStreamForConfig(
                config: config, messages: messages, tools: tools, client: dio);
          });
      await transport.complete(
          AgentNativeToolRequest(
              runId: 'fallback', userPrompt: 'test', toolResults: []),
          onEvent: events.add);
      await transport.complete(
          AgentNativeToolRequest(
              runId: 'fallback',
              userPrompt: 'test',
              allowToolCalls: false,
              toolResults: [
                AgentNativeToolResult(toolCallId: 'one', content: 'ok')
              ]),
          onEvent: events.add);
      expect(events.whereType<AgentNativeReasoningDelta>().single.text,
          'reasoning');
      final chunk = await AIProviderFactory.chatWithToolsStreamForConfig(
              config: config,
              messages: [],
              tools: [
                {'type': 'function'}
              ],
              client: dio)
          .single;
      expect((chunk['choices'] as List).first['delta']['reasoning_content'],
          'reasoning');
      expect(requests.any((r) => r['stream'] == false), isTrue);
    });
  }

  for (final enabled in [true, false]) {
    test('vision request honors Thinking=$enabled', () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          expect(request.path, '/chat/completions');
          final payload = request.data as Map;
          expect(payload['model'], XiaomiMiMoProfile.generationModel);
          expect(
              payload['thinking'], {'type': enabled ? 'enabled' : 'disabled'});
          expect(payload.containsKey('temperature'), isFalse);
          expect(payload['messages'][0]['content'][1]['image_url']['url'],
              startsWith('data:image/jpeg;base64,'));
          return _json({
            'choices': [
              {
                'message': {'content': '图片说明'}
              }
            ]
          });
        });
      expect(
          (await AIProviderFactory.validateVisionCapability(
                  xiaomi.copyWith(
                      thinkingEnabled: enabled,
                      assistantThinkingEnabled: enabled),
                  client: dio))
              .$1,
          isTrue);
    });
  }

  test('generic generation receives no Xiaomi fields', () async {
    final config = xiaomi.copyWith(
        dialect: AIProviderDialect.openAiCompatible, isBuiltIn: false);
    final dio = Dio()
      ..httpClientAdapter = _Adapter((request) {
        final payload = request.data as Map;
        expect(payload.containsKey('thinking'), isFalse);
        expect(payload['temperature'], 0.1);
        return _json({
          'choices': [
            {
              'message': {'content': 'ok'}
            }
          ]
        });
      });
    await AIProviderFactory.chatWithToolsStreamForConfig(
            config: config, messages: [], tools: [], client: dio)
        .toList();
  });

  test('ASR size guard uses padded Base64 length at the 10 MB boundary', () {
    expect(XiaomiMiMoProfile.maxAsrBase64Bytes, 10000000);
    for (final rawBytes in [0, 1, 2, 3, 7499997, 7499998, 7499999, 7500000]) {
      expect(
          () => XiaomiMiMoProfile.validateAsrSize(rawBytes), returnsNormally);
    }
    // One extra raw byte adds a padded quartet, exceeding 10 MB even though
    // the original file is smaller than 10 MB.
    for (final rawBytes in [7500001, 7500002, 7500003, 10000000]) {
      expect(() => XiaomiMiMoProfile.validateAsrSize(rawBytes),
          throwsA(isA<XiaomiMiMoAudioTooLargeException>()));
    }
  });

  for (final extension in ['wav', 'mp3']) {
    test('oversized $extension ASR fails locally without an HTTP request',
        () async {
      final directory = await Directory.systemTemp.createTemp('mimo-size-test');
      addTearDown(() => directory.delete(recursive: true));
      final audio = File('${directory.path}/audio.$extension');
      final file = await audio.open(mode: FileMode.write);
      try {
        // File length tests the production guard without a large memory buffer.
        await file.truncate(7500001);
      } finally {
        await file.close();
      }
      var requests = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          requests++;
          return _json({});
        });
      await expectLater(
          AIProviderFactory.speechToTextForConfig(xiaomi, audio, client: dio),
          throwsA(isA<AIException>().having(
              (e) => e.message, 'safe error', '音频过长或过大，超过 MiMo ASR 10 MB 限制')));
      expect(requests, 0);
    });
  }

  for (final scenario in [
    'MiMo tools',
    'MiMo finalization',
    'generic finalization'
  ]) {
    test('$scenario preserves tool choice in streaming and fallback payloads',
        () async {
      final generic = scenario == 'generic finalization';
      final withTools = scenario == 'MiMo tools';
      final config = generic
          ? xiaomi.copyWith(
              isBuiltIn: false, dialect: AIProviderDialect.openAiCompatible)
          : xiaomi;
      var requests = 0;
      final tools = <Map<String, dynamic>>[
        if (withTools)
          {
            'type': 'function',
            'function': {'name': 'probe'}
          },
      ];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          requests++;
          final payload = request.data as Map;
          if (withTools) {
            expect(payload['tools'], tools);
            expect(payload['tool_choice'], 'auto');
          } else {
            expect(payload.containsKey('tools'), isFalse);
            if (generic) {
              expect(payload['tool_choice'], 'none');
            } else {
              expect(payload.containsKey('tool_choice'), isFalse);
            }
          }
          if (payload['stream'] == true) {
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
      await AIProviderFactory.chatWithToolsStreamForConfig(
              config: config, messages: [], tools: tools, client: dio)
          .toList();
      expect(requests, 2);
    });
  }

  test(
      'ASR uses WAV/MP3 chat payload and validation shares transport; generic uses Whisper',
      () async {
    final directory = await Directory.systemTemp.createTemp('mimo-test');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = [82, 73, 70, 70, 1, 2, 3];
    for (final extension in ['wav', 'mp3']) {
      final audio =
          await File('${directory.path}/audio.$extension').writeAsBytes(bytes);
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          expect(request.path, '/chat/completions');
          final payload = request.data as Map;
          expect(payload['thinking'], isNull);
          expect(payload['asr_options'], {'language': 'auto'});
          final input = payload['messages'][0]['content'][0];
          expect(input['type'], 'input_audio');
          expect(input['input_audio']['data'],
              'data:${extension == 'wav' ? 'audio/wav' : 'audio/mpeg'};base64,${base64Encode(bytes)}');
          return _json({
            'choices': [
              {
                'message': {'content': '识别文本'}
              }
            ]
          });
        });
      expect(
          await AIProviderFactory.speechToTextForConfig(xiaomi, audio,
              client: dio),
          '识别文本');
      dio.httpClientAdapter = _Adapter((request) {
        expect(request.path, '/chat/completions');
        expect(
            (request.data as Map)['messages'][0]['content'][0]['input_audio']
                ['data'],
            startsWith('data:audio/wav;base64,'));
        return _json({
          'choices': [
            {
              'message': {'content': ''}
            }
          ]
        });
      });
      expect(
          (await AIProviderFactory.validateSpeechCapability(xiaomi,
                  client: dio))
              .$1,
          isTrue);
      dio.httpClientAdapter = _Adapter((request) {
        expect(request.path, '/audio/transcriptions');
        expect(request.data, isA<FormData>());
        return _json({'text': 'whisper'});
      });
      expect(
          await AIProviderFactory.speechToTextForConfig(
              xiaomi.copyWith(
                  isBuiltIn: false,
                  dialect: AIProviderDialect.openAiCompatible),
              audio,
              client: dio),
          'whisper');
    }
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
