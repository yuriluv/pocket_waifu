# DOCS AI UPPERCASE SUMMARY (KO)

## 목적
- `docs` 폴더 내 대문자/언더스코어 중심 영어 문서(주로 AI 생성/AI 보조 생성 문서군)를 한 번에 파악하기 위한 요약/정리 문서.
- 기준 시점: 2026-03-01.

## 범위
- 대상: `flutter_application_1/docs` 내 대문자 영어 파일명 중심 문서 40개.
- 제외: 사용자 메모/프롬프트 성격 문서(`userprompt*.md`, `request2.md`, `Newcastle.md` 등 소문자/혼합 파일명 문서).

## 전체 한눈 요약
- 문서군은 크게 6개 축으로 구성됨: 릴리즈/보안/QA, Newcastle, Live2D 단계 로드맵, Request2 오토파일럿, Non-core 운영, 감사/리팩터링.
- 문서 수는 많지만 중복이 높아 실제 운영 기준으로는 마스터 문서 8~10개로 축약 가능.
- 빠른 상황 파악은 `IMPLEMENTATION_STATUS_AUDIT.md` -> `NEWCASTLE_INTEGRATED_EXECUTION_PLAN_2026-02-27.md` -> `REQUEST2_PART1_GATE_EXECUTION_PLAN_2026-02-27.md` 순이 가장 효율적.

## 주제별 정리

### 1) 릴리즈/보안/QA
- `ANDROID_RELEASE_LOGGING_EXECUTION_PLAN.md`: 안드로이드 릴리즈 + 로그 자동화 전체 실행 설계.
- `APK_RELEASE_INFRA_SECURITY_DELIVERABLE_2026-02-26.md`: 릴리즈/로그 인프라 보안 통제 및 취약점 우선순위.
- `APK_RELEASE_LOGGING_QA_BUG_REPORT_TEMPLATE.md`: 릴리즈·로깅 결함 보고 템플릿.
- `APK_RELEASE_OPS_OUTPUT_GAP_ANALYSIS_2026-02-26.md`: 운영 산출물 누락/갭 분석과 보완안.
- `APK_RELEASE_QA_TEST_MATRIX_2026-02-26.md`: 릴리즈 QA 테스트 매트릭스.
- `QA_EXECUTION_PLAN.md`: 회귀/계약 테스트 실행 계획.
- `QA_DELIVERABLE_REPORT.md`: QA 산출물 보고.

### 2) Newcastle
- `NEWCASTLE_INTEGRATED_EXECUTION_PLAN_2026-02-27.md`: 요구사항 추적 + 실행 우선순위 통합.
- `NEWCASTLE_DECISIONS_CLOSED_2026-02-27.md`: 정책 의사결정 종결 로그.
- `NEWCASTLE_ANDROID_REAL_DEVICE_VALIDATION_MATRIX_2026-02-27.md`: 실기기 QA 검증 매트릭스.
- `NEWCASTLE_PROACTIVE_CONDITION_PARSER_PRIORITY_SPEC_2026-02-27.md`: proactive 조건 파서/우선순위 스펙.
- `NEWCASTLE_SELF_REVIEW_AND_QA_REPORT_2026-02-27.md`: 자체 리뷰 + QA 게이트 결과.

### 3) Live2D 단계 로드맵/구현
- `NATIVE_LIVE2D_MIGRATION_PLAN.md`: WebView -> Native 전환 장기 계획.
- `PHASE1_IMPLEMENTATION_GUIDE.md`: 기초 네이티브 모듈/채널 구현 가이드.
- `PHASE2_3_IMPLEMENTATION_GUIDE.md`: OpenGL 렌더러/오버레이/제스처 가이드.
- `PHASE_4_5_6_DETAILED_PLAN.md`: 4~6단계 상세 계획.
- `PHASE7_EXECUTION_PLAN.md`: Cubism 통합 실행 플랜.
- `PHASE7_1_SDK_INSTALLATION.md`: SDK 설치/검증 절차(Phase 7-1).
- `CUBISM_SDK_INSTALLATION.md`: Cubism SDK 설치/검증 가이드.
- `LIVE2D_PHASE7_COMPLETION_PLAN.md`: 7단계 완료 기준/공백 정리.
- `PHASE8_STABILIZATION_CHECKLIST.md`: 안정화 체크리스트.
- `PHASE9_INTERACTION_SETTINGS.md`: 상호작용 설정 정비.
- `PHASE10_IMPLEMENTATION_PLAN.md`: 고급 기능 구현 범위.

