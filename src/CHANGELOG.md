## 1.0.0-preview.2

### Features

- **Independent capture and playback sample rates** — `BoatConfig.playbackSampleRate` lets the voice session capture at one rate and play at another within the same AEC-coupled audio session, e.g. 16 kHz capture for ASR with 24 kHz TTS output. `null` (the default) means "same as `sampleRate`", so existing configs behave identically. Boat does **not** resample: supply playback PCM at `effectivePlaybackSampleRate`.
  - `BoatConfigBuilder.playbackSampleRate(int)` for fluent construction.
  - `BoatDiagnostics.captureSampleRate` / `playbackSampleRate` report the rates actually applied, so a platform that negotiates differently than requested is observable.
  - `play(AudioFrame)` emits `BoatWarning(code: 'PLAYBACK_RATE_MISMATCH')` once per session when `frame.sampleRate` differs from the configured playback rate.
- **Independent media playback bus** — `BoatMediaPlayer` plays application media (UI sounds, notification cues, bundled WAV clips) on its own OS audio session, with no relationship to AEC, AGC, noise suppression, or the capture pipeline. Import it from `package:boat/boat_media.dart`.
  - Sources: streaming PCM (`playPcm`), WAV file (`playFile`), WAV asset (`playAsset`). WAV is decoded natively — no third-party package.
  - Transport: `start` / `stop` / `pause` / `resume` / `seek` / `setVolume` / `flush`, plus `state`, `events`, and `status`.
  - Events: `BoatMediaStateChanged`, `BoatMediaProgress`, `BoatMediaCompleted`, `BoatMediaWarning`, `BoatMediaError`, `BoatMediaPreempted`.
  - Requires no microphone permission and works while `BoatEngine` is stopped.
- **Mutual exclusion between the two buses.** Media and voice are exclusive owners of the OS audio session. `BoatMediaPlayer.start()` throws `BoatMediaBusyException` while the voice engine runs; starting the voice engine stops media and emits `BoatMediaPreempted`.

### Fixes

- **iOS playback format is now explicit.** `AudioPlaybackEngine` previously derived its `AVAudioFormat` from `AVAudioSession.sampleRate` and `memcpy`'d consumer bytes into it. When the session rate differed from the rate the consumer produced, the bytes were reinterpreted rather than converted — 16 kHz PCM on a 48 kHz session played 3× fast at 3× pitch, silently. The player node is now connected at the declared playback rate and `AVAudioEngine` converts to the mixer rate.
- Removed the dead `com.circuids.boat/playback` `EventChannel` declaration. It was never registered natively, never listened to, and could not work in its documented direction (`EventChannel` is native→Dart). Playback PCM has always travelled over `com.circuids.boat/methods`.

### Compatibility

Additive. `BoatEngine`'s existing members, `BoatPlatform`, the capture pipeline, the 24-byte capture wire format, and the three voice channels are unchanged. `BoatConfig` gains one optional field; omitting it preserves current behavior exactly.

---

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
