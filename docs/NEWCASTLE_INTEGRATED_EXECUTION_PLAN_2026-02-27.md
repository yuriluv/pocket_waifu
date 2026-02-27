# Newcastle 통합 실행계획 (기획/운영 선행) - 2026-02-27

## 1. 목적

`docs/Newcastle.md`의 요구사항을 100% 누락 없이 작업단위로 분해하고, 문서의 Implementation Priority(1~8)를 그대로 의존순서로 적용해 개발/운영/QA 팀에 할당한다.

## 2. 선행 원칙

1. 기획/운영 산출물 확정 이전에는 구현 착수 금지.
2. 핵심 안정성 게이트(`serialization(queue/mutex)`, `API cancel`, `session sync`)를 P1 필수 선행으로 고정.
3. Android 실제 동작 기준 검증(권한/알림/포그라운드/인라인리플라이/터치스루/오프라인) 없이는 완료 처리 금지.
4. 자체 리뷰 2회 + QA 결과 첨부 없이는 main 반영 금지.

## 3. 요구사항 전수 추적표 (Coverage Matrix)

| Req ID | Newcastle 요구사항 | 작업단위/설계결정 | 우선순위(의존) | 담당 |
|---|---|---|---|---|
| G-01 | 메뉴 최상단 Global On/Off 버튼 | 메뉴 헤더 상단 고정 토글 컴포넌트 | 1 | Dev |
| G-02 | 전역 실행/정지 상태 통제 | `GlobalFeatureRegistry` 등록형 인터페이스 도입 | 1 | Dev |
| G-03 | Off 시 API 즉시 취소/알림 제거/프로액티브 타이머 중지 | 오케스트레이터 일괄 cancel + NotificationManager clear + Timer stop | 1 | Dev |
| G-04 | On/Off 상태 영속화 | SharedPreferences 저장/복원 | 1 | Dev |
| G-05 | 확장 가능한 모듈 구조 | feature register/unregister 계약 정의 | 1 | Dev |
| C-01 | Character Name 상단 표시/수정 | 메뉴 상단 인라인 편집 진입점 + 저장 | 2 | Dev |
| C-02 | 알림 타이틀에 Character Name 사용 | notification title source를 settings.characterName으로 단일화 | 2 | Dev |
| PB-01 | 고정 블록 제거, 모든 블록 추가/삭제 가능 | system/readOnly 블록 제거, block type 기반 완전 동적 UI | 3 | Dev |
| PB-02 | 과거메시지 조회 메커니즘 전면 교체 | `pastmemory` 블록 빌더 신규 구현 | 3 | Dev |
| PB-03 | JSON 저장/로드 + 충돌 자동 처리 | ID 중복 재발급, order normalize, unknown field 보존 | 3 | Dev |
| PB-04 | `range` 자연수만 허용, invalid는 1 | parser validation 규칙 고정 | 3 | Dev |
| PB-05 | 히스토리 부족 시 가능한 만큼만 사용 | safe slice 로직 적용 | 3 | Dev |
| PB-06 | `userHeader`/`charHeader` 파라미터 지원 | XML 태그 이름 사용자 정의 허용 | 3 | Dev |
| PB-07 | 메시지 순서 오래된순 -> 최신순 | compile 단계 chronological 보장 | 3 | Dev |
| PB-08 | `<user>..</user><char>..</char>` 포맷 출력 | `pastmemory` 렌더러 스펙 반영 | 3 | Dev |
| PB-09 | `input` 블록 파라미터 없음 | type=input은 현재 입력 placeholder만 컴파일 | 3 | Dev |
| PB-10 | 인식 타입: `prompt`, `pastmemory`, `input` | import 타입 whitelist 적용 | 3 | Dev |
| PB-11 | 동일 타입 다중 블록 모두 반영 | list 순서대로 전부 compile | 3 | Dev |
| PB-12 | 공통 필드 `type/title/isActive` 정의 | 모델 스키마 v2 명세 고정 | 3 | Dev |
| PB-13 | 블록 최소 UI: 토글 + 이름 | 공통 block card 표준화 | 3 | Dev |
| PB-14 | 타입별 입력 필드 제공 | `prompt.content`, `pastmemory.range/userHeader/charHeader` | 3 | Dev |
| PB-15 | 블록 순서 변경 지원 | drag/drop 또는 up/down | 3 | Dev |
| PB-16 | 비활성 블록 payload 완전 제외 | inactive drop rule 적용 | 3 | Dev |
| PB-17 | API payload는 활성 블록 핵심 내용만 단락 구분 | compile 결과를 final text로 통일 | 3 | Dev |
| PB-18 | 레거시 데이터 마이그레이션/유실 방지 | v1->v2 migration adapter + rollback-safe 로딩 | 3 | Dev |
| PV-01 | Preview는 API 전송 문자열과 완전 동일 | preview source를 compile output 단일화 | 5 | Dev |
| PV-02 | `pastmemory`는 활성 메인세션 실데이터 사용 | active session history 직접 조회 | 5 | Dev |
| PV-03 | 긴 프롬프트 스크롤 지원 | scrollable/selectable preview view | 5 | Dev |
| PS-01 | 편집기 하단 Preset 바 + Add/Save/Delete/Select | preset toolbar 컴포넌트 추가 | 4 | Dev |
| PS-02 | Add 시 이름 입력 필수 | name required dialog | 4 | Dev |
| PS-03 | Select 전 unsaved 변경 저장 팝업 | dirty-state guard dialog | 4 | Dev |
| PS-04 | Save는 활성 프리셋 갱신 | active preset upsert | 4 | Dev |
| PS-05 | Delete 확인 팝업 + 최소 1개 유지 | delete guard + confirm | 4 | Dev |
| PS-06 | 삭제된 preset 참조 자동 해제/재지정 | notification/proactive preset reference reassignment | 4 | Dev |
| PS-07 | Rename 제공 | preset rename action | 4 | Dev |
| PS-08 | 프리셋 수 제한 없음 | storage paging 없는 full list 정책 | 4 | Dev |
| PS-09 | Export/Import JSON | 외부 파일 I/O + schema validation | 4 | Dev |
| PS-10 | 최초 설치 기본 preset 제공 | bootstrap default preset | 4 | Dev |
| PS-11 | Prompt Preview 상단 preset selector | preview scope 선택기 추가 | 5 | Dev |
| NS-01 | Notifications On/Off | 알림 기능 전체 스위치 | 6 | Dev |
| NS-02 | Persistent Notification On/Off | ongoing 여부 설정값 연결 | 6 | Dev |
| NS-03 | Output as New Notification On/Off | heads-up 출력 분기 | 6 | Dev |
| NS-04 | Notification 전용 Prompt preset 선택 | notification setting에 preset id 저장 | 6 | Dev |
| NS-05 | Notification 전용 API preset 선택 | notification setting에 api preset id 저장 | 6 | Dev |
| NT-01 | Clear All로 지워지지 않는 상시 알림 | FGS + ongoing flag 조합 | 6 | Dev/Ops |
| NT-02 | Foreground Service 라이프사이클 관리 | start/restore/stop 정책 문서화 및 구현 | 6 | Dev/Ops |
| NT-03 | 전용 채널(name/importance/sound/vibration) | persistent/high-priority 채널 분리 | 6 | Dev/Ops |
| NT-04 | manifest `foregroundServiceType` 지정 | AndroidManifest 서비스 타입 고정 | 6 | Dev |
| NT-05 | 강종 후 앱 재실행 시 조건부 자동복원 | global on + notifications on일 때 restore | 6 | Dev/Ops |
| NT-06 | 출력별 새 heads-up 알림 | high importance 채널로 신규 알림 발행 | 6 | Dev |
| NT-07 | Android 13+ 권한 요청/거부 시 설정 유도 | first-enable request + denied deep-link | 6 | Dev/Ops |
| NM-01 | 최신 Android에서 persistent 유지 | ongoing/fgs 검증 케이스 포함 | 6 | Dev/QA |
| NM-02 | 알림 제목에 Character Name 반영 | title builder 공통화 | 6 | Dev |
| NM-03 | 긴 응답 전체 표시 | BigTextStyle 적용 | 6 | Dev |
| NM-04 | Reply 버튼 + inline 입력 + Cancel | RemoteInput + cancel action | 6 | Dev |
| NM-05 | Touch-Through 버튼으로 Live2D 토글 | notification action -> overlay toggle bridge | 6 | Dev |
| NM-06 | 답변 대기중 로딩/Responding 표시 | in-flight notification state | 6 | Dev |
| NM-07 | API 실패 시 에러 메시지 출력 | error notification fallback | 6 | Dev |
| NC-01 | 알림 기능은 메인 활성 세션 사용 | 별도 세션 미생성 정책 고정 | 7 | Dev |
| NC-02 | 활성 세션 없으면 기능 비활성/안내 | disable state + 안내 텍스트 | 7 | Dev |
| NC-03 | 알림 Reply 입력을 사용자 입력으로 처리 | source=notification_user로 enqueue | 7 | Dev |
| NC-04 | AI 출력은 알림으로 전달 | notification sink 연결 | 7 | Dev |
| NC-05 | 알림 송수신 메시지 메인 세션 동기화 | append on success/failure rule 명시 | 7 | Dev |
| NC-06 | 동시접근 직렬화(queue/mutex) | SessionOrchestrator 단일 직렬화 계층 | 7 | Dev |
| PR-01 | Proactive Response 설정 섹션 추가 | menu section 및 설정 저장 | 8 | Dev |
| PR-02 | 조건 TXT 팝업(조회/편집/저장) | text editor modal + parser | 8 | Dev |
| PR-03 | 문법 `<condition>=<min>~<max>` 또는 `=0` | line parser grammar 고정 | 8 | Dev |
| PR-04 | 조건 키: overlayon/off/screenlandscape/screenoff | parser token whitelist | 8 | Dev |
| PR-05 | 공백 금지, 단위 h/m/s, d 미지원 | lexer validation | 8 | Dev |
| PR-06 | 최소 간격 > 10초, 위반 시 에러 팝업 | save reject 정책 | 8 | Dev |
| PR-07 | 잘못된 라인 번호 포함 오류 표시, 저장 거부 | line-indexed validation result | 8 | Dev |
| PR-08 | proactive API preset 선택 | proactive settings binding | 8 | Dev |
| PR-09 | proactive prompt preset 선택 | proactive settings binding | 8 | Dev |
| PR-10 | 조건별 독립 설정 | condition map 저장 구조 | 8 | Dev |
| PR-11 | 동시충족 시 텍스트 하단 라인 우선 | ordered evaluation rule | 8 | Dev |
| PR-12 | `screenoff` 최상위 우선순위 강제 | hard override rule | 8 | Dev |
| PR-13 | 우선순위: overlayon < overlayoff < screenlandscape < screenoff | priority resolver 고정 | 8 | Dev |
| PR-14 | proactive 컨텍스트에서 `input` 블록 무시 | compile mode=proactive에서 skip | 8 | Dev |
| PR-15 | proactive 성공 응답 후 타이머 리셋 | success-only reset rule | 8 | Dev |
| PR-16 | proactive API 진행 중 사용자 reply 발생 시 강제 cancel | proactive cancel + user request 선점 | 8 | Dev |
| PR-17 | 사용자 reply는 proactive 타이머 리셋 금지 | remaining duration 유지 | 8 | Dev |
| PR-18 | proactive 결과를 알림으로 전달 | notification sink reuse | 8 | Dev |
| PR-19 | proactive 메시지 메인 세션 반영 | session append rule | 8 | Dev |
| PR-20 | proactive API 실패 시 에러 알림 | notification error path | 8 | Dev |
| PR-21 | screen-off 시 `screenoff` 조건 적용 | env detector + priority 적용 | 8 | Dev |
| PR-22 | 백그라운드(화면 on)에서도 FGS 활성 시 타이머 유지 | service-bound scheduler | 8 | Dev/Ops |
| PR-23 | Doze 정밀 타이밍 고려 | exact alarm 전략/대안 정의 | 8 | Dev/Ops |
| CM-01 | 필수 권한 선언/런타임 요청 | POST_NOTIFICATIONS/FOREGROUND_SERVICE/SYSTEM_ALERT_WINDOW 등 검증 | 6~8 | Ops/Dev |
| CM-02 | API 실패 표시 위치 통일 | 알림/채팅 각각 오류 표시 경로 | 6~8 | Dev |
| CM-03 | 오프라인 시 자동재시도 금지 | no-auto-retry 정책 고정 | 7~8 | Dev |
| CM-04 | preset JSON 파싱 실패 시 기존 활성 preset 유지 | fail-safe load | 4 | Dev |
| CM-05 | 오프라인 알림 reply 시 에러 알림 | notification error surface | 7 | Dev |
| CM-06 | 오프라인 proactive 실패 시 에러 알림 + 타이머 정상 리셋 | failure reset policy | 8 | Dev |
| CM-07 | 구현 우선순위 1~8 준수 | 본 문서 WBS 순서 고정 | 전체 | Planning |

