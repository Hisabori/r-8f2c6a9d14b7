# 온케어 네이티브 재설계 0.4.0

기존 온케어 SwiftUI 앱을 중심으로 다시 구성한 iPhone 프로젝트입니다. Flutter 실행부·Dart 코드·플랫폼 채널을 포함하지 않습니다. 기존 Flutter 통합 IPA와 원본 세 프로젝트는 보존합니다.

온케어의 오늘·마음·건강·기록·읽을거리 하단 메뉴를 유지하고 오늘 화면의 ‘함께하는 일상’에서 반려생활·이동 준비·투자와 리서치로 직접 이동합니다. 중간 앱 실행 화면이나 공통 홈으로 돌아가는 별도 막대가 없습니다. 시스템 뒤로가기와 온케어의 색상·카드·글자 확대·선택한 테마를 사용합니다.

- App/: SwiftUI 앱 수명주기, 권한, 온케어 아이콘
- Care/: 기존 온케어 기능과 상태 소유자, 건강·투약·수면·알림·기록
- Native/: 네이티브 반려견 녹음·파일 가져오기·YAMNet 분석·기록과 MapKit 이동 준비
- Packages/CryptoResearch/: 독립 Swift 모듈, 기존 시세·전략·수동 거래 화면
- Resources/: 기존 모델과 라이선스
- HealthWidgets/, DepartureWidget/: 기존 두 확장
- Tests/, UITests/: 온케어 회귀 테스트, 네이티브 계산·합성 오디오 추론·탐색 테스트
- docs/PARITY.md: 기능 보존·차이·남은 이식 검증

## Mac에서 빌드

Xcode 26+, XcodeGen, CocoaPods가 필요합니다. 기존에 사용하던 ONNX Runtime 1.20.0과 TensorFlowLiteSwift 2.12.0을 고정합니다.

```sh
brew install xcodegen
python3 tool/verify_native.py
xcodegen generate
pod install --repo-update
xcodebuild -workspace CareSuiteNative.xcworkspace -scheme CareSuiteNative -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
python3 tool/verify_native.py --app build/device/Build/Products/Release-iphoneos/CareSuiteNative.app
xcodebuild -workspace CareSuiteNative.xcworkspace -scheme CareSuiteNative -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test
```

실제 설치된 시뮬레이터 이름으로 바꿔 실행합니다. GitHub workflow는 사용 가능한 iPhone을 자동 선택합니다. 무서명 IPA 설치에는 앱·HealthKit·두 확장에 맞는 사용자 재서명이 필요합니다. 실물 기기의 오디오 전환·권한·딥링크·서버 연결 검증은 별도입니다.

동일 bundle ID `app.caresuite.super`를 사용하므로 기존 통합본을 대체 설치할 수 있습니다. 설치 전 기존 앱에서 사용자 기록을 내보내 보관하세요. 건강·거래 저장 경로와 Keychain 이름은 유지하지만, 기존 Flutter 반려 기록을 자동 변환했다고 주장하지 않습니다.


## 코인·미국 주식 티커 분석

투자와 리서치 → 코인·미국 주식 티커 분석. 코인은 Binance 공개 USDT 확정 일봉, 미국 주식은 Alpha Vantage 일봉을 사용합니다. 미국 주식·뉴스는 사용자가 화면에서 데이터 키를 등록해야 하며 거래소 주문 키와 분리합니다. 키 없이도 코인 가격·지표를 조회하거나 연구 JSON을 가져올 수 있습니다. 자세한 계산·가중치·스키마·공급자 제약은 docs/TICKER_RESEARCH.md를 확인하세요.


## 공통 흐름·컨디션 기록·다이내믹 아일랜드

홈에서 최근 반려 기록·선택한 이동 목적지·최근 리서치를 이어 보고 바로 티커 분석으로 이동합니다. 반려 메모·이동 준비·티커와 분석은 앱 실행 중 같은 상태를 사용합니다. ‘내 건강 기록 함께 보기’를 켜고 직접 저장하면 최근 수면·오늘 마음 기록과 리서치 메모를 기기에 함께 보관합니다. 건강 값은 가격 점수·주문·외부 데이터 요청에 전달하지 않습니다.

녹음/파일 분석과 리서치 진행 표시는 각 화면에서 선택하고, 이동 준비 표시는 계산 후 직접 시작합니다. 작은 아일랜드의 숫자 폭·오래된 상태·종료 표시를 정리했으며 탭하면 해당 기능으로 돌아갑니다. 기기별 아일랜드 배치는 iOS가 결정합니다. 자세한 동작과 검증은 docs/UNIFIED_EXPERIENCE.md를 확인하세요.
