// ============================================================================
// 프롬프트 빌더 (Prompt Builder) - v2
// ============================================================================
// 프롬프트 블록 시스템을 사용하여 최종 프롬프트를 조립하는 서비스입니다.
// SillyTavern 스타일의 프롬프트 블록을 지원합니다.
// ============================================================================

import 'package:uuid/uuid.dart';

import '../models/character.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';

/// 프롬프트 빌더 클래스 (v2)
/// 프롬프트 블록 시스템을 사용하여 최종 프롬프트를 조립합니다
class PromptBuilder {
  // UUID 생성기 (메시지 ID 생성용)
  final Uuid _uuid = const Uuid();

  // ============================================================================
  // 블록 기반 프롬프트 빌드 (새로운 방식)
  // ============================================================================

  /// 프롬프트 블록들을 사용하여 최종 프롬프트 텍스트를 생성합니다
  /// 
  /// [blocks]: 프롬프트 블록 목록
  /// [pastMessages]: 과거 대화 내역
  /// [currentInput]: 현재 사용자 입력
  /// [pastMessageCount]: 포함할 과거 메시지 수
  /// 
  /// 반환값: 조립된 최종 프롬프트 문자열
  String buildFinalPrompt({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    int pastMessageCount = 10,
  }) {
    // 활성화된 블록만 필터링하고 순서대로 정렬
    final enabledBlocks = blocks
        .where((block) => block.isEnabled)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final List<String> promptParts = [];

    for (final block in enabledBlocks) {
      String content = '';

      // 특수 블록 처리
      if (block.id == PromptBlock.TYPE_PAST_MEMORY) {
        // 과거 기억 블록: 대화 내역을 XML 형식으로 변환
        content = _buildPastMemoryXml(pastMessages, pastMessageCount);
      } else if (block.id == PromptBlock.TYPE_USER_INPUT) {
        // 사용자 입력 블록: 현재 입력
        content = currentInput;
      } else {
        // 일반 블록: 저장된 내용 사용
        content = block.content;
      }

      // 내용이 있는 경우만 추가
      if (content.isNotEmpty) {
        promptParts.add('--- ${block.name} ---\n$content');
      }
    }

    return promptParts.join('\n\n');
  }

  /// 과거 대화를 XML 형식으로 변환합니다
  /// 
  /// 출력 형식:
  /// ```xml
  /// <user>사용자 메시지 1</user>
  /// <char>AI 응답 1</char>
  /// ```
  String _buildPastMemoryXml(List<Message> messages, int count) {
    if (messages.isEmpty) return '';

    // 최근 count개의 메시지만 가져오기
    final recentMessages = messages.length > count
        ? messages.sublist(messages.length - count)
        : messages;

    final List<String> xmlParts = [];

    for (final msg in recentMessages) {
      if (msg.role == MessageRole.user) {
        xmlParts.add('<user>${msg.content}</user>');
      } else if (msg.role == MessageRole.assistant) {
        xmlParts.add('<char>${msg.content}</char>');
      }
      // system 메시지는 과거 기억에 포함하지 않음
    }

    return xmlParts.join('\n');
  }

  /// API 호출용 메시지 목록을 구성합니다 (블록 기반)
  /// 
  /// GitHub Copilot API 플래그 처리:
  /// - hasFirstSystemPrompt: 첫 메시지가 반드시 system이어야 함
  /// - requiresAlternateRole: user/assistant가 번갈아 와야 함
  List<Map<String, String>> buildMessagesForApi({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    int pastMessageCount = 10,
    bool hasFirstSystemPrompt = true,
    bool requiresAlternateRole = true,
  }) {
    final List<Map<String, String>> formatted = [];

    // 활성화된 블록만 필터링하고 순서대로 정렬
    final enabledBlocks = blocks
        .where((block) => block.isEnabled)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // === 1. 시스템 프롬프트 구성 (past_memory, user_input 제외한 모든 블록) ===
    final systemParts = <String>[];
    for (final block in enabledBlocks) {
      if (block.id != PromptBlock.TYPE_PAST_MEMORY &&
          block.id != PromptBlock.TYPE_USER_INPUT &&
          block.content.isNotEmpty) {
        systemParts.add('[${block.name}]\n${block.content}');
      }
    }

    // hasFirstSystemPrompt가 true면 시스템 메시지를 맨 앞에
    if (hasFirstSystemPrompt && systemParts.isNotEmpty) {
      formatted.add({
        'role': 'system',
        'content': systemParts.join('\n\n'),
      });
    }

    // === 2. 과거 기억 (past_memory) 블록 처리 ===
    final pastMemoryBlock = enabledBlocks.firstWhere(
      (b) => b.id == PromptBlock.TYPE_PAST_MEMORY,
      orElse: () => PromptBlock.pastMemory()..isEnabled = false,
    );

    if (pastMemoryBlock.isEnabled && pastMessages.isNotEmpty) {
      // 최근 메시지만 가져오기
      final recentMessages = pastMessages.length > pastMessageCount
          ? pastMessages.sublist(pastMessages.length - pastMessageCount)
          : pastMessages;

      // 메시지들을 API 형식으로 추가
      for (final msg in recentMessages) {
        if (msg.role == MessageRole.user) {
          formatted.add({'role': 'user', 'content': msg.content});
        } else if (msg.role == MessageRole.assistant) {
          formatted.add({'role': 'assistant', 'content': msg.content});
        }
      }
    }

    // === 3. 현재 사용자 입력 추가 ===
    if (currentInput.isNotEmpty) {
      formatted.add({'role': 'user', 'content': currentInput});
    }

    // === 4. requiresAlternateRole 처리: 연속된 같은 role 병합 ===
    if (requiresAlternateRole) {
      return _mergeConsecutiveSameRoles(formatted);
    }

    return formatted;
  }