Coverage 집계: `100/100` (요구사항 ID 기준 누락 0건).

## 4. Implementation Priority 준수 WBS 및 팀 할당

| WBS ID | 우선순위 | 작업 | 선행 의존 | 담당(Owner) | 완료기준(DoD) | 상태 |
|---|---|---|---|---|---|---|
| P0-01 | 선행 | 요구사항 전수 추적표/모듈 매핑 확정 | 없음 | Planning(Clio) | 본 문서 3장 확정 | Done |
| P0-02 | 선행 | 운영 시나리오 매트릭스(권한/FGS/배터리) 확정 | 없음 | Ops(Atlas) | 운영 시나리오 문서 승인 | In Progress |
| P0-03 | 선행 | QA 매트릭스/동시성 회귀세트 v1 고정 | 없음 | QA(Hawk) | 케이스 ID/합격기준 확정 | In Progress |
| D1-01 | 1 | SessionOrchestrator(Queue/Mutex/Cancel/Sync) 구축 | P0-01 | Dev(Aria) | 단일 직렬화 계층 + cancel token + sync state machine | Pending |
| D1-02 | 1 | Global On/Off + Feature Registry | D1-01 | Dev | Off 시 cancel/clear/stop 즉시 실행 | Pending |
| D1-03 | 2 | Character Name 설정/연동 | D1-02 | Dev | 상단 수정 + 알림 타이틀 반영 | Pending |
| D1-04 | 3 | Prompt Block v2(JSON schema+UI+compile) | D1-01 | Dev | `prompt/pastmemory/input` 전면 지원 | Pending |
| D1-05 | 3 | 레거시 데이터 마이그레이션 | D1-04 | Dev | 유실 없는 마이그레이션 로그 | Pending |
| D1-06 | 4 | Preset 시스템(Add/Save/Delete/Rename/Import/Export) | D1-04, D1-05 | Dev | 최소 1개 보장 + 참조 재지정 | Pending |
| D1-07 | 5 | Prompt Preview 개편(실세션 기반) | D1-06 | Dev | API 전송 문자열과 100% 동일 | Pending |
| D1-08 | 6 | Notification 설정 + FGS/채널/권한 플로우 | D1-02, D1-03, D1-06 | Dev/Ops | persistent + heads-up + permission guide | Pending |
| D1-09 | 6 | Notification 메시지 액션(Inline Reply/Cancel/Touch-Through) | D1-08 | Dev | 액션 동작/로딩/실패 표시 구현 | Pending |
| D1-10 | 7 | Notification-Chat 통합(메인 세션 동기화) | D1-01, D1-09 | Dev | 알림 송수신 메시지 session sync | Pending |
| D1-11 | 8 | Proactive parser/priority/scheduler | D1-08, D1-10 | Dev | 문법 파서 + 우선순위 + 타이머 규칙 준수 | Pending |
| D1-12 | 8 | Proactive 런타임 통합(오프라인/에러 포함) | D1-11 | Dev | cancel 경쟁상황/오프라인 정책 충족 | Pending |
| O1-01 | 6~8 | Android 13+ 권한 거부/해제 분기 운영정책 | P0-02 | Ops | 거부 상태 fallback/안내 문구 확정 | In Progress |
| O1-02 | 6~8 | 배포/롤백 플래그 운영안(Global/Notification/Proactive) | P0-02 | Ops | remote flag 및 롤백 runbook | In Progress |
| Q1-01 | 전체 | P1~P8 실기기 테스트 수행 | P0-03, D1-* | QA | Critical/High 0건 | Pending |
| Q1-02 | 전체 | 동시성 회귀(queue/mutex/cancel/sync) | D1-01, D1-10, D1-12 | QA | 레이스/불일치 재현 0건 | Pending |
| GATE-01 | 전체 | 자체 리뷰 1차(설계/의존성/누락) | P0-01~P0-03 | Planning/Ops/Dev | 리뷰 로그 첨부 | Done |
| GATE-02 | 전체 | 자체 리뷰 2차(구현 반영 후) | D1-01~D1-12 | Planning/Ops/Dev | 리뷰 로그 첨부 | Pending |
| RELEASE-01 | 완료 | QA sign-off + 리스크/백로그 확정 + main 반영 | GATE-02, Q1-* | PM/Dev/Ops/QA | 관련 task 전부 Done | Pending |

