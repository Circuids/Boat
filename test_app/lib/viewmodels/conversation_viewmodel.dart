import 'dart:async';
import 'dart:typed_data';

import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

import '../services/metrics_collector.dart';
import '../services/mock_audio_server.dart';
import 'app_viewmodel.dart';

/// Phases of the duplex conversation loop.
enum ConversationPhase { idle, listening, aiSpeaking, duplex }

/// Orchestrates the full-duplex conversation loop: capture (user speaks)
/// overlapping with playback (simulated AI response), stressing AEC.
///
/// The default scenario keeps capture active while [MockAudioServer] streams
/// PCM to the speaker — the duplex condition that AEC must handle.
///
/// Captured audio is accumulated in [_recordingBuffer] so it can be played
/// back to verify AEC quality — if AEC works, the playback of captured audio
/// should contain only your voice, not the AI response tone.
class ConversationViewModel extends ObservableObject {
  final AppViewModel _appVM;
  final MockAudioServer _mockServer;
  final MetricsCollector _metrics;

  final phase = ObservableProperty<ConversationPhase>(ConversationPhase.idle);
  final aiResponseProgress = ObservableProperty<double>(0.0);
  final isDuplex = ObservableProperty<bool>(false);

  // Metrics surfaced from MetricsCollector so the view binds to the VM,
  // never to a service directly.
  final captureFrameCount = ObservableProperty<int>(0);
  final droppedFrames = ObservableProperty<int>(0);
  final estimatedLatencyMs = ObservableProperty<double>(0.0);
  final playbackFrameCount = ObservableProperty<int>(0);

  // Recording state — accumulated capture PCM for AEC verification playback.
  final isRecording = ObservableProperty<bool>(false);
  final recordingDurationMs = ObservableProperty<int>(0);
  final hasRecording = ObservableProperty<bool>(false);
  final isPlayingCapture = ObservableProperty<bool>(false);
  final List<Uint8List> _recordingBuffer = [];
  int _recordingBytes = 0;

  StreamSubscription<AudioFrame>? _captureSub;
  StreamSubscription<double>? _playbackSub;
  void Function()? _phaseListener;
  final List<void Function()> _metricListeners = [];

  ConversationViewModel(this._appVM, this._mockServer, this._metrics) {
    _phaseListener = phase.propertyChanged(() {
      isDuplex.value = phase.value == ConversationPhase.duplex;
      startConversationCommand.notifyCanExecuteChanged();
      stopConversationCommand.notifyCanExecuteChanged();
      triggerAiResponseCommand.notifyCanExecuteChanged();
      bargeInCommand.notifyCanExecuteChanged();
    });
    // Forward metric changes from the service into the VM's own properties.
    _metricListeners.addAll([
      _metrics.captureFrameCount.propertyChanged(
        () => captureFrameCount.value = _metrics.captureFrameCount.value,
      ),
      _metrics.droppedFrames.propertyChanged(
        () => droppedFrames.value = _metrics.droppedFrames.value,
      ),
      _metrics.estimatedLatencyMs.propertyChanged(
        () => estimatedLatencyMs.value = _metrics.estimatedLatencyMs.value,
      ),
      _metrics.playbackFrameCount.propertyChanged(
        () => playbackFrameCount.value = _metrics.playbackFrameCount.value,
      ),
    ]);
    // Re-evaluate recording command availability when recording state changes.
    _metricListeners.addAll([
      hasRecording.propertyChanged(() {
        playCaptureCommand.notifyCanExecuteChanged();
        clearRecordingCommand.notifyCanExecuteChanged();
      }),
      isPlayingCapture.propertyChanged(() {
        playCaptureCommand.notifyCanExecuteChanged();
        clearRecordingCommand.notifyCanExecuteChanged();
      }),
    ]);
  }

  late final startConversationCommand = AsyncRelayCommand(
    _startConversation,
    canExecute: () => phase.value == ConversationPhase.idle,
  );

