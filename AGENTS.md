# OnCare native redesign

The user requested a native redesign around OnCare. This supersedes the earlier Flutter host architecture for this isolated project. Do not edit the source applications or older IPA packages.

- iPhone implementation must contain only Swift/SwiftUI and native system/ML libraries. Do not restore Flutter, Dart, WebViews, method channels or a UIKit launcher shell.
- Keep OnCare's five tabs, state owners, privacy filters, medication notification routing, deep-theme preferences and semantic surfaces. Daily services are real NavigationLink destinations inside the existing home. Keep each service's data separate.
- Keep Crypto Research as a separate Swift module to avoid RootView/type collisions. Preserve HTTPS-only server connection, existing Keychain namespaces, per-order manual confirmation and ambiguous-order handling. Never use real keys, place/cancel orders or enable live automation during agent tests.
- Preserve both model hashes in tool/verify_native.py. YAMNet input is mono 16 kHz float32, 15,600 samples, hop 7,680, output [1,521], indexes speech=0/dog=69/bark=70. Do not label scores as accuracy or emotions. Merge overlapping windows before counting candidate intervals.
- No microphone, HealthKit or location permission at app startup. Pet recording is bounded to 60 seconds and stops on departure/background. Reject a pet recording while SleepSoundStore is running; never silently interrupt another recording.
- Atomic native pet storage must not overwrite an unreadable index. Imported audio is bounded to 50 MB, 120 seconds and a bounded decoded buffer. No raw audio upload.
- Same app.caresuite.super bundle is intentional for the existing unified app's health data and Keychain access. Native pet history has a separate folder; do not silently convert/delete old Flutter records. Read docs/PARITY.md before describing feature completeness.
- Verify source/model hashes, native device build, zero Flutter binaries, both extensions, Swift unit tests including synthetic audio inference, and UI navigation tests. Preserve old IPA until the new build is verified. Signing and physical-device proof are separate.
- Package only tracked app source, model/license resources, tests and build instructions. No actual credentials, signing files, recordings, health exports, operator/server settings, or repository-secret injection.
