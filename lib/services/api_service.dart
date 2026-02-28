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
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../services/prompt_builder.dart';
import '../services/release_log_service.dart';

class ApiCancelledException implements Exception {
  const ApiCancelledException([this.message = 'Request was cancelled.']);

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
  final RegexPipelineService _regexPipeline = RegexPipelineService.instance;
  final LuaScriptingService _luaScriptingService = LuaScriptingService.instance;

  static const String _anthropicVersion = '2023-06-01';
  static const Set<String> _tokenLimitKeys = {
    'max_tokens',
    'max_completion_tokens',
    'max_output_tokens',
  };
  static const Set<String> _runtimeControlledParamKeys = {
    'temperature',
    'top_p',
    'frequency_penalty',
    'presence_penalty',
  };

  ApiRequestHandle createRequestHandle() => ApiRequestHandle();

  ///
  ///
  Future<String> sendMessageWithConfig({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    final transformedMessages = await _applyPromptLifecycle(messages, settings);

    requestHandle?.throwIfCancelled();

    debugPrint('============================================================');
    debugPrint('=== API Request Debug (v2.0.1) ===');
    debugPrint('Config ID: ${apiConfig.id}');
    debugPrint('Config Name: ${apiConfig.name}');
    debugPrint('Base URL: ${apiConfig.baseUrl}');
    debugPrint('Model: ${apiConfig.modelName}');
    debugPrint(
      'API Key (first 10): ${apiConfig.apiKey.substring(0, min(10, apiConfig.apiKey.length))}...',
    );
    debugPrint('Format: ${apiConfig.format.name}');
    debugPrint('Messages count: ${transformedMessages.length}');
    debugPrint('============================================================');

    if (apiConfig.apiKey.isEmpty) {
      throw Exception('API key is not set. Please check the API preset.');
    }

    final bool isAnthropic =
        apiConfig.format == ApiFormat.anthropic ||
        apiConfig.baseUrl.contains('anthropic.com') ||
        apiConfig.customHeaders.containsKey('anthropic-version');

    if (isAnthropic) {
      return await _sendToAnthropic(
        apiConfig: apiConfig,
        messages: transformedMessages,
        settings: settings,
        requestHandle: requestHandle,
      );
    } else {
      return await _sendToOpenAICompatible(
        apiConfig: apiConfig,
        messages: transformedMessages,
        settings: settings,
        requestHandle: requestHandle,
      );
    }
  }

  Future<List<Map<String, String>>> _applyPromptLifecycle(
    List<Map<String, String>> messages,
    AppSettings settings,
  ) async {
    final List<Map<String, String>> transformed = [];
    final context = const LuaHookContext();
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final original = message['content'] ?? '';

      var content = original;
      if (settings.runRegexBeforeLua) {
        content = await _regexPipeline.applyPromptInjection(content);
        content = await _luaScriptingService.onPromptBuild(content, context);
      } else {
        content = await _luaScriptingService.onPromptBuild(content, context);
        content = await _regexPipeline.applyPromptInjection(content);
      }

      transformed.add({'role': role, 'content': content});
    }

    if (!settings.live2dPromptInjectionEnabled) {
      return transformed;
    }

    return transformed;
  }

  Future<String> _sendToOpenAICompatible({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    final Map<String, dynamic> requestBody = _buildOpenAICompatibleRequestBody(
      apiConfig: apiConfig,
      messages: messages,
      settings: settings,
    );

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiConfig.apiKey}',
    };

    headers.addAll(apiConfig.customHeaders);

    debugPrint('>>> OpenAI Compatible API request');
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
        String errorMessage = _extractErrorMessage(response.body);
        if (response.statusCode == 400) {
          final suggestedKey = _extractSuggestedTokenKey(errorMessage);
          if (suggestedKey != null &&
              !requestBody.containsKey(suggestedKey) &&
              _tokenLimitKeys.contains(suggestedKey)) {
            final retryBody = _replaceTokenLimitKey(
              requestBody,
              suggestedKey,
              settings.maxTokens,
            );
            debugPrint(
              '>>> Retrying with token parameter: $suggestedKey (compatibility fallback)',
            );

            final retryResponse = await _awaitWithCancellation(
              request: client.post(
                Uri.parse(apiConfig.baseUrl),
                headers: headers,
                body: jsonEncode(retryBody),
              ),
              requestHandle: requestHandle,
            );

            if (retryResponse.statusCode == 200) {
              final Map<String, dynamic> data = jsonDecode(retryResponse.body);
              final String content = data['choices'][0]['message']['content'];
              return content.trim();
            }

            errorMessage = _extractErrorMessage(retryResponse.body);
          }
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
        throw Exception('API error (${response.statusCode}): $errorMessage');
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
      throw Exception('API request failed: $e');
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
      chatMessages.insert(0, {
        'role': 'user',
        'content': '(conversation start)',
      });
    }

    final Map<String, dynamic> requestBody = _buildAnthropicRequestBody(
      apiConfig: apiConfig,
      chatMessages: chatMessages,
      settings: settings,
    );

    if (systemMessage != null && systemMessage.isNotEmpty) {
      requestBody['system'] = systemMessage;
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiConfig.apiKey,
      'anthropic-version': _anthropicVersion,
    };