  /// 연속된 같은 role의 메시지를 병합합니다
  List<Map<String, String>> _mergeConsecutiveSameRoles(
    List<Map<String, String>> messages,
  ) {
    if (messages.isEmpty) return messages;

    final List<Map<String, String>> merged = [];
    
    for (final msg in messages) {
      if (merged.isEmpty) {
        merged.add(Map.from(msg));
      } else {
        final lastMsg = merged.last;
        if (lastMsg['role'] == msg['role']) {
          // 같은 role이면 내용 병합
          lastMsg['content'] = '${lastMsg['content']}\n\n${msg['content']}';
        } else {
          merged.add(Map.from(msg));
        }
      }
    }

    return merged;
  }

  // ============================================================================
  // 레거시 방식 (기존 Character 모델 기반) - 하위 호환성 유지
  // ============================================================================

  /// SillyTavern 스타일의 시스템 프롬프트를 생성합니다 (레거시)
  String buildSystemPrompt({
    required Character character,
    required AppSettings settings,
    String userName = 'User',
  }) {
    final List<String> promptParts = [];

    // 기본 롤플레이 지시사항
    promptParts.add('''당신은 "${character.name}"이라는 캐릭터를 연기하는 롤플레이 AI입니다.
아래의 캐릭터 정보와 시나리오에 따라 일관되게 행동하세요.
항상 캐릭터로서 응답하며, AI라는 사실을 언급하지 마세요.
사용자의 이름은 "$userName"입니다.''');

    if (character.description.isNotEmpty) {
      promptParts.add('[캐릭터 설명]\n${character.description}');
    }

    if (character.personality.isNotEmpty) {
      promptParts.add('[캐릭터 성격]\n${character.personality}');
    }

    if (character.scenario.isNotEmpty) {
      promptParts.add('[시나리오]\n${character.scenario}');
    }

    if (character.exampleDialogue.isNotEmpty) {
      String exampleDialogue = character.exampleDialogue
          .replaceAll('{{user}}', userName)
          .replaceAll('{{char}}', character.name);
      promptParts.add('[예시 대화]\n$exampleDialogue');
    }

    if (settings.systemPrompt.isNotEmpty) {
      promptParts.add('[추가 지시사항]\n${settings.systemPrompt}');
    }

    if (settings.useJailbreak && settings.jailbreakPrompt.isNotEmpty) {
      promptParts.add('[특별 지시사항]\n${settings.jailbreakPrompt}');
    }

    return promptParts.join('\n\n');
  }

  /// API에 보낼 전체 메시지 목록을 구성합니다 (레거시)
  List<Message> buildMessages({
    required Character character,
    required AppSettings settings,
    required List<Message> chatHistory,
    String userName = 'User',
  }) {
    final List<Message> messages = [];

    // 시스템 메시지 추가
    final String systemPrompt = buildSystemPrompt(
      character: character,
      settings: settings,
      userName: userName,
    );

    messages.add(Message(
      id: _uuid.v4(),
      role: MessageRole.system,
      content: systemPrompt,
    ));

    // 대화 내역이 비어있고 첫 인사말이 있으면 추가
    if (chatHistory.isEmpty && character.firstMessage.isNotEmpty) {
      final String firstMessage = character.firstMessage
          .replaceAll('{{user}}', userName)
          .replaceAll('{{char}}', character.name);

      messages.add(Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: firstMessage,
      ));
    }

    // 대화 내역 추가 (system 메시지 제외)
    for (final msg in chatHistory) {
      if (msg.role != MessageRole.system) {
        messages.add(msg);
      }
    }

    return messages;
  }

  /// 캐릭터의 첫 인사말을 가공해서 반환합니다
  String getFirstMessage({
    required Character character,
    String userName = 'User',
  }) {
    if (character.firstMessage.isEmpty) {
      return '안녕하세요!';
    }

    return character.firstMessage
        .replaceAll('{{user}}', userName)
        .replaceAll('{{char}}', character.name);
  }
}

