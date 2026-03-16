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

[핵심 계약]
- 시스템은 텍스트 의미를 직접 정하지 않습니다.
- Lua가 문자열을 읽고 훅 안에서 직접 오버레이/Live2D 함수를 호출합니다.
- 기본 Lua 블록은 수정 가능한 템플릿일 뿐이며, 원하는 형식으로 바꿀 수 있습니다.

[기본 fallback helper]
pwf.gsub(text, pattern, replacement)
pwf.replace(text, from, to)
pwf.append(text, suffix)
pwf.prepend(text, prefix)
pwf.trim(text)
pwf.call(functionName, payload)        -- 즉시 실행
pwf.emit(text, functionName, payload)  -- 즉시 실행 + text 유지
pwf.dispatch(text, pattern, functionName, payloadTemplate)
pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)

[시스템이 제공하는 runtime function]
live2d.param
live2d.motion
live2d.expression
live2d.emotion
live2d.wait
live2d.preset
live2d.reset
overlay.move
overlay.emotion
overlay.wait

[기본 Lua 템플릿이 인식하는 예시 형식]
<param .../>
<motion .../>
<expression .../>
<emotion .../>
<wait .../>
<preset .../>
<reset .../>
<move .../>
[param:...]
[motion:...]
[expression:...]
[emotion:...]
[wait:...]
[preset:...]
[reset]
[img_move:...]
[img_emotion:...]

[커스텀 예시]
기본 템플릿 주석처럼 사용자가 직접 원하는 형식을 매핑할 수 있습니다.
예: function(emotion, happy) -> overlay.emotion 호출

[Regex/Lua 실행 순서]
설정의 "Regex 선처리 후 Lua 실행"이 켜져 있으면:
- userInput: Regex -> Lua
- aiOutput: Regex -> Lua(직접 실행)
- promptInjection: Regex -> Lua
- displayOnly: Regex -> Lua
끄면:
- aiOutput: Lua(직접 실행) -> Regex
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
- 실제 Lua 네이티브 브리지가 없으면 위 helper 기반 fallback 실행이 사용됩니다.
- 기본 템플릿을 바꾸면 어떤 문자열이 어떤 함수가 되는지도 함께 바뀝니다.
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
- 기본 Regex는 의미를 정하지 않습니다.
- displayOnly에서 legacy 내부 토큰이나 잔여 제어 문자열을 화면에서 숨길 수 있습니다.
- 필요하면 aiOutput 규칙으로 LLM의 잘못된 XML/문자열을 보정할 수 있습니다.

[보정 예시]
닫히지 않은 XML 보정
잘못된 속성 이름 교정
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
