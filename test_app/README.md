# Boat Real-World Test App

A standalone Flutter application that exercises Boat's full-duplex audio
pipeline against a simulated server, using [Fairy](https://pub.dev/packages/fairy)
MVVM for state management. The existing `src/boat/example/` harness is retained
unchanged as the plugin's minimal smoke test.

## What this app tests

The app reproduces the real acoustic loop a production consumer would build:
sustained playback (simulated AI response) overlapping with microphone capture,
in speaker mode, on a physical device — the condition AEC must handle.

- **Conversation screen** — start/stop the engine, trigger AI responses
  (short/long PCM clips), barge-in, live metrics (frame count, drops, latency).
- **Diagnostics screen** — refresh and display `BoatDiagnostics` (effect status,
  route, frame counts, uptime).
- **Settings screen** — toggle AEC/AGC/NS, sample rate, speaker mode, route;
  hot-reconfigure the running engine.

## Architecture

```
View (Flutter)          ViewModel (Fairy)         Service (FairyLocator)
ConversationScreen  →   ConversationViewModel  →   MockAudioServer
DiagnosticsScreen   →   DiagnosticsViewModel  →   BoatEngineService
SettingsScreen      →   SettingsViewModel     →   MetricsCollector
HomeScreen           →   AppViewModel (global)  →   BoatEngine (single)
```

- **Services** are registered as `FairyLocator` singletons (app-lifetime).
- **Page ViewModels** are scoped via `FairyScope` (auto-disposed on navigation).
- **Metrics** flow from `MetricsCollector` (service) through
  `ConversationViewModel` (VM) to the view — the view never binds to a service
  directly.

## Running

```sh
cd test_app
flutter pub get
flutter run
```

> **Physical device required.** Emulators and simulators do not support AEC.
> Use a real Android or iOS device with speaker mode enabled.

## Testing

```sh
flutter test        # unit + widget tests
flutter analyze     # static analysis
```

## PCM assets

Raw PCM clips (16kHz, 16-bit, mono) are bundled in `assets/pcm/`. Regenerate
with `dart run tool/gen_assets.dart`. See `assets/pcm/README.md` for format
details.

## On-device test runbook

See `TEST_CHECKLIST.md` for the full on-device scenario matrix mapped to in-app
flows.