## 5. 핵심 안정성 아키텍처(필수 게이트)

### 5.1 SessionOrchestrator 명세

1. 세션별 단일 FIFO Queue를 두고, 동일 세션의 `in-app chat`, `notification reply`, `proactive` 요청을 직렬화한다.
2. 큐 실행 잠금은 세션 단위 `mutex` 1개를 사용한다.
3. 각 요청은 `requestId`, `sessionId`, `source`, `cancelToken`을 반드시 가진다.
4. `Global Off` 이벤트는 모든 세션 큐에 `cancelAll()` 브로드캐스트를 수행한다.
5. `notification reply`가 들어올 때 진행 중 요청이 `proactive`이면 즉시 cancel 후 reply를 우선 처리한다.
6. `session sync`는 append 순서를 `user message -> API result(or error marker)`로 고정하고 원자적 저장을 강제한다.

### 5.2 상태머신

| State | 진입 조건 | 종료 조건 | 실패 처리 |
|---|---|---|---|
| Idle | 실행 요청 없음 | 요청 enqueue | 없음 |
| Enqueued | 요청 큐 적재 | lock 획득 | 취소되면 Cancelled |
| Running | API 호출 시작 | 성공/실패/취소 | timeout/cancel/exception 기록 |
| Syncing | 결과를 세션 기록 중 | 기록 성공 | 기록 실패 시 retry 1회 후 error marker |
| Completed | 정상 종료 | 다음 큐 아이템 | 없음 |
| Cancelled | Global Off 또는 선점 취소 | 다음 큐 아이템 | 취소 원인 코드 저장 |
| Failed | API/파싱/오프라인 실패 | 다음 큐 아이템 | 사용자 표면(알림/채팅) 에러 노출 |

