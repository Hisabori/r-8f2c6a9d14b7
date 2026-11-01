# Care Suite integrated iOS project

User authorized integrating Bark Note, OnCare and Crypto Research into one iPhone application. Keep snapshots isolated from the original project directories. Do not modify their repositories or running agents.

- Flutter owns the common home, Bark Note and transit. Two local Swift packages own OnCare and Crypto Research. Expose only module navigation through app.caresuite/native; never pass health/medication/audio contents to trading APIs.
- Preserve OnCare research/medication limitations and privacy filters. Sound patterns are not validated dog emotion translation or veterinary diagnosis. Preserve model hashes and licenses.
- Preserve manual per-order review/confirmation, HTTPS-only trade APIs, separate Keychain namespace, at-most-once server execution and ambiguous-result policy. Agent tests must use fake transports, with no real exchange keys, accounts, orders, live activation or deployment.
- Do not autostart microphone, HealthKit, background services or trades from the common home. Module entry is a user action. Test stopping audio when switching modules and exiting the app on real devices.
- New app bundle ID means a new sandbox and Keychain access group. Do not claim automatic migration from old apps. Use explicit import/reconnection only.
- Exclude source app signing-store, build-config.json, secrets, recordings, journals, exports, keystores and profiles from ZIPs/CI/publication. No build should inject repository API secrets automatically.
- Run flutter analyze, flutter test and python3 tool/verify_superapp.py. Native integration additionally needs macOS, pinned Xcodeproj helper, device build, simulator UI tests, then payload verification before packaging an IPA.
- Do not claim an installable integrated IPA from source checks or prior individual-app builds. HealthKit and two extension identifiers need suitable signing profiles when the user re-signs.


## OnCare design and continuity

OnCare is the shared design baseline: grouped light background #F2F2F7, opaque white content cards with 30-point corners, blue #387DF5, and 20–22-point content padding. Keep glass bounded to navigation. Preserve large text, reduced motion and accessible tap targets. Use ordinary feature names rather than app-launcher language. Native module hosts are reused within the process so returning to the common home does not recreate the module stores or discard the current screen. Do not auto-open permissions or orders. This is navigation continuity, not cross-domain data sharing. Verify native return/re-entry and lifecycle behavior on macOS and a physical device before claiming completion.