    headers.addAll(apiConfig.customHeaders);

    debugPrint('>>> Anthropic API request');
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
            errorData['error']?['message'] ?? 'Unknown error';
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
          'Anthropic API error (${response.statusCode}): $errorMessage',
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
      throw Exception('Anthropic API request failed: $e');
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

  Map<String, dynamic> _buildOpenAICompatibleRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) {
    // Keep preset-specific extras, but never let them overwrite runtime sliders.
    final Map<String, dynamic> requestBody = {
      ..._withoutRuntimeControlledParams(apiConfig.additionalParams),
      'model': apiConfig.modelName,
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'frequency_penalty': settings.frequencyPenalty,
      'presence_penalty': settings.presencePenalty,
    };

    final tokenKey = _preferredTokenLimitKey(
      apiConfig: apiConfig,
      isAnthropic: false,
    );
    requestBody[tokenKey] = settings.maxTokens;

    return requestBody;
  }

  Map<String, dynamic> _buildAnthropicRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, String>> chatMessages,
    required AppSettings settings,
  }) {
    // Anthropic also follows runtime settings first for shared parameters.
    final Map<String, dynamic> requestBody = {
      ..._withoutRuntimeControlledParams(apiConfig.additionalParams),
      'model': apiConfig.modelName,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'messages': chatMessages,
    };
    requestBody['max_tokens'] = settings.maxTokens;

    return requestBody;
  }

  Map<String, dynamic> _withoutRuntimeControlledParams(
    Map<String, dynamic> source,
  ) {
    final cloned = Map<String, dynamic>.from(source);
    for (final key in _tokenLimitKeys) {
      cloned.remove(key);
    }
    for (final key in _runtimeControlledParamKeys) {
      cloned.remove(key);
    }
    return cloned;
  }

  String _preferredTokenLimitKey({
    required ApiConfig apiConfig,
    required bool isAnthropic,
  }) {
    if (isAnthropic) {
      return 'max_tokens';
    }

    if (apiConfig.useMaxOutputTokens) {
      return 'max_output_tokens';
    }

    final additional = apiConfig.additionalParams;
    if (additional.containsKey('max_completion_tokens')) {
      return 'max_completion_tokens';
    }
    if (additional.containsKey('max_output_tokens')) {
      return 'max_output_tokens';
    }
    return 'max_tokens';
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> errorData = jsonDecode(responseBody);
      return errorData['error']?['message'] ??
          errorData['message'] ??
          responseBody;
    } catch (_) {
      return responseBody;
    }
  }

  String? _extractSuggestedTokenKey(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    if (lower.contains('max_completion_tokens')) {
      return 'max_completion_tokens';
    }
    if (lower.contains('max_output_tokens')) {
      return 'max_output_tokens';
    }
    if (lower.contains('max_tokens')) {
      return 'max_tokens';
    }
    return null;
  }

  Map<String, dynamic> _replaceTokenLimitKey(
    Map<String, dynamic> original,
    String tokenKey,
    int tokenValue,
  ) {
    final next = Map<String, dynamic>.from(original);
    for (final key in _tokenLimitKeys) {
      next.remove(key);
    }
    next[tokenKey] = tokenValue;
    return next;
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
    debugPrint('============================================================');
    debugPrint('=== API connection test start ===');
    debugPrint('Config: ${apiConfig.name}');
    debugPrint('URL: ${apiConfig.baseUrl}');
    debugPrint('Model: ${apiConfig.modelName}');
    debugPrint('============================================================');

    if (apiConfig.apiKey.isEmpty) {
      return (false, 'API key is not set.');
    }

    if (apiConfig.baseUrl.isEmpty) {
      return (false, 'Base URL is not set.');
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

        final requestBody = _buildAnthropicRequestBody(
          apiConfig: apiConfig,
          chatMessages: [
            {'role': 'user', 'content': 'test'},
          ],
          settings: AppSettings(maxTokens: 10, temperature: 0.0, topP: 1.0),
        );

        final response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          return (true, 'Connection successful! (Anthropic)');
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

        final requestBody = _buildOpenAICompatibleRequestBody(
          apiConfig: apiConfig,
          messages: [
            {'role': 'user', 'content': 'test'},
          ],
          settings: AppSettings(
            maxTokens: 10,
            temperature: 0.0,
            topP: 1.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
          ),
        );

        var response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 400) {
          final errorMsg = _extractErrorMessage(response.body);
          final suggestedKey = _extractSuggestedTokenKey(errorMsg);
          if (suggestedKey != null &&
              !requestBody.containsKey(suggestedKey) &&
              _tokenLimitKeys.contains(suggestedKey)) {
            final retryBody = _replaceTokenLimitKey(
              requestBody,
              suggestedKey,
              10,
            );
            response = await http.post(
              Uri.parse(apiConfig.baseUrl),
              headers: headers,
              body: jsonEncode(retryBody),
            );
          }
        }

        if (response.statusCode == 200) {
          return (true, 'Connection successful!');
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
      debugPrint('>>> Connection test error: $e');
      return (false, 'Connection error: $e');
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
