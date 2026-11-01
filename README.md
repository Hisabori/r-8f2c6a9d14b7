# Care Suite0.1.1 — iPhone 통합 프로젝트

Bark Note0.17, 온케어3.43, Crypto Research1.9.1을 단일 iOS앱으로 묶는 첫 통합본입니다. 오늘/온케어/강아지/투자/이동 메뉴와 공통 홈, 네이티브 모듈 복귀 버튼을 제공합니다. 기존 앱을 URL로 실행하는 런처가 아니라 Flutter Runner 안에 건강·거래 Swift패키지를 링크하는 구조입니다.

## 디렉터리
- lib/: 공통 홈·Bark Note·이동, 고정된 모듈 열기 채널
- ios/Runner/: 단일 앱 호스트, 네이티브 화면 표시·알림 전달
- ios/SuperModules/: CareHealthKit와 CryptoResearchKit의 독립 Swift패키지 모듈
- ios/HealthWidgets/ 및 ios/LiveActivity/: 건강 위젯·활동과 반려/출발 활동 확장
- assets/models/, ios/HealthResources/: 해시가 고정된 기존 모델 및 라이선스
- test/, ios/SuperSuiteUITests/: 기존 테스트와 새 화면 전환 검증
- tool/: 빌드 연결·소스/최종앱 검증; .github/workflows/superapp-ios.yml: macOS 검증·IPA 패키징

## 보존 범위
온케어 건강·투약·약봉투·개인 기록, Bark Note 녹음/실시간 소리 후보/기록/이동, CryptoResearch 시세/모의전략/HTTPS서버/공통 수동주문 화면 소스를 포함했습니다. 별도 Swift모듈로 같은 이름의 RootView·타입 충돌을 피합니다. 공통 홈은 건강 정보나 소리 기록을 읽어 투자에 사용하지 않습니다. 실제 키·서명·기록·녹음·원본서버실행기는 포함하지 않습니다.

새 bundle ID app.caresuite.super이므로 기존앱sandbox/Keychain을 자동으로 읽지 않습니다. 기존 데이터는 사용자 가져오기·페어링으로, 거래서버는 새 토큰 연결로 사용합니다. 이동 서비스 API키도 복사하지 않으며 미설정 기능은 기존 오류/안내 상태로 남습니다. 건강 읽기·녹음·실주문은 모듈을 선택한 뒤 사용자가 별도로 승인/시작합니다. 소리 분석은 검증된 감정 번역/진단이 아니고 약 일정 일치는 임상 상호작용 판단이 아닙니다.

## macOS 빌드
Flutter3.47.7, Xcode26+, Ruby Xcodeproj1.27.0 필요.
```sh
flutter pub get
gem install xcodeproj -v 1.27.0 --no-document --user-install
ruby tool/add_live_activity.rb
ruby tool/integrate_native.rb
python3 tool/verify_superapp.py
flutter analyze
flutter test
dart tool/check_bark_insights.dart
flutter build ios --release --no-codesign
python3 tool/verify_superapp.py --app build/ios/iphoneos/Runner.app
```
그 뒤 시뮬레이터 통합 UI검사를 통과해야 워크플로가 IPA를 패키징합니다. 무서명 IPA는 본인 계정으로 앱/두 확장/HealthKit 권한에 맞게 재서명해야 합니다. 개별앱의 기존 IPA 검증은 통합본 검증을 대신하지 않습니다. 현재 증거는 validation.json을 확인하세요.

## 다음 검증 기준
1. macOS에서 두 Swift패키지/ONNX/두 위젯 확장까지 단일기기앱 빌드 성공.
2. 시뮬레이터에서 온케어·거래 화면 진입/슈퍼홈 복귀, 강아지 녹음 권한 거절/파일선택, 큰 글씨/VoiceOver 확인.
3. 실기기에서 수면 녹음↔짖음 녹음 전환 시 오디오 종료, 권한 독립, 투약 알림·위젯 딥링크·저장복원 확인.
4. 기존앱사용자가 직접 가져오기/재연결하고 결과를 확인. 자동 데이터 합치기나 건강↔거래 데이터 변환 금지.
5. 실주문 테스트는 사용자 서버와 사용자 확인으로만 수행하고 에이전트는 가짜 전송만 사용.

기술 근거: https://developer.apple.com/documentation/swiftui/uihostingcontroller , https://docs.flutter.dev/platform-integration/ios


## OnCare design and continuity

OnCare is the shared design baseline: grouped light background #F2F2F7, opaque white content cards with 30-point corners, blue #387DF5, and 20–22-point content padding. Keep glass bounded to navigation. Preserve large text, reduced motion and accessible tap targets. Use ordinary feature names rather than app-launcher language. Native module hosts are reused within the process so returning to the common home does not recreate the module stores or discard the current screen. Do not auto-open permissions or orders. This is navigation continuity, not cross-domain data sharing. Verify native return/re-entry and lifecycle behavior on macOS and a physical device before claiming completion.