### 4) Request2 오토파일럿/게이트
- `REQUEST2_AUTOPILOT_30M_ORCHESTRATION_PLAN_2026-02-27.md`: 30분 오토파일럿 운영 규칙.
- `REQUEST2_PART1_AUTOPILOT_EXECUTION_CONTROL_2026-02-27.md`: Part1 통제 원칙.
- `REQUEST2_PART1_GATE_EXECUTION_PLAN_2026-02-27.md`: Part1 게이트 실행 기준.
- `REQUEST2_PART1_DEV_DELIVERABLE_2026-02-27.md`: Part1 개발 산출물 보고.
- `REQUEST2_PART1_AUTOGEN_FOLLOWUPS.md`: 자동 생성 후속 태스크.
- `REQUEST2_QA_AUTOPILOT_EXECUTION_PLAN_2026-02-27.md`: QA 오토파일럿 실행 스펙.
- `REQUEST2_QA_TEAM_DELIVERABLE_2026-02-27.md`: QA팀 산출물 요약.
- `PART1_QA_GATE_MATRIX_2026-02-27.md`: Part1 QA 게이트 매트릭스.
- `PART2_ITERATION_LOOP.md`: Part2 반복 실행 루프.
- `STABILIZATION_CHECKLIST_AUTOMATION.md`: 안정화 자동 점검.

### 5) Non-core 운영
- `OPS_NON_CORE_MISSION_SPLIT_2026-02-26.md`: non-core 미션 분할.
- `NON_CORE_LANE_COORDINATOR_REFRESH_2026-02-26.md`: 레인 운영 재정의.
- `NON_CORE_LANE_BLOCKER_REASSIGN_GUIDE.md`: 블로커 재배정 가이드.

### 6) 감사/리팩터링/기능기획
- `IMPLEMENTATION_STATUS_AUDIT.md`: 구현 상태 감사 및 결손 분석.
- `MOTION_SYSTEM_OVERHAUL_PLAN.md`: 모션 시스템 재설계.
- `IMAGE_AND_SCREEN_SHARE_DEVELOPMENT_PLAN.md`: 이미지 첨부 + 화면공유 기능 설계.
- `REFACTORING_SUMMARY.md`: 리팩터링 전후 구조 요약.

## 중복/겹침 포인트
- SDK 설치 문서 중복: `CUBISM_SDK_INSTALLATION.md` <-> `PHASE7_1_SDK_INSTALLATION.md`.
- Phase7 상태/실행 중복: `LIVE2D_PHASE7_COMPLETION_PLAN.md`, `PHASE7_EXECUTION_PLAN.md`, `NATIVE_LIVE2D_MIGRATION_PLAN.md`.
- Request2 운영 규칙 반복: `REQUEST2_AUTOPILOT_30M_*`, `REQUEST2_PART1_*`, `PART1_QA_GATE_MATRIX_*`.
- QA 계획/결과 반복: `QA_EXECUTION_PLAN.md`, `QA_DELIVERABLE_REPORT.md`, `REQUEST2_QA_*`.

## 권장 읽기 순서 (빠른 온보딩)
1. `IMPLEMENTATION_STATUS_AUDIT.md`
2. `NEWCASTLE_INTEGRATED_EXECUTION_PLAN_2026-02-27.md`
3. `REQUEST2_PART1_GATE_EXECUTION_PLAN_2026-02-27.md`
4. `ANDROID_RELEASE_LOGGING_EXECUTION_PLAN.md`
5. `NEWCASTLE_ANDROID_REAL_DEVICE_VALIDATION_MATRIX_2026-02-27.md`
6. `PHASE7_EXECUTION_PLAN.md`
7. `NATIVE_LIVE2D_MIGRATION_PLAN.md`
8. `MOTION_SYSTEM_OVERHAUL_PLAN.md`
9. `APK_RELEASE_QA_TEST_MATRIX_2026-02-26.md`
10. `REQUEST2_AUTOPILOT_30M_ORCHESTRATION_PLAN_2026-02-27.md`

## 최소 운영 세트(권장)
- 실제 작업 기준 마스터 문서 8~10개만 우선 유지하고, 나머지는 부록/아카이브로 분리 권장.
- 시작 추천 8개:
  - `IMPLEMENTATION_STATUS_AUDIT.md`
  - `NEWCASTLE_INTEGRATED_EXECUTION_PLAN_2026-02-27.md`
  - `REQUEST2_PART1_GATE_EXECUTION_PLAN_2026-02-27.md`
  - `ANDROID_RELEASE_LOGGING_EXECUTION_PLAN.md`
  - `NEWCASTLE_ANDROID_REAL_DEVICE_VALIDATION_MATRIX_2026-02-27.md`
  - `PHASE7_EXECUTION_PLAN.md`
  - `NATIVE_LIVE2D_MIGRATION_PLAN.md`
  - `APK_RELEASE_QA_TEST_MATRIX_2026-02-26.md`
