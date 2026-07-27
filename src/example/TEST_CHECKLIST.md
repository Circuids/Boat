# Boat On-Device Test Checklist

All tests MUST run on a **physical device** — emulators/simulators do not support AEC.

## Prerequisites

- [ ] Physical Android device (API 23+) connected via USB
- [ ] Physical iOS device (iOS 13+) connected via USB
- [ ] Bluetooth earbuds paired
- [ ] Wired headphones with mic available
- [ ] Quiet room for AEC testing

## 1. Basic Lifecycle

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 1.1 | Start engine with defaults | State → running, capture frames flowing | [ ] | [ ] |
| 1.2 | Stop engine | State → idle, frames stop | [ ] | [ ] |
| 1.3 | Start → Pause → Resume | State transitions correct, frames resume | [ ] | [ ] |
| 1.4 | Dispose engine | State → disposed, subsequent calls throw | [ ] | [ ] |
| 1.5 | Start after stop (restart) | Works, frames flow again | [ ] | [ ] |

## 2. AEC Validation (Critical)

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 2.1 | Start engine (speaker mode, AEC on) | Engine running | [ ] | [ ] |
| 2.2 | Play voice sample through speaker | Audio audible from speaker | [ ] | [ ] |
| 2.3 | Speak during playback | Recording contains voice, NOT echo | [ ] | [ ] |
| 2.4 | Compare with AEC disabled | Recording contains obvious echo | [ ] | [ ] |
| 2.5 | Play loud music + speak | Voice captured cleanly over music | [ ] | [ ] |

## 3. Audio Routing

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 3.1 | Connect Bluetooth earbuds during conversation | Audio routes to BT, no interruption | [ ] | [ ] |
| 3.2 | Disconnect Bluetooth during conversation | Falls back to speaker, no crash | [ ] | [ ] |
| 3.3 | Plug wired headphones during conversation | Audio routes to wired | [ ] | [ ] |
| 3.4 | Unplug wired headphones during conversation | Falls back to speaker | [ ] | [ ] |
| 3.5 | setRoute(bluetooth) with no BT device | Graceful fallback, no crash | [ ] | [ ] |

## 4. Playback

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 4.1 | playRaw() with valid PCM | Audio plays through speaker | [ ] | [ ] |
| 4.2 | flushPlayback() during playback | Audio stops immediately | [ ] | [ ] |
| 4.3 | Rapid playRaw() calls (100 frames) | No crash, no glitch accumulation | [ ] | [ ] |

## 5. Latency

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 5.1 | Measure capture-to-Flutter delivery | < 30ms (20ms frame + 10ms channel) | [ ] | [ ] |
| 5.2 | Sustained 60s capture | No frame drops, no GC pauses | [ ] | [ ] |

## 6. Diagnostics

| # | Test | Expected | Android | iOS |
|---|------|----------|---------|-----|
| 6.1 | getDiagnostics() while running | Returns effect status, route, frame counts | [ ] | [ ] |
| 6.2 | AEC effect status | supported=true, available=true, active=true | [ ] | [ ] |

## Pass Criteria

- All 2.1–2.5 MUST pass on both platforms (AEC is the core value proposition)
- All 3.1–3.4 MUST pass (routing resilience)
- 5.1 latency < 30ms on mid-range devices
