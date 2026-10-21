# Boat Test App — On-Device Test Checklist

> **Physical device required.** Emulators/simulators do not support AEC.
> Run on a real Android or iOS device with speaker mode enabled.

## 0. Test environment prerequisites

> **Disable Bluetooth HFP/SCO sources before routing/capture tests.** A live
> Bluetooth Hands-Free link — e.g. **Windows Phone Link "Calls"**, a car kit,
> or a paired headset — makes Android treat the peer as a Bluetooth headset.
> This causes two symptoms that look like Boat bugs but are OS behavior:
>
> - **Output routes to earpiece despite `speakerMode: true`.** `MODE_IN_COMMUNICATION`
>   prefers the active SCO call path; `setCommunicationDevice(SPEAKER)` may not
>   fully take while SCO is negotiated.
> - **Capture is quiet and gappy.** `VOICE_COMMUNICATION` capture couples to the
>   8 kHz narrowband SCO mic (not the requested 16 kHz), which is thin, AGC-suppressed,
>   and drops packets over the wireless link.
>
> **Before testing:** turn off Bluetooth, or disable Phone Link Calls / disconnect
> the headset. Confirm `Diagnostics → route = speaker` and clean capture first.
> Section 3.2/3.3 intentionally test the *connect/disconnect* behavior separately.

## 1. Lifecycle

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 1.1 | Engine starts | Settings → Start Engine | ☐ |
| 1.2 | Engine stops | Settings → Stop Engine | ☐ |
| 1.3 | Engine restarts after stop | Stop → Start again | ☐ |
| 1.4 | Dispose and relaunch | Hot restart app → Start | ☐ |
| 1.5 | Error recovery | Trigger error → state returns to idle | ☐ |

## 2. AEC (Acoustic Echo Cancellation)

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 2.1 | AEC active in diagnostics | Diagnostics → Refresh → AEC active=true | ☐ |
| 2.2 | Short AI response — no echo | Conversation → Start → Short → speak over it | ☐ |
| 2.3 | Long AI response — no echo | Conversation → Start → Long → speak over it | ☐ |
| 2.4 | Duplex sustained — clean capture | 60s conversation with Long on loop | ☐ |
| 2.5 | AEC off — echo audible | Settings → AEC off → Reconfigure → repeat 2.2 | ☐ |

## 3. Routing

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 3.1 | Default speaker route | Diagnostics → route = speaker | ☐ |
| 3.2 | Connect BT during conversation | Pair BT headset mid-conversation | ☐ |
| 3.3 | Disconnect BT during conversation | Unpair mid-conversation — no crash | ☐ |
| 3.4 | Wired headset connect/disconnect | Plug/unplug mid-conversation | ☐ |
| 3.5 | Manual route change | Settings → route = earpiece → Reconfigure | ☐ |

## 4. Playback

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 4.1 | Short response plays to completion | Conversation → Short → progress reaches 100% | ☐ |
| 4.2 | Long response plays to completion | Conversation → Long → progress reaches 100% | ☐ |
| 4.3 | Barge-in stops playback | Conversation → Long → Barge-in → playback stops | ☐ |

## 5. Latency

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 5.1 | Capture latency < 30ms | Conversation → observe Est. latency over 60s | ☐ |
| 5.2 | No frame drops under duplex | Conversation → 60s duplex → Dropped frames = 0 | ☐ |

## 6. Diagnostics

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 6.1 | Effect status reflects config | Settings → AEC off → Reconfigure → Diagnostics | ☐ |
| 6.2 | Frame counters increment | Diagnostics → Refresh during conversation | ☐ |

## 7. Media playback (independent bus)

> The media bus is **mutually exclusive** with the voice engine. It is designed
> to work while the voice engine is stopped, and to be refused while it runs.

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 7.1 | Play WAV asset with engine idle | Media → Start media → Play WAV asset | ☐ |
| 7.2 | No microphone permission prompt | Media → Start media (fresh install) | ☐ |
| 7.3 | Pause → resume retains position | Media → Play → Pause → Resume | ☐ |
| 7.4 | Seek to 50% | Media → Play → Seek 50% | ☐ |
| 7.5 | Volume 0.0 / 0.5 / 1.0 | Media → Volume slider | ☐ |
| 7.6 | Non-looping source completes | Media → Play WAV asset → wait | ☐ |
| 7.7 | Looping source restarts | Media → Play looping → wait | ☐ |
| 7.8 | Media refused while voice runs | Settings → Start Engine → Media → Start media | ☐ |
| 7.9 | Voice preempts media | Media → Play → Settings → Start Engine | ☐ |
| 7.10 | Preemption banner appears | Media → observe banner after 7.9 | ☐ |
| 7.11 | Media plays after voice stops | Settings → Stop Engine → Media → Start media → Play | ☐ |
| 7.12 | Media is not echo-cancelled | Media → Play → listen: full-band, not thin/AGC-pumped | ☐ |
| 7.13 | Source replacement changes format | Media → Play 48 kHz asset → Play 16 kHz asset (no Stop) | ☐ |
| 7.14 | No progress events after stop | Media → Play → Stop → event log shows no further progress | ☐ |
| 7.15 | Seek refused for streaming PCM | Media → (PCM source) → Seek 50% → error surfaced | ☐ |

## 8. Asymmetric voice sample rates

> Capture and playback share one audio session (AEC requires it) but may run at
> different rates. Boat does **not** resample — the consumer supplies playback
> PCM at `BoatConfig.playbackSampleRate`.

| § | Scenario | In-app flow | Pass |
|---|----------|-------------|------|
| 8.1 | Default config is symmetric | Settings → Playback rate = "Same as capture" → Start → Diagnostics | ☐ |
| 8.2 | 16 kHz capture + 24 kHz playback | Settings → Playback rate = 24000 → Reconfigure → Conversation → Short | ☐ |
| 8.3 | TTS plays at correct pitch and speed | Conversation → observe 8.2: no chipmunk/slow artifact | ☐ |
| 8.4 | AEC still active with asymmetric rates | Diagnostics → AEC active=true; speak over playback in speaker mode | ☐ |
| 8.5 | Diagnostics report both rates | Diagnostics → captureSampleRate=16000, playbackSampleRate=24000 | ☐ |
| 8.6 | Rate mismatch warns once | Play a 16 kHz frame while playback is 24 kHz → one `PLAYBACK_RATE_MISMATCH` | ☐ |
| 8.7 | `playRaw` at the configured rate is clean | Conversation → Short with 24 kHz config → no warning | ☐ |
| 8.8 | Reconfigure symmetric → asymmetric | Settings → change Playback rate → Reconfigure → both rates applied | ☐ |
| 8.9 | iOS reports the applied session rate | iOS → Diagnostics → playbackSampleRate reflects what the session granted | ☐ |