# Crypto Research mobile 1.3
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

## 1.3 background and Ubuntu server
Android adds a user-started dataSync foreground service with a persistent stop notification, bounded wake lock, 5h45 session ceiling, Android15 onTimeout cleanup, explicit handoff of an existing paper session and read-only recovery of the last local report. No boot autostart or OS-limit bypass.
iOS local execution still pauses when backgrounded. Continuous paper execution is moved to the user's Ubuntu LTS server; native clients fetch status/reports and optionally start/pause paper sessions via HTTPS. Tokens use Keychain/Keystore, separate read/control roles, and no redirect forwarding. Only saved matching configurations are polled automatically while the screen is active.
Server code and Docker/Caddy setup are supplied in background_server/ in the local delivery ZIP, not in this public mobile-build repository. No server deployment, real orders, exchange authentication or power/firewall changes are performed by the agent.

## Mobile 1.4
Native read-only server operations center: diagnostics, paginated events, archived paper reports. See docs/CLIENT_1_4_KO.md. Server1.4 required for new operations; existing1.3 control/status remain compatible.

## Mobile 1.5
Android: One UI inspired native design, themes, grouped research workflow, sort/empty states and account reset confirmation. iPhone: preserve OnCare design, add native appearance choice and reset confirmation only. See docs/CLIENT_1_5_KO.md. Server remains1.4, engines/operator unchanged.

## Mobile1.6
Persist bounded local research/execution drafts, display current paper account summary, export original server report JSON, and filter archived sessions by symbol. Android One UI/iPhone OnCare remain; server stays1.4. See docs/CLIENT_1_6_KO.md.