### 5.3 취소/동기화 불변식

1. 취소된 요청 결과는 절대 세션에 append하지 않는다.
2. 동일 `requestId` 결과 중복 반영 금지(idempotent sync).
3. active session 부재 시 notification/proactive 요청은 enqueue 금지.
4. 오프라인 실패는 자동 재시도 금지, 즉시 에러 표면화 후 정책대로 타이머 처리.

## 6. 운영 계획 (Android 실제 동작 기준)

1. 권한 플로우: `POST_NOTIFICATIONS`(API 33+) 최초 enable 시 요청, 거부 시 settings deep-link 제공.
2. FGS 정책: persistent notification ON일 때 foreground service 유지, OFF일 때 즉시 stop.
3. 채널 정책: persistent 채널과 heads-up 채널을 분리하고 importance를 독립 설정.
4. 배터리 정책: Doze 지연 허용 기본, 정확 타이밍 필요 시 `setExactAndAllowWhileIdle()` 경로 사용.
5. 복원 정책: 앱 강종 후 재실행 시 `Global On && Notifications On`이면 서비스/알림 복원.
6. 롤백 정책: `global_master_enabled`, `notification_enabled`, `proactive_enabled` 3개 플래그로 단계적 차단.

## 7. 검증 계획 연결

Android 실기기 검증 체크리스트와 테스트 케이스는 아래 문서로 분리했다.

