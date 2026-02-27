# Newcastle Android 실기기 검증 매트릭스 - 2026-02-27

## 1. 검증 목표

1. Newcastle 요구사항이 Android 실제 동작 기준에서 기능/안정성/오류처리를 충족하는지 검증한다.
2. 동시성 핵심 게이트(queue/mutex 직렬화, API cancel, session sync)를 회귀세트로 고정한다.
3. Critical/High 결함 0건일 때만 main 반영 가능하다.

## 2. 테스트 환경 매트릭스

| ID | 축 | 값 |
|---|---|---|
| ENV-01 | OS | Android 10, 12, 13, 14 |
| ENV-02 | 제조사 | Pixel(AOSP), Samsung(OneUI), Xiaomi(MIUI) |
| ENV-03 | 네트워크 | Wi-Fi 안정, LTE, 완전 오프라인, Offline->Online 복구 |
| ENV-04 | 앱 상태 | Foreground, Background(화면 켜짐), Screen-off |
| ENV-05 | 권한 상태 | POST_NOTIFICATIONS 허용/거부, SYSTEM_ALERT_WINDOW 허용/거부 |

## 3. 공통 사전 체크리스트

1. 테스트 빌드에 Newcastle 플래그가 활성화되어 있다.
2. 기본 Prompt preset 1개 이상 존재한다.
3. API preset 1개 이상 존재한다.
4. 활성 메인 세션이 최소 1개 존재한다.
5. 알림 채널(persistent, heads-up)이 생성되어 있다.
6. 로그 수집 항목(requestId, sessionId, source, cancel reason)이 켜져 있다.

## 4. 기능 테스트 케이스

### 4.1 Priority 1-3 (Global/Character/Prompt Block)

| ID | 카테고리 | 절차 | 기대결과 | 심각도 |
|---|---|---|---|---|
| P1-01 | Global Toggle | Global On에서 Off 전환 | 진행중 API 즉시 취소, 모든 알림 제거, proactive 타이머 중지 | Critical |
| P1-02 | Global Toggle | 앱 재시작 후 상태 확인 | 마지막 On/Off 상태 복원 | High |
| P1-03 | Global Toggle | Off 상태에서 notification/proactive 트리거 | 요청 enqueue 차단 및 안내 메시지 | High |
| P1-04 | Feature Registry | Live2D+Notification 등록 후 On/Off 반복 | 등록 feature만 상태 동기화 | High |
| P2-01 | Character Name | 상단 이름 편집 후 저장 | 메뉴/알림 제목에 동일 반영 | High |
| P3-01 | Block Type | `prompt/pastmemory/input` 각각 추가/삭제 | 모든 블록 자유 생성/삭제 가능 | High |
| P3-02 | Block Multiplicity | 같은 타입 2개 이상 생성 | 컴파일 결과에 순서대로 모두 반영 | High |
| P3-03 | Pastmemory Range | `range=-1`, `0`, `abc`, 빈값 입력 | 저장 시 1로 보정 | High |
| P3-04 | Pastmemory Range | range가 히스토리 수보다 큼 | 가능한 메시지만 사용, 예외 없음 | High |
| P3-05 | Pastmemory Header | userHeader/charHeader 커스텀 | XML 태그명이 설정값대로 출력 | Medium |
| P3-06 | Inactive Exclusion | 블록 비활성화 후 API 호출 | payload에서 완전 제외(빈 값도 없음) | Critical |
| P3-07 | Reorder | 블록 순서 변경 후 호출 | 컴파일 결과 순서가 UI 순서와 동일 | High |
| P3-08 | Legacy Migration | 기존 저장 데이터가 있는 상태로 업그레이드 | 데이터 유실 없이 v2 구조로 로드 | Critical |

### 4.2 Priority 4-5 (Preset/Preview)

