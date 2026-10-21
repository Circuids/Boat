# WAV test assets

Bundled WAV clips for the media playback screen.

## Expected format

- Container: RIFF/WAVE
- Encoding: PCM (`audioFormat = 1`), 16-bit
- Channels: 1 (mono) or 2 (stereo)
- Sample rate: any (the media bus configures its output from the file header)

`WAVE_FORMAT_EXTENSIBLE` (`0xFFFE`) and IEEE float (`3`) are rejected by the
native reader — see the proposal's WAV reader contract.

## Files

| File | Purpose |
|------|---------|
| `click.wav` | Short UI cue (~150 ms), used for the basic playback and looping scenarios |

Generate with any audio tool, or produce a silent clip:

```powershell
# 150 ms of silence, 48 kHz stereo 16-bit
ffmpeg -f lavfi -i anullsrc=r=48000:cl=stereo -t 0.15 -c:a pcm_s16le click.wav
```
