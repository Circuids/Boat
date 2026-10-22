# Boat — Copilot Instructions

## Project Identity

Boat is a production-grade realtime voice and audio engine for Flutter. It provides clean, echo-free bidirectional PCM audio with OS-level AEC, AGC, and noise suppression. The primary design target is **speaker mode** where acoustic echo cancellation is critically needed.

- **Archetype:** Flutter platform plugin (Android + iOS)
- **Package:** `com.circuids.boat`
- **Consumers:** Flutter developers building realtime AI voice applications
- **Scope:** Pure audio I/O — AI-agnostic. No networking, no VAD, no AI backend integration.

## Architecture Rules

1. **The OS is the audio authority.** AEC, AGC, and NS are handled by the OS audio stack (Android `AudioEffects`, iOS `AVAudioSession` voiceChat mode). Never implement software DSP in Dart or native code.
2. **No manual echo reference feeding.** Flutter cannot provide sample-accurate timing. The OS handles reference signal routing internally via shared audio session IDs.
3. **Capture and playback share audio context.** Android: same `audioSessionId` for `AudioRecord` and `AudioTrack`. iOS: single `AVAudioEngine` graph.
4. **Speaker mode first.** Design for the hard case (loud speaker + exposed mic). If speaker mode works, everything else works.
5. **Dependency direction is one-way:** Dart API → Platform Interface → Native. Native code never calls Dart directly; events flow via EventChannel.
6. **Single engine.** All audio I/O flows through `BoatEngine`. No separate playback class. Playback that bypasses the engine breaks AEC.

## Coding Standards

### Dart
- Follow Effective Dart style.
- One public type per file. Implementation details in `lib/src/`.
- Use `flutter_lints` (see `analysis_options.yaml`).
- Prefer streams over callbacks for async data (audio frames, events).
- Use sealed classes for event hierarchies (`BoatEvent`).
- Named parameters for config classes (`BoatConfig`).
- Document all public API members with doc comments.

### Kotlin (Android)
- Use `VOICE_COMMUNICATION` audio source — the only source with AEC coupling.
- Set `MODE_IN_COMMUNICATION` before creating audio objects.
- Use high-priority threads for audio capture/playback loops.
- Query effect availability before attaching; report status via diagnostics.

### Swift (iOS)
- Use `AVAudioSession` category `.playAndRecord` with mode `.voiceChat`.
- Use `AVAudioEngine` graph (input node tap + player node).
- Voice processing (AEC/AGC/NS) is implicit in voiceChat mode — do not add explicit effects.
- Handle route change notifications via `AVAudioSession.routeChangeNotification`.

### Comments
- Explain **intent, invariants, and platform constraints** — not code.
- Required: security decisions, platform-specific workarounds, AEC-related constraints.
- Discouraged: obvious comments, decorative comments, comments that restate code.

## Internal Pipeline Rules

The capture path uses an internal sequential pipeline (`PipelineRunner`). It is an implementation detail — the public API is unchanged.

1. **Stages never allocate.** No `new`, no boxing, no collection operations per frame. Pre-allocate everything.
2. **Stages never block.** No locks, no I/O, no waiting. In-place mutation only.
3. **Stages never call Flutter.** Only `FramePublisher` touches EventChannel. Stages never see Flutter types.
4. **Stages never throw.** Errors are caught by `PipelineRunner` with consecutive-failure disable (threshold: 50). When a stage exceeds the threshold, it is **actually disabled** — subsequent frames skip `stage.process()` for that stage. The warning is emitted once.
5. **Pipeline is internal-only.** Consumers cannot register, replace, or intercept stages. No public extension.
6. **Playback is NOT a formal pipeline.** It uses a simpler push-based path (EventChannel sink → native write).
7. **`PipelineRunner` owns the capture loop.** `AudioCaptureEngine` is a thin wrapper around `AudioRecord`/`AVAudioEngine` — it does NOT own the thread.
8. **Wire format is a contract:** seq(int64) + tsNanos(int64) + sampleRate(int32) + channelCount(int32) + pcm = 24-byte header. Both platforms must match.

## Key Files

| Path | Purpose |
|------|---------|
| `lib/boat.dart` | Public API barrel file |
| `lib/src/` | Implementation (models, engine, platform interface) |
| `android/src/main/kotlin/com/circuids/boat/` | Android native plugin |
| `android/src/main/kotlin/com/circuids/boat/pipeline/` | Android pipeline (PipelineRunner, stages, FramePublisher) |
| `ios/boat/Sources/boat/` | iOS native plugin |
| `ios/boat/Sources/boat/Pipeline/` | iOS pipeline (PipelineRunner, stages, FramePublisher) |
| `docs/core/api-design.md` (repo root) | Public API contract |
| `docs/core/architecture.md` (repo root) | System design and AEC responsibility |
| `docs/core/platform-architecture.md` (repo root) | Native platform details + pipeline |
| `docs/core/rejected-approaches.md` (repo root) | What NOT to do (and why) |
| `docs/proposals/0001-internal-audio-pipeline.md` (repo root) | Pipeline architecture proposal (implemented) |

## Testing

- Unit tests: Dart API logic, config validation, state machine transitions.
- Platform conformance: same test suite passes on Android and iOS.
- On-device integration: AEC validation in speaker mode is the critical test.
- Emulators/simulators do not support AEC. Test on physical devices.

## What NOT To Do

- ❌ Do not use WebRTC for audio processing.
- ❌ Do not implement software AEC/AGC/NS.
- ❌ Do not feed echo reference manually from Flutter.
- ❌ Do not create a separate playback class outside the engine.
- ❌ Do not use `AudioSource.MIC` or `VOICE_RECOGNITION` on Android (no AEC coupling).
- ❌ Do not add networking, VAD, or AI backend logic to this package.
- ❌ Do not add `permission_handler` or any third-party permission package. Use `BoatPermission` (built-in, zero-dependency).
- ❌ Do not call `BoatPermission.check()` inside `BoatEngine` — use `_platform.checkPermission()` to respect DI injection.
- ❌ Do not request permissions inside `BoatEngine.start()` — the gate is check-only; consumers control dialog timing via `BoatPermission.request()`.