| ID | 카테고리 | 절차 | 기대결과 | 심각도 |
|---|---|---|---|---|
| P4-01 | Preset Add | 새 preset 추가(이름 입력) | preset 생성, 목록 즉시 반영 | High |
| P4-02 | Preset Select Dirty | 미저장 변경 후 다른 preset 선택 | 저장 여부 팝업 노출 | High |
| P4-03 | Preset Save | 활성 preset 수정 후 저장 | 재진입 시 변경 유지 | High |
| P4-04 | Preset Delete Guard | preset 1개만 남긴 상태에서 삭제 | 삭제 차단 메시지 표시 | High |
| P4-05 | Preset Delete Reassign | notification/proactive가 참조중인 preset 삭제 | 참조가 기존 preset으로 자동 재지정 | Critical |
| P4-06 | Preset Rename | preset 이름 변경 | 모든 선택 UI에 새 이름 반영 | Medium |
| P4-07 | Preset Export/Import | 외부 JSON 내보내기/가져오기 | 스키마 유효 시 정상 로드 | High |
| P4-08 | Import Parse Error | malformed JSON import | 에러 표시, 기존 활성 preset 유지 | Critical |
| P5-01 | Preview Exactness | preview 문자열과 실제 API payload 비교 | 완전 일치 | Critical |
| P5-02 | Preview Session Source | active main session 변경 후 preview | pastmemory가 새 active session 기록 반영 | High |
| P5-03 | Preview Scroll | 10k+ 문자 프롬프트 확인 | UI 스크롤/복사 정상 | Medium |

### 4.3 Priority 6 (Notification Settings/Message)

| ID | 카테고리 | 절차 | 기대결과 | 심각도 |
|---|---|---|---|---|
| P6-01 | Notification Toggle | Notifications Off/On 반복 | 설정 즉시 반영, Off 시 발행 중단 | High |
| P6-02 | Persistent Mode | Persistent On 후 Clear All 수행 | 알림 유지(삭제되지 않음) | Critical |
| P6-03 | Non-Persistent Mode | Persistent Off 후 dismiss | 알림 dismiss 가능 | Medium |
| P6-04 | New Output Mode | Output as New Notification On | 각 응답이 heads-up 신규 알림으로 발행 | High |
| P6-05 | Preset Binding | Notification용 prompt/api preset 변경 | 실제 알림 reply 요청에 선택값 적용 | Critical |
| P6-06 | Permission Flow First Enable | Android 13+에서 처음 On | POST_NOTIFICATIONS 권한 요청 팝업 | High |
| P6-07 | Permission Denied Guide | 권한 거부 후 다시 On | 설정 이동 가이드 노출 | High |
| P6-08 | Force-stop Restore | 강종 후 재실행(Global On+Noti On) | 서비스/알림 자동 복원 | High |
| P6-09 | Big Text | 장문 응답 수신 | 확장 시 전체 메시지 확인 가능 | Medium |
| P6-10 | Inline Reply Entry | Reply 액션 탭 | 인라인 입력 + Cancel 노출 | High |
| P6-11 | Touch-Through Action | Touch-Through 액션 탭 | Live2D 터치스루 상태 토글 | High |
| P6-12 | Loading State | Reply 전송 직후 | Responding 상태 표시 | Medium |
| P6-13 | API Error Surface | Reply API 실패 유도 | 정상 응답 대신 에러 메시지 표시 | High |

### 4.4 Priority 7 (Notification-Chat Integration + Concurrency)

| ID | 카테고리 | 절차 | 기대결과 | 심각도 |
|---|---|---|---|---|
| P7-01 | Active Session Rule | 활성 세션 없음 상태에서 notification reply 시도 | 기능 비활성 또는 세션 생성 안내 | High |
| P7-02 | Session Sync User | notification reply 전송 | 메인 세션에 user 메시지 반영 | High |
| P7-03 | Session Sync Assistant | notification 응답 수신 | 메인 세션에 assistant 메시지 반영 | High |
| P7-04 | Queue Serialization | 앱 입력/알림 reply 동시 전송 | 세션 단위 순차 처리, 순서 역전 없음 | Critical |
| P7-05 | Mutex Integrity | 3개 소스 동시 burst | 하나의 in-flight만 존재 | Critical |
| P7-06 | Cancel on Global Off | 처리중 요청 중 Global Off | 즉시 취소, stale 응답 미반영 | Critical |
| P7-07 | Idempotent Sync | 동일 requestId 결과 중복 주입 | 세션 중복 append 없음 | High |

