## 1.0.0-preview.1

### Documentation

- Rewrote the public (pub.dev) and repository READMEs following the Circuids package style — centered logo, table of contents, problem-first narrative, full API reference, architecture diagram, and design philosophy.
- Added a **Rejected Approaches** section documenting tried-and-discarded architectures (WebRTC client-side loop, manual echo reference feeding, Flutter-level DSP, `permission_handler`, separate playback class, and others) so the design rationale is visible.
- Added the full Apache License 2.0 text to `LICENSE` and a trademark policy in `TRADEMARKS.md`.
- Added the cover logo to both READMEs.

No public API or platform channel changes.

---

## 1.0.0-preview

### Initial Release

Boat — production-grade realtime voice and audio engine for Flutter, optimized for **speaker mode** where AEC is critically needed.

#### Features

- **Audio Capture** — 16-bit PCM via platform-native APIs with OS-level processing
- **Audio Playback** — Low-latency, AEC-coupled playback through the engine
- **Acoustic Echo Cancellation (AEC)** — OS-level (Android `AudioEffects`, iOS `voiceChat` mode)
- **Automatic Gain Control (AGC)** — Level normalization for consistent audio
- **Noise Suppression (NS)** — Environmental noise reduction
- **Unified Engine** — Single `BoatEngine` for capture + playback (no separate playback class)
- **Hot Reconfiguration** — Change sample rate, effects, or route without full restart
- **Audio Routing** — Speaker / earpiece / Bluetooth / wired headset
- **Lifecycle Management** — start / stop / pause / resume / dispose
- **State Observation** — Stream-based typed events (`BoatEvent` sealed hierarchy)
- **Diagnostics API** — Device info, effect status, session statistics
- **Typed Exceptions** — `BoatConfigException`, `BoatPermissionException`, `BoatNativeException`, `BoatStateException`

#### Architecture Highlights

- OS audio stack is the authority — no software DSP, no WebRTC
- Shared audio session between capture and playback for AEC correlation
- `VOICE_COMMUNICATION` source on Android (only source with AEC coupling)
- `AVAudioSession` voiceChat mode on iOS (implicit voice processing)
- Dual-platform from v1.0 (Android API 23+, iOS 13.0+)
