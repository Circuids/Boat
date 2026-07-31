## 1.0.0-preview

### Changed

- **Android routing (behavioral fix):** `speakerMode: true` no longer forces the loudspeaker when earbuds/headphones are connected. External devices (Bluetooth, wired, USB) now always take priority; `speakerMode` and `preferredRoute` only affect the fallback when no external device is connected. Connecting or disconnecting a device after engine start now re-applies routing automatically via `RoutePolicy`. iOS behavior is unchanged (OS-managed routing was already correct).

### Fixed

- **Android initial-start routing:** the engine now force-applies routing to the OS at start. Previously the detected route was only stored in a field, so the OS default could win — `speakerMode: true` could produce earpiece audio (the `MODE_IN_COMMUNICATION` default) and legacy Bluetooth connected at start never established SCO.
- **Android route actuator hardening:** `setCommunicationDevice()` (API 31+) return value is now checked; on failure the route falls back to the legacy path instead of silently no-oping. Legacy Bluetooth SCO (API 26-30) is guarded by a 3-second timeout that falls back to speaker if SCO fails to establish. Consumer-initiated `setRoute()` now persists across device changes until an external device connects (previously the next device change silently overrode the consumer's choice).

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
