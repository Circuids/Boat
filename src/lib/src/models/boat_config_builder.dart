import '../common/audio_route.dart';
import 'boat_config.dart';

/// Builder for [BoatConfig] with fluent API.
class BoatConfigBuilder {
  int _sampleRate = 16000;
  int _channelCount = 1;
  int _bitsPerSample = 16;
  int _bufferDurationMs = 20;
  bool _aec = true;
  bool _agc = true;
  bool _noiseSuppression = true;
  bool _speakerMode = true;
  AudioRoute _preferredRoute = AudioRoute.speaker;

  BoatConfigBuilder sampleRate(int value) {
    _sampleRate = value;
    return this;
  }

  BoatConfigBuilder channelCount(int value) {
    _channelCount = value;
    return this;
  }

  BoatConfigBuilder bitsPerSample(int value) {
    _bitsPerSample = value;
    return this;
  }

  BoatConfigBuilder bufferDurationMs(int value) {
    _bufferDurationMs = value;
    return this;
  }

  BoatConfigBuilder aec(bool value) {
    _aec = value;
    return this;
  }

  BoatConfigBuilder agc(bool value) {
    _agc = value;
    return this;
  }

  BoatConfigBuilder noiseSuppression(bool value) {
    _noiseSuppression = value;
    return this;
  }

  BoatConfigBuilder speakerMode(bool value) {
    _speakerMode = value;
    return this;
  }

  BoatConfigBuilder preferredRoute(AudioRoute value) {
    _preferredRoute = value;
    return this;
  }

  BoatConfig build() => BoatConfig(
    sampleRate: _sampleRate,
    channelCount: _channelCount,
    bitsPerSample: _bitsPerSample,
    bufferDurationMs: _bufferDurationMs,
    aec: _aec,
    agc: _agc,
    noiseSuppression: _noiseSuppression,
    speakerMode: _speakerMode,
    preferredRoute: _preferredRoute,
  );
}
