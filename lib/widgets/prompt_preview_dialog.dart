import 'package:flutter/material.dart';

class CommandHelpDialog {
  const CommandHelpDialog._();

  static Future<void> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _CommandHelpPage()));
  }
}

class _CommandHelpPage extends StatelessWidget {
  const _CommandHelpPage();

  static const String _chatCommandsText = '''
/help
/?:
  도움말 페이지 열기

/del n
/delete n:
  n번째 메시지 삭제
  예: /del 3

/del n~m
/delete n~m:
  n번째부터 m번째 메시지까지 삭제
  예: /del 1~5

/send 내용:
  API 호출 없이 메시지 기록만 추가
  예: /send 테스트 메시지

/edit n 내용:
  n번째 메시지 내용 수정
  예: /edit 2 수정된 내용

/copy n:
  n번째 메시지 내용을 클립보드로 복사
  예: /copy 3

/clear:
  현재 세션 대화 전체 초기화

/export:
  현재 세션 대화를 JSON으로 내보내기

메시지 번호는 1부터 시작합니다.
''';

  static const String _luaText = '''
[지원 훅 이름]
onLoad
onUnload
onUserMessage
onAssistantMessage
onPromptBuild
onDisplayRender

[훅 실행 순서]
1) 스크립트 isEnabled=true
2) scope 검사(global/perCharacter)
3) order 오름차순 실행

[입력/출력 규칙]
- onUserMessage/onAssistantMessage/onPromptBuild/onDisplayRender:
  문자열 입력 -> 문자열 출력
- onLoad/onUnload:
  라이프사이클 훅(반환값 없음)

[네이티브 브리지]
executeHook(script, hook, input, timeoutMs)
executeHookAndReturn(script, hook, input, timeoutMs)

[의사 Lua(폴백) 지원 주석 문법]
-- hook:onUserMessage replace:foo=>bar
-- hook:onAssistantMessage append:...text...
-- hook:onPromptBuild prepend:...text...

위 문법은 주석 라인 기반 폴백 실행에서만 동작합니다.
''';

  static const String _regexText = '''
[룰 타입]
userInput
aiOutput
promptInjection
displayOnly

[룰 스코프]
global
perCharacter
perSession

[정규식 옵션]
caseInsensitive  -> RegExp(caseSensitive: false)
multiLine        -> RegExp(multiLine: true)
dotAll           -> RegExp(dotAll: true)

[기본 동작]
- pattern으로 RegExp 생성
- replacement로 치환
- priority 오름차순 적용
- isEnabled=false면 실행 제외

[예시]
pattern: <live2d>.*?</live2d>
replacement: (empty)

pattern: [img_emotion:name=(.*?)]
replacement: <overlay><emotion name="\$1"/></overlay>
''';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('명령어 도움말'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '채팅 명령어'),
              Tab(text: 'Lua 함수 및 문법'),
              Tab(text: 'Regex 문법'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlainTextTab(text: _chatCommandsText),
            _PlainTextTab(text: _luaText),
            _PlainTextTab(text: _regexText),
          ],
        ),
      ),
    );
  }
}

class _PlainTextTab extends StatelessWidget {
  const _PlainTextTab({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
    );
  }
}