  late final stopConversationCommand = AsyncRelayCommand(
    _stopConversation,
    canExecute: () => phase.value != ConversationPhase.idle,
  );

  late final triggerAiResponseCommand = AsyncRelayCommand.param<String>(
    (assetPath) => _playAiResponse(assetPath),
    canExecute: (_) =>
        phase.value == ConversationPhase.listening ||
        phase.value == ConversationPhase.duplex,
  );

  late final bargeInCommand = RelayCommand(
    _bargeIn,
    canExecute: () =>
        phase.value == ConversationPhase.aiSpeaking ||
        phase.value == ConversationPhase.duplex,
  );

  /// Plays back the recorded capture audio through the engine's playback
  /// path so you can hear whether AEC removed the AI response from the mic.
  /// Recording is automatic during conversation — this plays it back after.
  late final playCaptureCommand = AsyncRelayCommand(
    _playCapture,
    canExecute: () => hasRecording.value && !isPlayingCapture.value,
  );

  /// Clears the recording buffer.
  late final clearRecordingCommand = RelayCommand(
    _clearRecording,
    canExecute: () => hasRecording.value && !isPlayingCapture.value,
  );

  Future<void> _playCapture() async {
    if (_recordingBuffer.isEmpty) return;
    isPlayingCapture.value = true;
    try {
      // Play back at realtime pace (20ms per frame) to hear it naturally.
      for (final chunk in _recordingBuffer) {
        _appVM.engine.playRaw(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    } finally {
      isPlayingCapture.value = false;
    }
  }

  void _clearRecording() {
    _recordingBuffer.clear();
    _recordingBytes = 0;
    hasRecording.value = false;
    recordingDurationMs.value = 0;
  }

  Future<void> _startConversation() async {
    if (_appVM.engineState.value != BoatState.running) {
      await _appVM.startEngineCommand.execute();
    }
    _metrics.reset();
    _clearRecording();
    _captureSub = _appVM.engine.captureFrames.listen((frame) {
      _metrics.onCaptureFrame(frame);
      // Auto-record all captured audio during the conversation for AEC
      // verification playback.
      _recordingBuffer.add(Uint8List.fromList(frame.pcm));
      _recordingBytes += frame.pcm.length;
      // 16-bit mono at 16kHz: bytes / 32 = ms
      recordingDurationMs.value = _recordingBytes ~/ 32;
      hasRecording.value = true;
    });
    isRecording.value = true;
    phase.value = ConversationPhase.listening;
  }

  Future<void> _playAiResponse(String assetPath) async {
    final wasListening = phase.value == ConversationPhase.listening;
    phase.value = wasListening ? ConversationPhase.duplex : ConversationPhase.aiSpeaking;
    _playbackSub = _mockServer.playResponse(assetPath).listen(
      (progress) {
        aiResponseProgress.value = progress;
        _metrics.onPlayback();
      },
      onDone: () {
        aiResponseProgress.value = 1.0;
        phase.value = ConversationPhase.listening;
      },
      onError: (Object e) {
        lastError.value = 'Playback failed: $e';
        phase.value = ConversationPhase.listening;
      },
    );
  }

  void _bargeIn() {
    _playbackSub?.cancel();
    _playbackSub = null;
    _mockServer.flush();
    aiResponseProgress.value = 0.0;
    phase.value = ConversationPhase.listening;
  }

  Future<void> _stopConversation() async {
    await _playbackSub?.cancel();
    _playbackSub = null;
    await _captureSub?.cancel();
    _captureSub = null;
    isRecording.value = false;
    phase.value = ConversationPhase.idle;
    // Engine stays running so Play Capture can use the playback path.
    // User stops the engine separately via Stop Engine button.
  }

  final lastError = ObservableProperty<String>('');

  @override
  void dispose() {
    _playbackSub?.cancel();
    _captureSub?.cancel();
    _phaseListener?.call();
    for (final cancel in _metricListeners) {
      cancel();
    }
    super.dispose();
  }
}