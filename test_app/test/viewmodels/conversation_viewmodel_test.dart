import 'dart:typed_data';

import 'package:boat/boat.dart';
import 'package:boat_diagnostics/services/boat_engine_service.dart';
import 'package:boat_diagnostics/services/metrics_collector.dart';
import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:boat_diagnostics/viewmodels/app_viewmodel.dart';
import 'package:boat_diagnostics/viewmodels/conversation_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_boat_platform.dart';

AudioFrame _frame(int seq) => AudioFrame(
      pcm: Uint8List(640),
      sequenceNumber: seq,
      timestamp: Duration(milliseconds: seq * 20),
      sampleRate: 16000,
      channelCount: 1,
    );

void main() {
  late FakeBoatPlatform platform;
  late BoatEngineService engineService;
  late AppViewModel appVM;
  late MockAudioServer mockServer;
  late MetricsCollector metrics;
  late ConversationViewModel vm;

  setUp(() {
    platform = FakeBoatPlatform();
    BoatPlatform.instance = platform;
    engineService = BoatEngineService();
    appVM = AppViewModel(engineService);
    metrics = MetricsCollector();
    mockServer = MockAudioServer(engineService);
    vm = ConversationViewModel(appVM, mockServer, metrics);
  });

  tearDown(() async {
    vm.dispose();
    try {
      final state = engineService.engine.state;
      if (state == BoatState.running || state == BoatState.paused) {
        await engineService.engine.stop();
      }
    } catch (_) {}
    appVM.dispose();
    engineService.dispose();
  });

  test('starts in idle phase', () {
    expect(vm.phase.value, ConversationPhase.idle);
    expect(vm.isDuplex.value, false);
  });

  test('startConversation transitions to listening and subscribes to capture',
      () async {
    await vm.startConversationCommand.execute();
    expect(vm.phase.value, ConversationPhase.listening);

    platform.emitFrame(_frame(0));
    platform.emitFrame(_frame(1));
    await Future<void>.delayed(Duration.zero);
    expect(metrics.captureFrameCount.value, 2);
    expect(vm.captureFrameCount.value, 2);
  });

  test('startConversation starts engine if not running', () async {
    expect(appVM.engineState.value, BoatState.idle);
    await vm.startConversationCommand.execute();
    // Allow the BoatStateChanged event to propagate through the stream.
    await Future<void>.delayed(Duration.zero);
    expect(appVM.engineState.value, BoatState.running);
    expect(platform.startedConfigs, hasLength(1));
  });

  test('stopConversation returns to idle but keeps engine running', () async {
    await vm.startConversationCommand.execute();
    await Future<void>.delayed(Duration.zero);
    await vm.stopConversationCommand.execute();
    await Future<void>.delayed(Duration.zero);
    expect(vm.phase.value, ConversationPhase.idle);
    // Engine stays running so Play Capture can use the playback path.
    expect(appVM.engineState.value, BoatState.running);
  });

  test('bargeIn cancels playback and returns to listening', () async {
    await vm.startConversationCommand.execute();
    // Simulate entering aiSpeaking phase directly.
    vm.phase.value = ConversationPhase.aiSpeaking;
    vm.bargeInCommand.execute();
    expect(vm.phase.value, ConversationPhase.listening);
    expect(vm.aiResponseProgress.value, 0.0);
    expect(platform.flushCount, 1);
  });

  test('commands respect canExecute based on phase', () {
    expect(vm.startConversationCommand.canExecute, true);
    expect(vm.stopConversationCommand.canExecute, false);
    expect(vm.bargeInCommand.canExecute, false);

    vm.phase.value = ConversationPhase.listening;
    expect(vm.startConversationCommand.canExecute, false);
    expect(vm.stopConversationCommand.canExecute, true);
    // Parameterized command: canExecute takes the argument.
    expect(vm.triggerAiResponseCommand.canExecute('any'), true);

    vm.phase.value = ConversationPhase.aiSpeaking;
    expect(vm.bargeInCommand.canExecute, true);
    expect(vm.triggerAiResponseCommand.canExecute('any'), false);
  });

  test('isDuplex tracks duplex phase', () {
    vm.phase.value = ConversationPhase.duplex;
    expect(vm.isDuplex.value, true);
    vm.phase.value = ConversationPhase.listening;
    expect(vm.isDuplex.value, false);
  });

  test('metrics forward from service to VM', () {
    metrics.onCaptureFrame(_frame(0));
    metrics.onCaptureFrame(_frame(5));
    metrics.onPlayback();
    expect(vm.captureFrameCount.value, 2);
    expect(vm.droppedFrames.value, 4);
    expect(vm.playbackFrameCount.value, 1);
  });
}