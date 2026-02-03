// ============================================================================
// API 서비스 (API Service) - v2
// ============================================================================
// OpenAI, Anthropic, GitHub Copilot API와 통신하는 기능을 담당합니다.
// 메시지를 보내고 AI의 응답을 받아옵니다.
// ============================================================================

import 'dart:convert';  // JSON 변환용
import 'package:http/http.dart' as http;  // HTTP 요청용

import '../models/message.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';
import '../services/prompt_builder.dart';

/// API 서비스 클래스
/// OpenAI, Anthropic, GitHub Copilot API에 요청을 보내고 응답을 받습니다
class ApiService {
  // === OpenAI API 설정 ===
  static const String _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // === Anthropic API 설정 ===
  static const String _anthropicBaseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';  // Anthropic API 버전

  // === GitHub Copilot API 설정 ===
  static const String _copilotBaseUrl = 'https://api.githubcopilot.com/chat/completions';
  static const String _copilotEditorVersion = 'vscode/1.90.0';
  static const String _copilotPluginVersion = 'copilot/1.0.0';

  // 프롬프트 빌더 (블록 기반 API 호출용)
  final PromptBuilder _promptBuilder = PromptBuilder();

  /// 메시지를 AI에게 보내고 응답을 받습니다 (레거시 방식)
  /// 
  /// [messages]: 대화 내역 (시스템 메시지 포함)
  /// [settings]: 앱 설정 (API 키, 모델, 파라미터 등)
  /// 
  /// 반환값: AI의 응답 텍스트
  /// 에러 발생 시 예외를 던집니다
  Future<String> sendMessage({
    required List<Message> messages,
    required AppSettings settings,
  }) async {
    // 현재 선택된 API 제공자에 따라 적절한 메서드 호출
    switch (settings.apiProvider) {
      case ApiProvider.openai:
        return await _sendToOpenAI(messages: messages, settings: settings);
      case ApiProvider.anthropic:
        return await _sendToAnthropic(messages: messages, settings: settings);
      case ApiProvider.copilot:
        return await _sendToCopilot(messages: messages, settings: settings);
    }
  }