- `docs/NEWCASTLE_ANDROID_REAL_DEVICE_VALIDATION_MATRIX_2026-02-27.md`

자체 리뷰 2회 로그와 QA 결과 첨부는 아래 문서에 기록한다.

- `docs/NEWCASTLE_SELF_REVIEW_AND_QA_REPORT_2026-02-27.md`

## 8. 리스크 및 후속 백로그

| Risk ID | 내용 | 영향 | 대응 | 후속 백로그 |
|---|---|---|---|---|
| R-01 | 세션 동시성 경합으로 메시지 순서 역전 | 대화 무결성 손상 | D1-01 선행, queue/mutex 강제 | race detector 로그/metrics 추가 |
| R-02 | HTTP 요청 취소 미지원 경로 존재 | stale 응답 반영 위험 | cancelToken 어댑터 계층 추가 | 네트워크 클라이언트 cancel 호환성 표준화 |
| R-03 | 알림 권한 거부 제조사별 UX 편차 | 기능 접근성 저하 | O1-01 분기 가이드/설정 유도 | OEM별 FAQ 문서화 |
| R-04 | Doze/배터리 정책으로 proactive 지연 | 타이머 정확도 저하 | 정확모드 옵션 분리 | WorkManager/AlarmManager 하이브리드 |
| R-05 | preset import malformed JSON | 데이터 손상 가능성 | fail-safe load + 기존 preset 유지 | schema versioning(v2/v3) |
| R-06 | 삭제된 preset 참조 dangling | 기능 오동작 | 자동 재지정 규칙 강제 | 참조 무결성 정합성 검사기 |

## 9. 완료 조건(Definition of Done)

1. `docs/Newcastle.md` 요구사항 coverage 100% 유지(본 문서 Req ID 기준).
2. Implementation Priority 1~8 순서 위반 없이 완료.
3. 핵심 안정성 게이트(직렬화/cancel/session sync) 검증 완료.
4. Android 실기기 체크리스트/테스트 케이스 수행 및 결과 첨부.
5. 자체 리뷰 2회 완료 기록 + QA sign-off 첨부.
6. 리스크/후속 백로그 확정.
7. 관련 task 상태 `Done` 확인 후 main 반영.
