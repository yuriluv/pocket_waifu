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
import '../models/oauth_account.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../services/oauth_account_service.dart';
import '../services/prompt_builder.dart';
import '../services/release_log_service.dart';
import '../utils/api_preset_parameter_policy.dart';

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
  static const String _defaultResponsesInstructions =
      'You are a helpful assistant.';
  static const String _codexOriginator = 'codex_cli_rs';
  static const String _codexResponsesBeta = 'responses=experimental';
  static const String _codexUserAgent = 'PocketWaifu/Android';
  static const Set<String> _tokenLimitKeys = {
    'max_tokens',
    'max_completion_tokens',
    'max_output_tokens',
  };

  ApiRequestHandle createRequestHandle() => ApiRequestHandle();

  ///
  ///
  Future<String> sendMessageWithConfig({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
    ApiRequestHandle? requestHandle,
  }) async {
    final resolvedCredential = await OAuthAccountService.instance
        .resolveCredentialForConfig(apiConfig);
    final resolvedToken = resolvedCredential?.accessToken ?? apiConfig.apiKey;
    final transformedMessages = await _applyPromptLifecycle(messages, settings);
    final credentialPreview = resolvedToken.isEmpty
        ? '(empty)'
        : '${resolvedToken.substring(0, min(10, resolvedToken.length))}...';

    requestHandle?.throwIfCancelled();

    debugPrint('============================================================');
    debugPrint('=== API Request Debug (v2.0.1) ===');
    debugPrint('Config ID: ${apiConfig.id}');
    debugPrint('Config Name: ${apiConfig.name}');
    debugPrint('Base URL: ${apiConfig.baseUrl}');
    debugPrint('Model: ${apiConfig.modelName}');
    debugPrint('Credential (first 10): $credentialPreview');
    debugPrint('Format: ${apiConfig.format.name}');
    debugPrint('Messages count: ${transformedMessages.length}');
    debugPrint('============================================================');

    if (resolvedToken.isEmpty) {
      throw Exception('API key or OAuth account is not set. Please check the API preset.');
    }

    if (apiConfig.format == ApiFormat.openAIResponses) {
      return await _sendToOpenAIResponses(
        apiConfig: apiConfig,
        messages: transformedMessages,
        authToken: resolvedToken,
        oauthAccount: resolvedCredential?.account,
        requestHandle: requestHandle,
      );
    }

    if (apiConfig.format == ApiFormat.googleCodeAssist) {
      return await _sendToGoogleCodeAssist(
        apiConfig: apiConfig,
        messages: transformedMessages,
        settings: settings,
        authToken: resolvedToken,
        oauthAccount: resolvedCredential?.account,
        requestHandle: requestHandle,
      );
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
        authToken: resolvedToken,
        requestHandle: requestHandle,
      );
    } else {
      return await _sendToOpenAICompatible(
        apiConfig: apiConfig,
        messages: transformedMessages,
        settings: settings,
        authToken: resolvedToken,
        requestHandle: requestHandle,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _applyPromptLifecycle(
    List<Map<String, dynamic>> messages,
    AppSettings settings,
  ) async {
    final List<Map<String, dynamic>> transformed = [];
    final context = const LuaHookContext();
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final content = await _transformContentWithPromptLifecycle(
        message['content'],
        settings: settings,
        context: context,
      );
      transformed.add({'role': role, 'content': content});
    }

    if (!settings.live2dPromptInjectionEnabled) {
      return transformed;
    }

    return transformed;
  }

  Future<dynamic> _transformContentWithPromptLifecycle(
    dynamic content, {
    required AppSettings settings,
    required LuaHookContext context,
  }) async {
    if (content is String) {
      return _applyPromptLifecycleToText(
        content,
        settings: settings,
        context: context,
      );
    }

    if (content is List) {
      final transformed = <dynamic>[];
      for (final part in content) {
        if (part is Map) {
          final partMap = Map<String, dynamic>.from(part);
          if (partMap['type'] == 'text' && partMap['text'] is String) {
            partMap['text'] = await _applyPromptLifecycleToText(
              partMap['text'] as String,
              settings: settings,
              context: context,
            );
          }
          transformed.add(partMap);
        } else {
          transformed.add(part);
        }
      }
      return transformed;
    }

    return content;
  }

  Future<String> _applyPromptLifecycleToText(
    String text, {
    required AppSettings settings,
    required LuaHookContext context,
  }) async {
    var output = text;
    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyPromptInjection(output);
      output = await _luaScriptingService.onPromptBuild(output, context);
    } else {
      output = await _luaScriptingService.onPromptBuild(output, context);
      output = await _regexPipeline.applyPromptInjection(output);
    }
    return output;
  }

  Future<String> _sendToOpenAICompatible({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
    required String authToken,
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
      'Authorization': 'Bearer $authToken',
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
      final responseBody = _decodeUtf8ResponseBody(response.bodyBytes);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final String content = _extractOpenAITextContent(
          data['choices'][0]['message']['content'],
        );
        return content.trim();
      } else {
        String errorMessage = _extractErrorMessage(responseBody);
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
              final decodedRetryBody = _decodeUtf8ResponseBody(
                retryResponse.bodyBytes,
              );
              final Map<String, dynamic> data = jsonDecode(decodedRetryBody);
              final String content = _extractOpenAITextContent(
                data['choices'][0]['message']['content'],
              );
              return content.trim();
            }

            final decodedRetryBody = _decodeUtf8ResponseBody(
              retryResponse.bodyBytes,
            );
            errorMessage = _extractErrorMessage(decodedRetryBody);
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
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
    required String authToken,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    String? systemMessage;
    final List<Map<String, dynamic>> chatMessages = [];

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        final extracted = _extractTextOnlyContent(msg['content']);
        if (extracted.isEmpty) {
          continue;
        }
        if (systemMessage == null) {
          systemMessage = extracted;
        } else {
          systemMessage = '$systemMessage\n\n$extracted';
        }
      } else {
        chatMessages.add(_toAnthropicMessage(msg));
      }
    }

    if (chatMessages.isNotEmpty && chatMessages.first['role'] == 'assistant') {
      chatMessages.insert(0, {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': '(conversation start)'},
        ],
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
      'x-api-key': authToken,
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
      final responseBody = _decodeUtf8ResponseBody(response.bodyBytes);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final String content = data['content'][0]['text'];
        return content.trim();
      } else {
        final Map<String, dynamic> errorData = jsonDecode(responseBody);
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

  Future<String> _sendToOpenAIResponses({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required String authToken,
    required OAuthAccount? oauthAccount,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    final requestBody = _buildOpenAIResponsesRequestBody(
      apiConfig: apiConfig,
      messages: messages,
    );

    final headers = _buildOpenAIResponsesHeaders(
      apiConfig: apiConfig,
      authToken: authToken,
      oauthAccount: oauthAccount,
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
      final responseBody = _decodeUtf8ResponseBody(response.bodyBytes);
      if (response.statusCode == 200) {
        final content = _extractResponsesResponseContent(
          responseBody: responseBody,
          contentType: response.headers['content-type'],
        );
        return content.trim();
      }
      throw Exception(
        'Responses API error (${response.statusCode}): ${_extractErrorMessage(responseBody)}',
      );
    } on ApiCancelledException {
      rethrow;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Responses API request failed: $e');
    } finally {
      if (requestHandle == null) {
        client.close();
      } else {
        requestHandle.close();
      }
    }
  }

  Future<String> _sendToGoogleCodeAssist({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
    required String authToken,
    required OAuthAccount? oauthAccount,
    ApiRequestHandle? requestHandle,
  }) async {
    requestHandle?.throwIfCancelled();

    final requestBody = _buildGoogleCodeAssistRequestBody(
      apiConfig: apiConfig,
      messages: messages,
      settings: settings,
      oauthAccount: oauthAccount,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
      ...apiConfig.customHeaders,
    };
    final projectId = _googleCloudProjectFor(apiConfig, oauthAccount);
    if (projectId != null && projectId.isNotEmpty) {
      headers['x-goog-user-project'] = projectId;
    }

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
      final responseBody = _decodeUtf8ResponseBody(response.bodyBytes);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final content = _extractGoogleCodeAssistTextContent(data);
        return content.trim();
      }
      throw Exception(
        'Google Code Assist error (${response.statusCode}): ${_extractErrorMessage(responseBody)}',
      );
    } on ApiCancelledException {
      rethrow;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Google Code Assist request failed: $e');
    } finally {
      if (requestHandle == null) {
        client.close();
      } else {
        requestHandle.close();
      }
    }
  }

  String _extractTextOnlyContent(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = <String>[];
      for (final part in content) {
        if (part is Map &&
            part['type']?.toString() == 'text' &&
            part['text'] is String) {
          buffer.add(part['text'] as String);
        }
      }
      return buffer.join('\n');
    }
    return '';
  }

  String _extractOpenAITextContent(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = <String>[];
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.add(part['text'] as String);
        }
      }
      return buffer.join('\n');
    }
    return '';
  }

  String _extractResponsesTextContent(Map<String, dynamic> payload) {
    final direct = payload['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final buffer = <String>[];
    final output = payload['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map) continue;
        final content = item['content'];
        if (content is List) {
          for (final part in content) {
            if (part is! Map) continue;
            final text = part['text'];
            if (text is String && text.isNotEmpty) {
              buffer.add(text);
            }
          }
        }
      }
    }
    return buffer.join('\n');
  }

  String _extractResponsesResponseContent({
    required String responseBody,
    String? contentType,
  }) {
    final normalizedContentType = contentType?.toLowerCase() ?? '';
    if (normalizedContentType.contains('text/event-stream')) {
      return _extractResponsesStreamContent(responseBody);
    }
    final Map<String, dynamic> data = jsonDecode(responseBody);
    return _extractResponsesTextContent(data);
  }

  String _extractResponsesStreamContent(String responseBody) {
    final buffer = StringBuffer();
    Map<String, dynamic>? completedResponse;

    for (final rawLine in const LineSplitter().convert(responseBody)) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) {
        continue;
      }
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') {
        continue;
      }

      Map<String, dynamic> event;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          event = decoded;
        } else if (decoded is Map) {
          event = Map<String, dynamic>.from(decoded);
        } else {
          continue;
        }
      } catch (_) {
        continue;
      }

      final type = event['type']?.toString();
      if ((type == 'response.output_text.delta' ||
              type == 'response.text.delta') &&
          event['delta'] is String) {
        buffer.write(event['delta'] as String);
        continue;
      }

      if (type == 'response.completed' && event['response'] is Map) {
        completedResponse = Map<String, dynamic>.from(event['response'] as Map);
      }
    }

    if (buffer.isNotEmpty) {
      return buffer.toString();
    }
    if (completedResponse != null) {
      return _extractResponsesTextContent(completedResponse);
    }
    throw const FormatException('Responses stream did not contain text output.');
  }

  String _extractGoogleCodeAssistTextContent(Map<String, dynamic> payload) {
    final response = payload['response'];
    if (response is! Map) {
      return '';
    }
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }
    final first = candidates.first;
    if (first is! Map) {
      return '';
    }
    final content = first['content'];
    if (content is! Map) {
      return '';
    }
    final parts = content['parts'];
    if (parts is! List) {
      return '';
    }
    final buffer = <String>[];
    for (final part in parts) {
      if (part is! Map) continue;
      final text = part['text'];
      if (text is String && text.isNotEmpty) {
        buffer.add(text);
      }
    }
    return buffer.join('\n');
  }

  Map<String, dynamic> _toAnthropicMessage(Map<String, dynamic> msg) {
    final role = msg['role']?.toString() ?? 'user';
    final content = msg['content'];

    if (content is String) {
      return {
        'role': role,
        'content': [
          {'type': 'text', 'text': content},
        ],
      };
    }

    if (content is List) {
      final parts = <dynamic>[];
      for (final part in content) {
        if (part is! Map) continue;
        final map = Map<String, dynamic>.from(part);
        final type = map['type']?.toString() ?? '';

        if (type == 'text' && map['text'] is String) {
          parts.add({'type': 'text', 'text': map['text']});
          continue;
        }

        if (type == 'image_url') {
          final imageUrl = map['image_url'];
          String? url;
          if (imageUrl is Map && imageUrl['url'] is String) {
            url = imageUrl['url'] as String;
          }
          final extracted = _extractBase64FromDataUrl(url);
          if (extracted != null) {
            parts.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': extracted.$1,
                'data': extracted.$2,
              },
            });
          }
        }
      }

      if (parts.isEmpty) {
        parts.add({'type': 'text', 'text': ''});
      }
      return {'role': role, 'content': parts};
    }

    return {
      'role': role,
      'content': [
        {'type': 'text', 'text': ''},
      ],
    };
  }

  (String, String)? _extractBase64FromDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:')) {
      return null;
    }

    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    final meta = dataUrl.substring(5, commaIndex);
    final data = dataUrl.substring(commaIndex + 1);
    final semicolonIndex = meta.indexOf(';');
    final mimeType = semicolonIndex == -1
        ? meta
        : meta.substring(0, semicolonIndex);
    if (mimeType.isEmpty || data.isEmpty) {
      return null;
    }

    return (mimeType, data);
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
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
  }) {
    final runtimeParams = _runtimeAdditionalParams(apiConfig);
    final Map<String, dynamic> requestBody = {
      ..._passthroughAdditionalParams(runtimeParams),
      'model': apiConfig.modelName,
      'messages': messages,
    };

    _setIfPresent(
      requestBody,
      'temperature',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.temperatureKey) ??
          settings.temperature,
    );
    _setIfPresent(
      requestBody,
      'top_p',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.topPKey) ??
          settings.topP,
    );
    _setIfPresent(
      requestBody,
      'frequency_penalty',
      _readDoubleParam(
        runtimeParams,
        ApiPresetParameterPolicy.frequencyPenaltyKey,
      ) ??
          settings.frequencyPenalty,
    );
    _setIfPresent(
      requestBody,
      'presence_penalty',
      _readDoubleParam(
        runtimeParams,
        ApiPresetParameterPolicy.presencePenaltyKey,
      ) ??
          settings.presencePenalty,
    );

    final tokenKey = _preferredTokenLimitKey(
      apiConfig: apiConfig,
      isAnthropic: false,
    );
    final maxTokens = _readMaxTokensParam(runtimeParams) ?? settings.maxTokens;
    requestBody[tokenKey] = maxTokens;

    return requestBody;
  }

  @visibleForTesting
  Map<String, dynamic> buildOpenAICompatibleRequestBodyForTest({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
  }) {
    return _buildOpenAICompatibleRequestBody(
      apiConfig: apiConfig,
      messages: messages,
      settings: settings,
    );
  }

  Map<String, dynamic> _buildOpenAIResponsesRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
  }) {
    final instructions = _buildResponsesInstructions(messages);
    final runtimeParams = _runtimeAdditionalParams(apiConfig);
    final requestBody = <String, dynamic>{
      ..._passthroughAdditionalParams(runtimeParams),
      'model': apiConfig.modelName,
      'input': _toResponsesInput(messages),
      'instructions': instructions,
      'store': false,
      'stream': true,
    };
    return requestBody;
  }

  @visibleForTesting
  Map<String, dynamic> buildOpenAIResponsesRequestBodyForTest({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
  }) {
    return _buildOpenAIResponsesRequestBody(
      apiConfig: apiConfig,
      messages: messages,
    );
  }

  @visibleForTesting
  Map<String, String> buildOpenAIResponsesHeadersForTest({
    required ApiConfig apiConfig,
    required String authToken,
    required OAuthAccount? oauthAccount,
  }) {
    return _buildOpenAIResponsesHeaders(
      apiConfig: apiConfig,
      authToken: authToken,
      oauthAccount: oauthAccount,
    );
  }

  @visibleForTesting
  String extractResponsesResponseContentForTest({
    required String responseBody,
    String? contentType,
  }) {
    return _extractResponsesResponseContent(
      responseBody: responseBody,
      contentType: contentType,
    );
  }

  Map<String, String> _buildOpenAIResponsesHeaders({
    required ApiConfig apiConfig,
    required String authToken,
    required OAuthAccount? oauthAccount,
  }) {
    final headers = <String, String>{
      ...apiConfig.customHeaders,
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
    if (_isCodexResponsesRequest(apiConfig, oauthAccount)) {
      headers['Accept'] = 'text/event-stream';
      headers['originator'] = _codexOriginator;
      headers['OpenAI-Beta'] = _codexResponsesBeta;
      headers['User-Agent'] = _codexUserAgent;
      final chatgptAccountId = oauthAccount?.chatgptAccountId;
      if (chatgptAccountId != null && chatgptAccountId.trim().isNotEmpty) {
        headers['ChatGPT-Account-Id'] = chatgptAccountId.trim();
      }
    }
    return headers;
  }

  bool _isCodexResponsesRequest(ApiConfig apiConfig, OAuthAccount? oauthAccount) {
    if (oauthAccount?.provider == OAuthAccountProvider.codex) {
      return true;
    }
    final uri = Uri.tryParse(apiConfig.baseUrl);
    if (uri == null) {
      return false;
    }
    return uri.host == 'chatgpt.com' &&
        uri.path.contains('/backend-api/codex/responses');
  }

  Map<String, dynamic> _buildGoogleCodeAssistRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required AppSettings settings,
    required OAuthAccount? oauthAccount,
  }) {
    final systemTexts = <String>[];
    final contents = <Map<String, dynamic>>[];

    for (final message in messages) {
      final role = message['role']?.toString() ?? 'user';
      if (role == 'system') {
        final text = _extractTextOnlyContent(message['content']);
        if (text.trim().isNotEmpty) {
          systemTexts.add(text.trim());
        }
        continue;
      }
      contents.add({
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': _toGoogleParts(message['content']),
      });
    }

    if (contents.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': const [
          {'text': ''},
        ],
      });
    }

    final generationConfig = <String, dynamic>{};
    final runtimeParams = _runtimeAdditionalParams(apiConfig);
    _setIfPresent(
      generationConfig,
      'temperature',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.temperatureKey) ??
          settings.temperature,
    );
    _setIfPresent(
      generationConfig,
      'topP',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.topPKey) ??
          settings.topP,
    );
    _setIfPresent(
      generationConfig,
      'maxOutputTokens',
      _readMaxTokensParam(runtimeParams) ?? settings.maxTokens,
    );
    _setIfPresent(
      generationConfig,
      'presencePenalty',
      _readDoubleParam(
        runtimeParams,
        ApiPresetParameterPolicy.presencePenaltyKey,
      ) ??
          settings.presencePenalty,
    );
    _setIfPresent(
      generationConfig,
      'frequencyPenalty',
      _readDoubleParam(
        runtimeParams,
        ApiPresetParameterPolicy.frequencyPenaltyKey,
      ) ??
          settings.frequencyPenalty,
    );
    final project = _googleCloudProjectFor(apiConfig, oauthAccount);

    return {
      'model': apiConfig.modelName.startsWith('models/')
          ? apiConfig.modelName
          : 'models/${apiConfig.modelName}',
      if (project != null && project.isNotEmpty)
        'project': project,
      'user_prompt_id': 'pwa-${DateTime.now().millisecondsSinceEpoch}',
      'request': {
        'contents': contents,
        if (systemTexts.isNotEmpty)
          'systemInstruction': {
            'role': 'user',
            'parts': [
              {'text': systemTexts.join('\n\n')},
            ],
          },
        'generationConfig': generationConfig,
      },
    };
  }

  Map<String, dynamic> _buildAnthropicRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> chatMessages,
    required AppSettings settings,
  }) {
    final runtimeParams = _runtimeAdditionalParams(apiConfig);
    final Map<String, dynamic> requestBody = {
      ..._passthroughAdditionalParams(runtimeParams),
      'model': apiConfig.modelName,
      'messages': chatMessages,
    };

    _setIfPresent(
      requestBody,
      'temperature',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.temperatureKey) ??
          settings.temperature,
    );
    _setIfPresent(
      requestBody,
      'top_p',
      _readDoubleParam(runtimeParams, ApiPresetParameterPolicy.topPKey) ??
          settings.topP,
    );
    _setIfPresent(
      requestBody,
      'max_tokens',
      _readMaxTokensParam(runtimeParams) ?? settings.maxTokens,
    );

    return requestBody;
  }

  List<Map<String, dynamic>> _toResponsesInput(
    List<Map<String, dynamic>> messages,
  ) {
    final input = <Map<String, dynamic>>[];
    for (final message in messages) {
      final role = message['role']?.toString() ?? 'user';
      if (role == 'system') {
        continue;
      }
      input.add({
        'role': role,
        'content': _toResponsesContent(message['content']),
      });
    }
    if (input.isEmpty) {
      return const <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': ''},
          ],
        },
      ];
    }
    return input;
  }

  String _buildResponsesInstructions(List<Map<String, dynamic>> messages) {
    final parts = <String>[];
    for (final message in messages) {
      final role = message['role']?.toString() ?? 'user';
      if (role != 'system') {
        continue;
      }
      final text = _extractTextOnlyContent(message['content']).trim();
      if (text.isNotEmpty) {
        parts.add(text);
      }
    }
    if (parts.isEmpty) {
      return _defaultResponsesInstructions;
    }
    return parts.join('\n\n');
  }

  List<Map<String, dynamic>> _toResponsesContent(dynamic content) {
    if (content is String) {
      return [
        {'type': 'input_text', 'text': content},
      ];
    }
    if (content is List) {
      final parts = <Map<String, dynamic>>[];
      for (final part in content) {
        if (part is! Map) continue;
        final type = part['type']?.toString();
        if (type == 'text' && part['text'] is String) {
          parts.add({'type': 'input_text', 'text': part['text']});
          continue;
        }
        if (type == 'image_url') {
          String? url;
          final imageUrl = part['image_url'];
          if (imageUrl is Map && imageUrl['url'] is String) {
            url = imageUrl['url'] as String;
          }
          if (url != null && url.isNotEmpty) {
            parts.add({'type': 'input_image', 'image_url': url});
          }
        }
      }
      if (parts.isNotEmpty) {
        return parts;
      }
    }
    return const <Map<String, dynamic>>[
      {'type': 'input_text', 'text': ''},
    ];
  }

  List<Map<String, dynamic>> _toGoogleParts(dynamic content) {
    if (content is String) {
      return [
        {'text': content},
      ];
    }
    if (content is List) {
      final parts = <Map<String, dynamic>>[];
      for (final part in content) {
        if (part is! Map) continue;
        final type = part['type']?.toString();
        if (type == 'text' && part['text'] is String) {
          parts.add({'text': part['text']});
          continue;
        }
        if (type == 'image_url') {
          final imageUrl = part['image_url'];
          String? url;
          if (imageUrl is Map && imageUrl['url'] is String) {
            url = imageUrl['url'] as String;
          }
          final extracted = _extractBase64FromDataUrl(url);
          if (extracted != null) {
            parts.add({
              'inlineData': {
                'mimeType': extracted.$1,
                'data': extracted.$2,
              },
            });
          }
        }
      }
      if (parts.isNotEmpty) {
        return parts;
      }
    }
    return const <Map<String, dynamic>>[
      {'text': ''},
    ];
  }

  String? _googleCloudProjectFor(ApiConfig apiConfig, OAuthAccount? account) {
    final configProject = apiConfig.additionalParams['googleCloudProject'];
    if (configProject is String && configProject.trim().isNotEmpty) {
      return configProject.trim();
    }
    final accountProject = account?.cloudProjectId;
    if (accountProject != null && accountProject.trim().isNotEmpty) {
      return accountProject.trim();
    }
    return null;
  }

  Map<String, dynamic> _runtimeAdditionalParams(ApiConfig apiConfig) {
    return ApiPresetParameterPolicy.sanitizeAdditionalParams(apiConfig);
  }

  Map<String, dynamic> _passthroughAdditionalParams(Map<String, dynamic> source) {
    final sanitized = Map<String, dynamic>.from(source);
    for (final key in _tokenLimitKeys) {
      sanitized.remove(key);
    }
    sanitized.remove(ApiPresetParameterPolicy.maxTokensKey);
    sanitized.remove(ApiPresetParameterPolicy.temperatureKey);
    sanitized.remove(ApiPresetParameterPolicy.topPKey);
    sanitized.remove(ApiPresetParameterPolicy.frequencyPenaltyKey);
    sanitized.remove(ApiPresetParameterPolicy.presencePenaltyKey);
    return sanitized;
  }

  double? _readDoubleParam(Map<String, dynamic> params, String key) {
    return ApiPresetParameterPolicy.readDouble(params, key);
  }

  int? _readMaxTokensParam(Map<String, dynamic> params) {
    return ApiPresetParameterPolicy.readMaxTokens(params);
  }

  void _setIfPresent(Map<String, dynamic> target, String key, Object? value) {
    if (value != null) {
      target[key] = value;
    }
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

  String _decodeUtf8ResponseBody(List<int> bodyBytes) {
    final output = StringBuffer();
    final sink = StringConversionSink.fromStringSink(output);
    final chunkedDecoder = utf8.decoder.startChunkedConversion(sink);

    const chunkSize = 1024;
    for (int i = 0; i < bodyBytes.length; i += chunkSize) {
      final end = min(i + chunkSize, bodyBytes.length);
      chunkedDecoder.add(bodyBytes.sublist(i, end));
    }
    chunkedDecoder.close();

    return output.toString();
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

    final resolvedCredential = await OAuthAccountService.instance
        .resolveCredentialForConfig(apiConfig);
    final resolvedToken = resolvedCredential?.accessToken ?? apiConfig.apiKey;

    if (resolvedToken.isEmpty) {
      return (false, 'API key or OAuth account is not set.');
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
          'x-api-key': resolvedToken,
          'anthropic-version': _anthropicVersion,
          ...apiConfig.customHeaders,
        };

        final requestBody = _buildAnthropicRequestBody(
          apiConfig: apiConfig,
          chatMessages: [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'test'},
              ],
            },
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
      } else if (apiConfig.format == ApiFormat.openAIResponses) {
        final headers = _buildOpenAIResponsesHeaders(
          apiConfig: apiConfig,
          authToken: resolvedToken,
          oauthAccount: resolvedCredential?.account,
        );

        final requestBody = _buildOpenAIResponsesRequestBody(
          apiConfig: apiConfig,
          messages: [
            {'role': 'user', 'content': 'test'},
          ],
        );

        final response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          return (true, 'Connection successful! (Responses)');
        }

        return (
          false,
          'HTTP ${response.statusCode}: ${_extractErrorMessage(response.body)}',
        );
      } else if (apiConfig.format == ApiFormat.googleCodeAssist) {
        final Map<String, String> headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $resolvedToken',
          ...apiConfig.customHeaders,
        };
        final projectId = _googleCloudProjectFor(
          apiConfig,
          resolvedCredential?.account,
        );
        if (projectId != null && projectId.isNotEmpty) {
          headers['x-goog-user-project'] = projectId;
        }

        final requestBody = _buildGoogleCodeAssistRequestBody(
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
          oauthAccount: resolvedCredential?.account,
        );

        final response = await http.post(
          Uri.parse(apiConfig.baseUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          return (true, 'Connection successful! (Google Code Assist)');
        }

        return (
          false,
          'HTTP ${response.statusCode}: ${_extractErrorMessage(response.body)}',
        );
      } else {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $resolvedToken',
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

    final List<Map<String, dynamic>> formattedMessages = messages.map((msg) {
      if (msg.images.isEmpty) {
        return {'role': msg.roleString, 'content': msg.content};
      }
      return {
        'role': msg.roleString,
        'content': _promptBuilder.buildMultimodalContent(
          msg.content,
          msg.images,
        ),
      };
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