  /// 블록 기반 메시지 전송 (새로운 방식)
  /// 
  /// [blocks]: 프롬프트 블록 목록
  /// [pastMessages]: 과거 대화 내역
  /// [currentInput]: 현재 사용자 입력
  /// [settings]: 앱 설정
  /// [pastMessageCount]: 포함할 과거 메시지 수
  Future<String> sendMessageWithBlocks({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    required AppSettings settings,
    int pastMessageCount = 10,
  }) async {
    // API 제공자별 플래그 설정
    bool hasFirstSystemPrompt = true;
    bool requiresAlternateRole = false;

    switch (settings.apiProvider) {
      case ApiProvider.copilot:
        // GitHub Copilot은 첫 메시지가 system이어야 하고, role이 번갈아야 함
        hasFirstSystemPrompt = true;
        requiresAlternateRole = true;
        break;
      case ApiProvider.openai:
        hasFirstSystemPrompt = true;
        requiresAlternateRole = false;
        break;
      case ApiProvider.anthropic:
        // Anthropic은 system을 별도로 처리하므로 false
        hasFirstSystemPrompt = false;
        requiresAlternateRole = true;  // 연속 user 불가
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

    // API 호출
    switch (settings.apiProvider) {
      case ApiProvider.openai:
        return await _sendFormattedToOpenAI(
          messages: formattedMessages,
          settings: settings,
        );
      case ApiProvider.anthropic:
        return await _sendFormattedToAnthropic(
          messages: formattedMessages,
          settings: settings,
        );
      case ApiProvider.copilot:
        return await _sendFormattedToCopilot(
          messages: formattedMessages,
          settings: settings,
        );
    }
  }

  // ============================================================================
  // OpenAI API
  // ============================================================================

  /// OpenAI API에 메시지를 보냅니다 (레거시)
  Future<String> _sendToOpenAI({
    required List<Message> messages,
    required AppSettings settings,
  }) async {
    if (settings.openaiApiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    final List<Map<String, dynamic>> formattedMessages = messages.map((msg) {
      return {
        'role': msg.roleString,
        'content': msg.content,
      };
    }).toList();

    return await _sendFormattedToOpenAI(
      messages: formattedMessages.map((m) => Map<String, String>.from(m)).toList(),
      settings: settings,
    );
  }

  /// OpenAI API에 포맷된 메시지를 보냅니다
  Future<String> _sendFormattedToOpenAI({
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    if (settings.openaiApiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    final Map<String, dynamic> requestBody = {
      'model': settings.openaiModel,
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'max_tokens': settings.maxTokens,
      'frequency_penalty': settings.frequencyPenalty,
      'presence_penalty': settings.presencePenalty,
    };

    try {
      final response = await http.post(
        Uri.parse(_openaiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.openaiApiKey}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        return content.trim();
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMessage = errorData['error']?['message'] ?? '알 수 없는 오류';
        throw Exception('OpenAI API 오류 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('OpenAI API 요청 실패: $e');
    }
  }

  // ============================================================================
  // Anthropic API
  // ============================================================================

  /// Anthropic API에 메시지를 보냅니다 (레거시)
  Future<String> _sendToAnthropic({
    required List<Message> messages,
    required AppSettings settings,
  }) async {
    if (settings.anthropicApiKey.isEmpty) {
      throw Exception('Anthropic API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    String? systemMessage;
    final List<Map<String, dynamic>> formattedMessages = [];

    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        if (systemMessage == null) {
          systemMessage = msg.content;
        } else {
          systemMessage = '$systemMessage\n\n${msg.content}';
        }
      } else {
        formattedMessages.add({
          'role': msg.roleString,
          'content': msg.content,
        });
      }
    }

    if (formattedMessages.isNotEmpty && formattedMessages.first['role'] == 'assistant') {
      formattedMessages.insert(0, {'role': 'user', 'content': '(대화 시작)'});
    }

    return await _sendFormattedToAnthropicInternal(
      messages: formattedMessages,
      systemMessage: systemMessage,
      settings: settings,
    );
  }

  /// Anthropic API에 포맷된 메시지를 보냅니다
  Future<String> _sendFormattedToAnthropic({
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    if (settings.anthropicApiKey.isEmpty) {
      throw Exception('Anthropic API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    // system 메시지 분리
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

    return await _sendFormattedToAnthropicInternal(
      messages: chatMessages,
      systemMessage: systemMessage,
      settings: settings,
    );
  }

  /// Anthropic API 내부 전송 함수
  Future<String> _sendFormattedToAnthropicInternal({
    required List<Map<String, dynamic>> messages,
    String? systemMessage,
    required AppSettings settings,
  }) async {
    final Map<String, dynamic> requestBody = {
      'model': settings.anthropicModel,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'messages': messages,
    };

    if (systemMessage != null && systemMessage.isNotEmpty) {
      requestBody['system'] = systemMessage;
    }

    try {
      final response = await http.post(
        Uri.parse(_anthropicBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': settings.anthropicApiKey,
          'anthropic-version': _anthropicVersion,
        },
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

  // ============================================================================
  // GitHub Copilot API
  // ============================================================================

  /// GitHub Copilot API에 메시지를 보냅니다 (레거시)
  Future<String> _sendToCopilot({
    required List<Message> messages,
    required AppSettings settings,
  }) async {
    if (settings.copilotApiKey.isEmpty) {
      throw Exception('GitHub Copilot API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    // 메시지 포맷 변환
    final List<Map<String, String>> formattedMessages = messages.map((msg) {
      return {
        'role': msg.roleString,
        'content': msg.content,
      };
    }).toList();

    return await _sendFormattedToCopilot(
      messages: formattedMessages,
      settings: settings,
    );
  }

  /// GitHub Copilot API에 포맷된 메시지를 보냅니다
  /// 
  /// Copilot API 특이사항:
  /// - hasFirstSystemPrompt: 첫 메시지가 반드시 system이어야 함
  /// - requiresAlternateRole: user/assistant가 번갈아 와야 함
  Future<String> _sendFormattedToCopilot({
    required List<Map<String, String>> messages,
    required AppSettings settings,
  }) async {
    if (settings.copilotApiKey.isEmpty) {
      throw Exception('GitHub Copilot API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.');
    }

    // 첫 메시지가 system인지 확인 (필수)
    if (messages.isEmpty || messages.first['role'] != 'system') {
      // system 메시지가 없으면 기본 추가
      messages.insert(0, {
        'role': 'system',
        'content': 'You are a helpful AI assistant.',
      });
    }

    final Map<String, dynamic> requestBody = {
      'model': settings.copilotModel.isNotEmpty 
          ? settings.copilotModel 
          : 'gpt-4o',  // 기본 모델
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      'max_tokens': settings.maxTokens,
    };

    try {
      final response = await http.post(
        Uri.parse(_copilotBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.copilotApiKey}',
          'Editor-Version': _copilotEditorVersion,
          'Editor-Plugin-Version': _copilotPluginVersion,
        },
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
                        '알 수 없는 오류';
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception('GitHub Copilot API 오류 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('GitHub Copilot API 요청 실패: $e');
    }
  }
}
