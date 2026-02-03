// ============================================================================
// API 서비스 (API Service) - v3 (범용 구조)
// ============================================================================
// ApiConfig를 사용하여 모든 OpenAI 호환 API에 요청을 보내는 범용 서비스입니다.
// SillyTavern 스타일로 Base URL, 헤더, 파라미터를 자유롭게 설정할 수 있습니다.
// ============================================================================

import 'dart:convert';  // JSON 변환용
import 'package:http/http.dart' as http;  // HTTP 요청용

import '../models/api_config.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';
import '../services/prompt_builder.dart';

/// API 서비스 클래스
/// ApiConfig를 받아 범용적으로 API 요청을 처리합니다
class ApiService {
  // 프롬프트 빌더 (블록 기반 API 호출용)
  final PromptBuilder _promptBuilder = PromptBuilder();

  // === Anthropic API 특수 설정 ===
  static const String _anthropicVersion = '2023-06-01';

  /// 범용 메시지 전송 (새로운 ApiConfig 기반)
  /// 
  /// [apiConfig]: API 설정 (URL, 키, 헤더 등)
  /// [messages]: 대화 메시지 목록 (role, content)
  /// [settings]: 앱 설정 (temperature, maxTokens 등 파라미터)
  /// 
  /// 반환값: AI의 응답 텍스트
  Future<String> sendMessageWithConfig({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    if (apiConfig.apiKey.isEmpty) {
      throw Exception('API 키가 설정되지 않았습니다. 설정에서 API 프리셋을 확인해주세요.');
    }

    // API 타입 감지 (URL 또는 헤더로 판단)
    final bool isAnthropic = apiConfig.baseUrl.contains('anthropic.com') ||
        apiConfig.customHeaders.containsKey('anthropic-version');

    if (isAnthropic) {
      return await _sendToAnthropic(
        apiConfig: apiConfig,
        messages: messages,
        settings: settings,
      );
    } else {
      return await _sendToOpenAICompatible(
        apiConfig: apiConfig,
        messages: messages,
        settings: settings,
      );
    }
  }

  /// OpenAI 호환 API 전송 (OpenAI, Copilot, OpenRouter 등)
  Future<String> _sendToOpenAICompatible({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    // 요청 바디 구성
    final Map<String, dynamic> requestBody = {
      'model': apiConfig.modelName,
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'max_tokens': settings.maxTokens,
      'frequency_penalty': settings.frequencyPenalty,
      'presence_penalty': settings.presencePenalty,
    };

    // 추가 파라미터 병합
    requestBody.addAll(apiConfig.additionalParams);

    // 헤더 구성
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiConfig.apiKey}',
    };

    // 커스텀 헤더 추가
    headers.addAll(apiConfig.customHeaders);

    try {
      final response = await http.post(
        Uri.parse(apiConfig.baseUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        return content.trim();
      } else {
        // 에러 응답 파싱
        String errorMessage = '알 수 없는 오류';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? 
                        errorData['message'] ?? 
                        response.body;
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception('API 오류 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('API 요청 실패: $e');
    }
  }

  /// Anthropic API 전송 (Claude)
  Future<String> _sendToAnthropic({
    required ApiConfig apiConfig,
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    // system 메시지 분리 (Anthropic은 별도 필드로 처리)
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

    // 첫 메시지가 assistant면 user 추가
    if (chatMessages.isNotEmpty && chatMessages.first['role'] == 'assistant') {
      chatMessages.insert(0, {'role': 'user', 'content': '(대화 시작)'});
    }

    // 요청 바디 구성
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

    // 추가 파라미터 병합
    requestBody.addAll(apiConfig.additionalParams);

    // 헤더 구성
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiConfig.apiKey,
      'anthropic-version': _anthropicVersion,
    };

    // 커스텀 헤더 추가
    headers.addAll(apiConfig.customHeaders);

    try {
      final response = await http.post(
        Uri.parse(apiConfig.baseUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['content'][0]['text'];
        return content.trim();
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMessage = errorData['error']?['message'] ?? '알 수 없는 오류';
        throw Exception('Anthropic API 오류 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Anthropic API 요청 실패: $e');
    }
  }

  /// 블록 기반 메시지 전송 (새로운 ApiConfig 방식)
  /// 
  /// [apiConfig]: API 설정
  /// [blocks]: 프롬프트 블록 목록
  /// [pastMessages]: 과거 대화 내역
  /// [currentInput]: 현재 사용자 입력
  /// [settings]: 앱 설정
  /// [pastMessageCount]: 포함할 과거 메시지 수
  Future<String> sendMessageWithBlocks({
    required ApiConfig? apiConfig,
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    required AppSettings settings,
    int pastMessageCount = 10,
  }) async {
    // apiConfig가 없으면 레거시 방식으로 폴백
    if (apiConfig == null) {
      return await _sendMessageWithBlocksLegacy(
        blocks: blocks,
        pastMessages: pastMessages,
        currentInput: currentInput,
        settings: settings,
        pastMessageCount: pastMessageCount,
      );
    }

    // API 타입에 따른 플래그 설정
    final bool isAnthropic = apiConfig.baseUrl.contains('anthropic.com');
    final bool isCopilot = apiConfig.baseUrl.contains('githubcopilot.com');

    bool hasFirstSystemPrompt = true;
    bool requiresAlternateRole = false;

    if (isAnthropic) {
      hasFirstSystemPrompt = false;  // Anthropic은 system을 별도 처리
      requiresAlternateRole = true;  // 연속 user 불가
    } else if (isCopilot) {
      hasFirstSystemPrompt = true;
      requiresAlternateRole = true;  // role이 번갈아야 함
    }

    // 블록 기반으로 메시지 목록 구성
    final formattedMessages = _promptBuilder.buildMessagesForApi(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      pastMessageCount: pastMessageCount,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
    );

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
    );
  }

  // ============================================================================
  // 레거시 메서드들 (하위 호환성 유지)
  // ============================================================================

  /// 메시지를 AI에게 보내고 응답을 받습니다 (레거시 방식)
  /// 
  /// [messages]: 대화 내역 (시스템 메시지 포함)
  /// [settings]: 앱 설정 (API 키, 모델, 파라미터 등)
  /// 
  /// 반환값: AI의 응답 텍스트
  Future<String> sendMessage({
    required List<Message> messages,
    required AppSettings settings,
  }) async {
    // 레거시 설정을 ApiConfig로 변환
    final apiConfig = _createLegacyApiConfig(settings);
    
    final List<Map<String, String>> formattedMessages = messages.map((msg) {
      return {
        'role': msg.roleString,
        'content': msg.content,
      };
    }).toList();

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
    );
  }

  /// 레거시 블록 기반 전송
  Future<String> _sendMessageWithBlocksLegacy({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    required AppSettings settings,
    int pastMessageCount = 10,
  }) async {
    final apiConfig = _createLegacyApiConfig(settings);

    // API 제공자별 플래그 설정
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

    // 블록 기반으로 메시지 목록 구성
    final formattedMessages = _promptBuilder.buildMessagesForApi(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      pastMessageCount: pastMessageCount,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
    );

    return await sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
    );
  }

  /// 레거시 설정에서 ApiConfig 생성
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
