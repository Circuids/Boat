## 1.0.0 (unreleased)

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

#### Documentation

- Complete architecture documentation in `docs/core/`
- API design contract in `docs/core/api-design.md`
- Rejected approaches preserved from voice_core prototype
- Copilot instructions for AI-assisted development
