# PCM Test Assets

Raw PCM clips used by `MockAudioServer` to simulate AI voice responses streamed
to `engine.playRaw(Uint8List)`.

## Format

- **Container:** None (raw PCM, no WAV header)
- **Sample rate:** 16000 Hz
- **Bit depth:** 16-bit signed, little-endian
- **Channels:** 1 (mono)

This matches `BoatConfig` defaults and `BoatEngine.playRaw()` expectations.

## Files

| File | Duration | Purpose |
|------|----------|---------|
| `ai_response_short.pcm` | ~3s | Short AI reply — barge-in and routing tests |
| `ai_response_long.pcm` | ~10s | Sustained playback — AEC duplex stress |

## Regenerating

Assets are deterministic synthesized tones (warble/sweep), not recorded speech.
Regenerate with:

```sh
dart run tool/gen_assets.dart
```

They are intentionally synthetic: deterministic, repeatable, and license-free.
Real speech recordings can be dropped in as replacements if perceptual AEC
verification is needed, provided they match the format above.