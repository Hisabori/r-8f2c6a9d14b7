# Crypto Research mobile

Native SwiftUI iOS and Java Android clients for public crypto prices and offline research-report viewing. No orders, accounts, credentials, private exchange APIs, background services or analytics.

- Six Upbit KRW vs Binance spot USDT tickers, daily Frankfurter USD/KRW or explicit manual FX.
- FX premium assumes USDT=USD; domestic USDT basis is separate. Missing/stale/skewed quotes remain unavailable.
- Foreground-only observed charts, favorites, local preferences, in-app premium alerts, JSON report import and public snapshot export.
- Mobile does not execute the Windows Python CSV/SQLite strategy engine. v1.7 signal/liquidity evaporation remains planned. Original v1.0/v1.1 settings are never rewritten.

## Build
Android: JDK17, Android SDK35, Gradle8.9. From android: `gradle assembleDebug testDebugUnitTest lintDebug`. Development APK: app/build/outputs/apk/debug/app-debug.apk. Debug signing is for development only.
iOS: macOS, Xcode26+, XcodeGen. From ios: `xcodegen generate`; `xcodebuild -project CryptoResearch.xcodeproj -scheme CryptoResearch -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`. The workflow packages an unsigned IPA. Re-sign with your own Apple account using Sideloadly/AltStore/SideStore before installation. No App Store submission.

## Design
References OnCare chat: large rounded numbers, generous spacing, 22pt card padding, 26pt corners, blue/teal accents, native bottom tabs. iOS26 uses Liquid Glass for controls with reduced-transparency/older-OS fallback. Android uses native large titles and touch-friendly cards; no WebView or local server.

## Validation boundaries
Unit tests cover price math, missing/stale/future quotes, skew, alert priming/rearming/cooldown. CI builds a device IPA, runs simulator unit tests and captures actual simulator UI. Package checks and simulator checks do not establish physical-device operation or investment performance.
