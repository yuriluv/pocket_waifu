// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_config.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';
import '../services/prompt_builder.dart';
import '../services/release_log_service.dart';

class ApiCancelledException implements Exception {
  const ApiCancelledException([this.message = '요청이 취소되었습니다.']);

  final String message;

  @override
  String toString() => message;
}

class ApiRequestHandle {
  final http.Client _client = http.Client();
  final Completer<void> _cancelled = Completer<void>();
  bool _isCancelled = false;
  bool _isClosed = false;

  bool get isCancelled => _isCancelled;
  http.Client get client => _client;
  Future<void> get cancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    close();
  }

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _client.close();
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const ApiCancelledException();
    }
  }
}

class ApiService {
  final PromptBuilder _promptBuilder = PromptBuilder();

  static const String _anthropicVersion = '2023-06-01';

  ApiRequestHandle createRequestHandle() => ApiRequestHandle();

  ///
  ///
  Future<String> sendMessageWithConfig({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    debugPrint('╔════════════════════════════════════════════════════════════');
    debugPrint('║ === API 호출 디버그 (v2.0.1) ===');
    debugPrint('║ Config ID: ${apiConfig.id}');
    debugPrint('║ Config Name: ${apiConfig.name}');
    debugPrint('║ Base URL: ${apiConfig.baseUrl}');
    debugPrint('║ Model: ${apiConfig.modelName}');
    debugPrint(
      '║ API Key (앞 10자): ${apiConfig.apiKey.substring(0, min(10, apiConfig.apiKey.length))}...',
    );
    debugPrint('║ Format: ${apiConfig.format.name}');
    debugPrint('║ Messages count: ${messages.length}');
    debugPrint('╚════════════════════════════════════════════════════════════');

    if (apiConfig.apiKey.isEmpty) {
      throw Exception('API 키가 설정되지 않았습니다. 설정에서 API 프리셋을 확인해주세요.');
    }

    final bool isAnthropic =
        apiConfig.format == ApiFormat.anthropic ||
        apiConfig.baseUrl.contains('anthropic.com') ||
        apiConfig.customHeaders.containsKey('anthropic-version');

    if (isAnthropic) {
      return await _sendToAnthropic(
        apiConfig: apiConfig,
        messages: messages,
        settings: settings,
        requestHandle: requestHandle,
      );
    } else {
      return await _sendToOpenAICompatible(
        apiConfig: apiConfig,
        messages: messages,
        settings: settings,
        requestHandle: requestHandle,
      );
    }
  }

  Future<String> _sendToOpenAICompatible({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    final Map<String, dynamic> requestBody = {
      'model': apiConfig.modelName,
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'max_tokens': settings.maxTokens,
      'frequency_penalty': settings.frequencyPenalty,
      'presence_penalty': settings.presencePenalty,
    };

    requestBody.addAll(apiConfig.additionalParams);

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiConfig.apiKey}',
    };

    headers.addAll(apiConfig.customHeaders);

    debugPrint('>>> OpenAI Compatible API 요청');
    debugPrint('>>> URL: ${apiConfig.baseUrl}');
    debugPrint('>>> Headers: ${headers.keys.join(', ')}');

    await ReleaseLogService.instance.info(
      'api_request',
      'OpenAI compatible request started',
      payload: {
        'provider': apiConfig.format.name,
        'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
        'event': 'request_start',
      },
    );

    final client = requestHandle?.client ?? http.Client();

    try {
      final response = await _awaitWithCancellation(
        request: client.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        ),
        requestHandle: requestHandle,
      );

      debugPrint('>>> Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        return content.trim();
      } else {
        String errorMessage = '알 수 없는 오류';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage =
              errorData['error']?['message'] ??
              errorData['message'] ??
              response.body;
        } catch (_) {
          errorMessage = response.body;
        }
        debugPrint('>>> API Error: $errorMessage');
        await ReleaseLogService.instance.warning(
          'api_response',
          'OpenAI compatible request failed',
          payload: {
            'provider': apiConfig.format.name,
            'httpStatus': response.statusCode.toString(),
            'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
            'reason': _safeReason(errorMessage),
          },
        );
        throw Exception('API 오류 (${response.statusCode}): $errorMessage');
      }
    } on ApiCancelledException {
      rethrow;
    } catch (e) {
      debugPrint('>>> Exception: $e');
      await ReleaseLogService.instance.error(
        'api_exception',
        'OpenAI compatible request exception',
        payload: {
          'provider': apiConfig.format.name,
          'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
          'errorType': e.runtimeType.toString(),
          'reason': _safeReason(e.toString()),
        },
      );
      if (e is Exception) rethrow;
      throw Exception('API 요청 실패: $e');
    } finally {
      if (requestHandle == null) {
        client.close();
      } else {
        requestHandle.close();
      }
    }
  }

  Future<String> _sendToAnthropic({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    String? systemMessage;
    final List<Map<String, String>> chatMessages = [];

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        if (systemMessage == null) {
          systemMessage = msg['content'];
        } else {
          systemMessage = '$systemMessage\n\n${msg['content']}';
        }
      } else {
        chatMessages.add(msg);
      }
    }

    if (chatMessages.isNotEmpty && chatMessages.first['role'] == 'assistant') {
      chatMessages.insert(0, {'role': 'user', 'content': '(대화 시작)'});
    }

    final Map<String, dynamic> requestBody = {
      'model': apiConfig.modelName,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'messages': chatMessages,
    };

    if (systemMessage != null && systemMessage.isNotEmpty) {
      requestBody['system'] = systemMessage;
    }

    requestBody.addAll(apiConfig.additionalParams);

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiConfig.apiKey,
      'anthropic-version': _anthropicVersion,
    };

    headers.addAll(apiConfig.customHeaders);

    debugPrint('>>> Anthropic API 요청');
    debugPrint('>>> URL: ${apiConfig.baseUrl}');
    debugPrint('>>> Model: ${apiConfig.modelName}');

    await ReleaseLogService.instance.info(
      'api_request',
      'Anthropic request started',
      payload: {
        'provider': apiConfig.format.name,
        'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
        'event': 'request_start',
      },
    );

    final client = requestHandle?.client ?? http.Client();

    try {
      final response = await _awaitWithCancellation(
        request: client.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        ),
        requestHandle: requestHandle,
      );

      debugPrint('>>> Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['content'][0]['text'];
        return content.trim();
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMessage =
            errorData['error']?['message'] ?? '알 수 없는 오류';
        debugPrint('>>> Anthropic Error: $errorMessage');
        await ReleaseLogService.instance.warning(
          'api_response',
          'Anthropic request failed',
          payload: {
            'provider': apiConfig.format.name,
            'httpStatus': response.statusCode.toString(),
            'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
            'reason': _safeReason(errorMessage),
          },
        );
        throw Exception(
          'Anthropic API 오류 (${response.statusCode}): $errorMessage',
        );
      }
    } on ApiCancelledException {
      rethrow;
    } catch (e) {
      debugPrint('>>> Exception: $e');
      await ReleaseLogService.instance.error(
        'api_exception',
        'Anthropic request exception',
        payload: {
          'provider': apiConfig.format.name,
          'endpointHost': _safeEndpointHost(apiConfig.baseUrl),
          'errorType': e.runtimeType.toString(),
          'reason': _safeReason(e.toString()),
        },
      );
      if (e is Exception) rethrow;
      throw Exception('Anthropic API 요청 실패: $e');
    } finally {
      if (requestHandle == null) {
        client.close();
      } else {
        requestHandle.close();
      }
    }
  }

  String _safeEndpointHost(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return 'invalid_url';
    }
    return uri.host;
  }

  String _safeReason(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<T> _awaitWithCancellation<T>({
    required Future<T> request,
    ApiRequestHandle? requestHandle,
  }) async {
    if (requestHandle == null) {
      return request;
    }

    requestHandle.throwIfCancelled();

    final response = await Future.any<T>([
      request,
      requestHandle.cancelled.then<T>((_) {
        throw const ApiCancelledException();
      }),
    ]);

    requestHandle.throwIfCancelled();
    return response;
  }

  ///
  Future<String> sendMessageWithBlocks({
    required ApiConfig? apiConfig,
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    required AppSettings settings,
    int pastMessageCount = 10,
    ApiRequestHandle? requestHandle,
  }) async {
    if (apiConfig == null) {
      return await _sendMessageWithBlocksLegacy(
        blocks: blocks,
        pastMessages: pastMessages,
        currentInput: currentInput,
        settings: settings,
        pastMessageCount: pastMessageCount,
        requestHandle: requestHandle,
      );
    }

    final bool hasFirstSystemPrompt = apiConfig.hasFirstSystemPrompt;
    final bool requiresAlternateRole = apiConfig.requiresAlternateRole;

    debugPrint('>>> sendMessageWithBlocks - Config: ${apiConfig.name}');
    debugPrint(
      '>>> hasFirstSystemPrompt: $hasFirstSystemPrompt, requiresAlternateRole: $requiresAlternateRole',
    );

    final formattedMessages = _promptBuilder.buildMessagesForApi(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
    );

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  ///
  Future<(bool, String)> testConnection(ApiConfig apiConfig) async {
    debugPrint('╔════════════════════════════════════════════════════════════');
    debugPrint('║ === API 연결 테스트 시작 ===');
    debugPrint('║ Config: ${apiConfig.name}');
    debugPrint('║ URL: ${apiConfig.baseUrl}');
    debugPrint('║ Model: ${apiConfig.modelName}');
    debugPrint('╚════════════════════════════════════════════════════════════');

    if (apiConfig.apiKey.isEmpty) {
      return (false, 'API 키가 설정되지 않았습니다.');
    }

    if (apiConfig.baseUrl.isEmpty) {
      return (false, 'Base URL이 설정되지 않았습니다.');
    }

    try {
      final bool isAnthropic =
          apiConfig.format == ApiFormat.anthropic ||
          apiConfig.baseUrl.contains('anthropic.com');

      if (isAnthropic) {
        final headers = {
          'Content-Type': 'application/json',
          'x-api-key': apiConfig.apiKey,
          'anthropic-version': _anthropicVersion,
          ...apiConfig.customHeaders,
        };

        final response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode({
            'model': apiConfig.modelName,
            'max_tokens': 10,
            'messages': [
              {'role': 'user', 'content': 'test'},
            ],
          }),
        );

        if (response.statusCode == 200) {
          return (true, '연결 성공! (Anthropic)');
        } else {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['error']?['message'] ?? response.body;
          return (false, 'HTTP ${response.statusCode}: $errorMsg');
        }
      } else {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${apiConfig.apiKey}',
          ...apiConfig.customHeaders,
        };

        final response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode({
            'model': apiConfig.modelName,
            'messages': [
              {'role': 'user', 'content': 'test'},
            ],
            'max_tokens': 10,
          }),
        );

        if (response.statusCode == 200) {
          return (true, '연결 성공!');
        } else {
          String errorMsg = response.body;
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['error']?['message'] ?? response.body;
          } catch (_) {}
          return (false, 'HTTP ${response.statusCode}: $errorMsg');
        }
      }
    } catch (e) {
      debugPrint('>>> 연결 테스트 오류: $e');
      return (false, '연결 오류: $e');
    }
  }

  // ============================================================================
  // ============================================================================

  ///
  ///
  Future<String> sendMessage({
    required List<Message> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    final apiConfig = _createLegacyApiConfig(settings);

    final List<Map<String, String>> formattedMessages = messages.map((msg) {
      return {'role': msg.roleString, 'content': msg.content};
    }).toList();

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  Future<String> _sendMessageWithBlocksLegacy({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    required AppSettings settings,
    int pastMessageCount = 10,
    ApiRequestHandle? requestHandle,
  }) async {
    final apiConfig = _createLegacyApiConfig(settings);

    bool hasFirstSystemPrompt = true;
    bool requiresAlternateRole = false;

    switch (settings.apiProvider) {
      case ApiProvider.copilot:
        hasFirstSystemPrompt = true;
        requiresAlternateRole = true;
        break;
      case ApiProvider.openai:
        hasFirstSystemPrompt = true;
        requiresAlternateRole = false;
        break;
      case ApiProvider.anthropic:
        hasFirstSystemPrompt = false;
        requiresAlternateRole = true;
        break;
    }

    final formattedMessages = _promptBuilder.buildMessagesForApi(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
    );

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  ApiConfig _createLegacyApiConfig(AppSettings settings) {
    switch (settings.apiProvider) {
      case ApiProvider.openai:
        return ApiConfig.openaiDefault().copyWith(
          apiKey: settings.openaiApiKey,
          modelName: settings.openaiModel,
        );
      case ApiProvider.anthropic:
        return ApiConfig.anthropicDefault().copyWith(
          apiKey: settings.anthropicApiKey,
          modelName: settings.anthropicModel,
        );
      case ApiProvider.copilot:
        return ApiConfig.copilotDefault().copyWith(
          apiKey: settings.copilotApiKey,
          modelName: settings.copilotModel,
        );
    }
  }
}