### 4.5 Priority 8 (Proactive Response)

| ID | 카테고리 | 절차 | 기대결과 | 심각도 |
|---|---|---|---|---|
| P8-01 | Condition Parser Valid | `overlayon=3m30s~5m` 저장 | 정상 저장 | High |
| P8-02 | Condition Disable | `screenoff=0` 저장 | 해당 조건 비활성 | Medium |
| P8-03 | Parser Invalid Line | 문법 오류 라인 포함 저장 | 라인번호 포함 오류, 저장 거부 | High |
| P8-04 | Min Interval Rule | `overlayon=10s~30s` 저장 | 10초 이하 최소값 거부 | High |
| P8-05 | Unit Rule | `1d~2d` 입력 | d 단위 거부 | Medium |
| P8-06 | Priority Rule | overlayoff+screenlandscape 동시 충족 | screenlandscape 조건 채택 | High |
| P8-07 | Screenoff Override | screenoff가 텍스트 상단에 있어도 동시충족 | screenoff가 최우선 적용 | Critical |
| P8-08 | Input Block Ignore | proactive preset에 input 블록 포함 | 컴파일 시 input 자동 skip | Medium |
| P8-09 | Timer Reset Success | proactive 성공 응답 | 타이머 리셋 | High |
| P8-10 | User Reply Preemption | proactive API 중 reply 전송 | proactive 즉시 cancel, reply 우선 | Critical |
| P8-11 | Timer Preserve on Reply | P8-10 직후 타이머 확인 | proactive 타이머는 리셋되지 않음 | High |
| P8-12 | Offline Reply | 오프라인에서 notification reply | 에러 알림 표시, 자동재시도 없음 | High |
| P8-13 | Offline Proactive | 오프라인 proactive 트리거 | 에러 알림 표시, 타이머는 실패 후 정상 리셋 | High |
| P8-14 | Background Run | 앱 백그라운드+FGS active | 타이머 지속 동작 | High |
| P8-15 | Screen-off Condition | 화면 OFF 전환 후 대기 | `screenoff` 조건으로 간격 계산 | High |
| P8-16 | Doze Delay Behavior | Doze 진입 상태에서 타이머 측정 | 정책 범위 내 지연, 비정상 누락 없음 | Medium |

## 5. 동시성 전용 회귀세트

| ID | 시나리오 | 검증 포인트 | 합격 기준 |
|---|---|---|---|
| CON-01 | in-app 20연속 + notification 20연속 동시 | queue 직렬화 | 세션 메시지 순서 불변 |
| CON-02 | proactive 실행 중 global off | cancel 전파 | in-flight 즉시 중단 + 타이머 정지 |
| CON-03 | proactive 실행 중 notification reply | 선점 취소 | proactive 취소 후 reply 정상 처리 |
| CON-04 | 세션 전환 직후 알림 reply 도착 | session sync | 활성 세션 기준 정책대로 처리/차단 |
| CON-05 | 오프라인/온라인 빠른 토글 | 오류/복구 | 중복 append 없이 오류 표면화 |

## 6. 운영 체크리스트 (실배포 전)

1. Android 13+ 권한 거부/허용/재허용 플로우를 제조사별로 1회 이상 검증했다.
2. Persistent notification이 Clear All로 삭제되지 않음을 Android 14 실기기에서 확인했다.
3. Force-stop 후 앱 재실행 복원 조건(Global On + Notifications On)을 검증했다.
4. Inline reply와 Touch-Through 액션이 백그라운드 상태에서도 정상 동작한다.
5. 오프라인 실패 시 자동재시도 미동작과 오류 알림 표시를 확인했다.
6. Critical/High 결함이 0건이다.

## 7. 증빙 템플릿

| 항목 | 필수 증빙 |
|---|---|
| 기능 테스트 | 케이스 ID별 Pass/Fail 로그 |
| 권한/알림 | 화면 녹화 또는 스크린샷 |
| 동시성 | requestId/sessionId 포함 로그 추적 |
| 오프라인 | 네트워크 차단/복구 시퀀스 로그 |
| 결함관리 | Severity/Owner/Disposition 표 |
| 승인 | QA Owner 서명 + 날짜 |
