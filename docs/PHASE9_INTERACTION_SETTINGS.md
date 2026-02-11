# Phase 9: 오류 수정 및 상호작용 설정

## 1. 오류 수정: 투명상자 동기화 문제

### 문제
- 편집 모드에서 투명상자(overlay)의 가로세로 비율 및 상대적 크기가 저장/동기화되지 않음
- 프리셋 저장/불러오기 시 overlayWidth/overlayHeight가 반영되지 않음
- 표시 설정에서 크기 변경 시 상대적 크기가 올바르게 적용되지 않음

### 수정 내용
1. `Live2DController.savePreset()` - overlayWidth/overlayHeight를 현재 Native 상태에서 동기화
2. `Live2DController.loadPreset()` - overlayWidth/overlayHeight를 Native에 반영 (`setSize`)
3. `Live2DController.setScale()` - 상대적 크기도 함께 반영
4. `Live2DNativeBridge` - 현재 오버레이 크기를 조회할 수 있는 `getOverlaySize()` 추가
5. `Live2DController` - 오버레이 크기 설정 `setOverlaySize()` 추가

## 2. 추가 기능: 상호작용 설정 화면

### 구조
기존 "제스처 설정" + "자동 동작 설정"을 통합하여 **"상호작용 설정"** 화면으로 재구성

### 2.1 모션 확인 및 테스트
- 현재 모델의 모션 그룹 목록 표시 (Native에서 가져옴)
- 각 그룹별 모션 수 표시
- 모션별 테스트 버튼 (재생)
- 표정 목록 표시 및 테스트

### 2.2 상호작용 모션 설정
- 터치, 드래그, 더블 탭 시 실행할 모션 설정
- 실제 모델의 모션/표정 목록에서 선택 가능
- 기본 상태 파라미터 (깜빡임, 호흡 등) 조절
- 액세서리, auto motion on/off 설정

### UI 구조
```
상호작용 설정
├── 탭1: 모션/표정 테스트
│   ├── 모션 그룹 목록 (확장 가능한 타일)
│   │   └── 각 모션 재생 버튼
│   └── 표정 목록
│       └── 각 표정 적용 버튼
├── 탭2: 상호작용 매핑
│   ├── 터치 → 모션/표정 선택
│   ├── 더블탭 → 모션/표정 선택
│   ├── 드래그 → 모션/표정 선택
│   └── 롱프레스 → 모션/표정 선택
└── 탭3: 자동 동작
    ├── 눈 깜빡임 on/off + 간격
    ├── 호흡 on/off + 속도
    ├── 시선 추적 on/off + 민감도
    ├── 자동 모션 on/off
    └── 액세서리 on/off
```
