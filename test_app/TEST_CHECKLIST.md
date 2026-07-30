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