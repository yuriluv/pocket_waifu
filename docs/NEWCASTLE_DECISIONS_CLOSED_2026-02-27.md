# NEWCASTLE Decision Closure (2026-02-27)

이 문서는 Newcastle 요구사항 구현 과정에서 남을 수 있는 미결 의사결정을 운영 기준으로 확정한 기록이다.

## 1) Global Toggle 영향 범위
- **결정:** 현재 범위는 `Live2D Overlay`, `Notification`, `Proactive Timer` 3개로 확정.
- **확장 방식:** 신규 기능은 GlobalRuntimeRegistry(리스너 등록)로 온/오프 훅을 연결.

## 2) Global OFF 시 즉시 정리 동작
- **결정:** OFF 전환 즉시 다음을 강제 수행.
  1. 진행 중 API 요청 cancel
  2. pending notification clear
  3. proactive timer stop
- **재기동:** 앱 재시작 시 persisted state 기준 복구.

## 3) Prompt Block 파서 정책
- **결정:** 지원 타입은 `prompt`, `pastmemory`, `input`.
- **결정:** `pastmemory.range`는 자연수만 허용, 유효하지 않으면 `1`로 보정.
- **결정:** 동일 타입 다중 블록 허용, 표시 순서대로 전부 반영.
- **결정:** `isActive=false` 블록은 API payload에서 완전 제외.

## 4) Preset 삭제 시 참조 처리
- **결정:** 삭제 대상 preset이 notification/proactive 설정에서 참조 중이면,
  - 자동으로 다른 기존 preset에 재할당.
  - 최소 1개 preset은 반드시 유지.

## 5) Notification 권한/지속 알림 정책
- **결정:** Android 13+는 POST_NOTIFICATIONS 런타임 권한 필수.
- **결정:** Persistent notification은 FGS + ongoing event로 처리.
- **결정:** 앱 force-stop 시 시스템 제거 후, 다음 앱 실행에서 상태 복원.

## 6) Reply/Touch-through UX 정책
- **결정:** 알림 Reply 액션은 inline input + cancel 제공.
- **결정:** Touch-through 액션은 Overlay 터치모드 즉시 토글.
- **결정:** 응답 대기 시 notification 내 loading 표기.

## 7) Session 동시성 제어
- **결정:** notification reply / in-app input / proactive response는 단일 직렬 큐(또는 mutex)로 serialize.
- **결정:** proactive API 진행 중 사용자 reply 입력 시 proactive 호출 우선 취소.

## 8) Proactive 조건 우선순위
- **결정:** 겹침 시 우선순위는 `overlayon < overlayoff < screenlandscape < screenoff`.
- **결정:** screenoff는 항상 최우선.

## 9) Offline/Error 처리 정책
- **결정:** 네트워크 오프라인 시 자동 재시도 없음.
- **결정:** 실패 결과는 notification/chat UI에 명시적으로 표시.
- **결정:** malformed preset JSON은 로드 거부, 기존 active preset 유지.

## 10) Release/검증 운영 정책
- **결정:** main 반영 전 QA 체크리스트 기반 검증 필수.
- **결정:** 미검증 항목은 리스크로 문서화하고 후속 백로그로 분리.

---

상기 항목을 Newcastle 요구사항 구현의 공식 운영 결정으로 확정한다.
