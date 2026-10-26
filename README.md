# Crypto Research mobile 1.2
Native SwiftUI/Java apps with public quotes, mobile CSV backtesting and foreground real-time paper execution. No private API or credentials in mobile binaries.

Mobile strategy MOBILE_PAPER_EMA_SPOT_V2 is independent from the preserved Python v1.6 engine: long-only spot EMA9/21, 30-bar warmup, next-open paper fills, 10% cash allocation including fee, 1.5% stop / 3% target, 5% start-equity loss entry gate, fees/slippage configurable 0..100 bps. These are software defaults, not a recommendation. No full v1.1 multi-factor or v1.7 implementation is claimed.
CSV needs UTF8 timestamp,open,high,low,close,volume, explicit UTC offset and strictly increasing valid bars, <=8MB / 50000 bars. Input files/configs are never overwritten. Input price currency equals starting-capital currency; no implicit USDT/KRW conversion. CSV ends by liquidating the hypothetical position with costs; live pause keeps residual paper holdings and does not simulate a forced fill.
Live paper uses observed Upbit KRW ticker prices in 1-minute buckets; this is observed-price OHLC, not an exchange-complete trade tape. First partial bucket is discarded, 30 completed buckets are required. Stale/gapped quotes and background transitions pause the session without inventing candles or fills. New sessions explicitly reset the simulated account.

Android: JDK17, SDK35, Gradle8.9; `gradle assembleDebug testDebugUnitTest lintDebug` in android/. iOS16+, Xcode26+, XcodeGen; `xcodegen generate`, then build/test CryptoResearch scheme. CI packages an unsigned ARM64 IPA. User must re-sign with their own Apple account before installation. Android development APK is debug-signed. No Store submission or physical installation is claimed.

OnCare design reference: native bottom tabs, rounded cards, large type and blue accents, iOS26 Liquid Glass controls with older-OS/reduced-transparency fallback. Legacy desktop/Python source remains separate and unchanged.

User-operated live trading preparation is supplied separately in operator/ in the local delivery ZIP, not linked to the mobile paper engine. The agent never starts it or calls private order APIs. Never put exchange keys in apps, source, CI, issue/chat or ZIPs. See local operator README for setup and unsupported/unverified boundaries.

## 1.2 research analytics
Additive report schema2 preserves existing mode, fills and summary keys, adds equity_curve/bar_timestamp_ms, structured fill_records, nullable win_rate/profit_factor_net, quote-currency total_fees and explicit truncation/time/currency metadata. CSV final liquidation costs are reflected in the final curve point; algorithm and golden ending equity remain unchanged.
Native read-only report cards show a curve and latest100 fills, with peak/trough-preserving display sampling. Metrics always use all closed trades, not sampled display points. CSV retains up to50000 curve points; foreground live retains3600, and fills5000. These bounds and undefined ratios are explicit. Live warmup progress shows0..30 closed observed bars.
