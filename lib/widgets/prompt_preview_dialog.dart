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
[지원 Lua 훅]
onLoad()
onUnload()
onUserMessage(text) -> string
onAssistantMessage(text) -> string
onPromptBuild(text) -> string
onDisplayRender(text) -> string

[스크립트 실행 조건]
- isEnabled=true
- scope=global 또는 perCharacter
- perCharacter는 현재 캐릭터 id가 일치해야 실행
- order 오름차순 실행

[기본 지시어 소유 블록]
기본 스크립트에 아래 마커가 있으면 assistant 지시어 실행을 Lua 단계가 소유합니다.
-- hook:onAssistantMessage directives:owned

이 마커가 켜져 있으면:
- 선택한 LLM 연결 대상의 지시어를 먼저 실행
- 이어서 다른 대상의 지시어도 계속 실행
- 한 응답 안에서 Live2D + 이미지 오버레이 지시어를 함께 처리 가능

[지원 지시어 문법 - Live2D]
<live2d> ... </live2d>
<param id="..." value="..." op="set|del|mul" dur="..." delay="..."/>
<motion group="..." index="..." priority="..." delay="..."/>
<motion name="Idle/0"/>
<expression id="smile" delay="..."/>
<expression name="smile"/>
<emotion name="happy"/>
<wait ms="300"/>
<preset name="idle" delay="..."/>
<reset delay="..."/>
[param:id=ParamMouthOpenY,value=0.7]
[motion:name=Idle/0]
[expression:id=smile]
[emotion:name=happy]
[wait:ms=300]
[preset:name=idle]
[reset]

[지원 지시어 문법 - 이미지 오버레이]
<overlay> ... </overlay>
<move x="100" y="200" op="set|del|mul" delay="..."/>
<emotion name="happy"/>
<wait ms="300"/>
[img_move:x=100,y=200]
[img_emotion:name=happy]

[Regex/Lua 실행 순서]
설정의 "Regex 선처리 후 Lua 실행"이 켜져 있으면:
- userInput: Regex -> Lua
- aiOutput: Regex -> Lua -> 지시어 소유 실행
- promptInjection: Regex -> Lua
- displayOnly: Regex -> Lua
끄면:
- aiOutput: Lua -> Regex -> 지시어 소유 실행
- 나머지 단계는 Lua -> Regex 순서로 실행됩니다.

[네이티브 브리지]
executeHook(script, hook, input, timeoutMs)
executeHookAndReturn(script, hook, input, timeoutMs)

[의사 Lua(폴백) 주석 문법]
-- hook:onUserMessage replace:foo=>bar
-- hook:onAssistantMessage append:...text...
-- hook:onPromptBuild prepend:...text...

[주의]
- onLoad/onUnload는 반환값이 없습니다.
- 위 폴백 문법은 주석 라인 기반 폴백 실행에서만 동작합니다.
- Lua 실행을 끄거나 directives:owned 마커를 제거하면 기본 지시어 자동 실행도 꺼집니다.
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

[기본 제공 규칙 요약]
- aiOutput: 공개 지시어를 내부 런타임 토큰으로 변환
- displayOnly: 공개/내부 지시어를 화면 출력에서 제거

[기본 변환 예시]
<live2d>...</live2d> -> <pwf-live2d>...</pwf-live2d>
<overlay>...</overlay> -> <pwf-overlay>...</pwf-overlay>
[param:...] -> [pwf-live2d:param:...]
[motion:...] -> [pwf-live2d:motion:...]
[expression:...] -> [pwf-live2d:expression:...]
[emotion:...] -> [pwf-live2d:emotion:...]
[wait:...] -> [pwf-live2d:wait:...]
[preset:...] -> [pwf-live2d:preset:...]
[reset] -> [pwf-live2d:reset:]
[img_move:...] -> [pwf-overlay:img_move:...]
[img_emotion:...] -> [pwf-overlay:img_emotion:...]
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
