import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

import '../services/metrics_collector.dart';
import '../services/mock_audio_server.dart';
import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/conversation_viewmodel.dart';

/// Full-duplex conversation screen: start/stop, trigger AI response,
/// barge-in, live metrics. The central AEC validation surface.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (locator) => ConversationViewModel(
        locator.get<AppViewModel>(),
        locator.get<MockAudioServer>(),
        locator.get<MetricsCollector>(),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: const _Body(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _PhaseIndicator(),
        SizedBox(height: 16),
        _EngineControls(),
        SizedBox(height: 16),
        _ConversationControls(),
        SizedBox(height: 16),
        _AiResponseControls(),
        SizedBox(height: 16),
        _RecordingControls(),
        SizedBox(height: 16),
        _MetricsPanel(),
      ],
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator();

  @override
  Widget build(BuildContext context) {
    return Bind.viewModel<ConversationViewModel>(
      builder: (context, vm) {
        final phase = vm.phase.value;
        final color = switch (phase) {
          ConversationPhase.idle => Colors.grey,
          ConversationPhase.listening => Colors.green,
          ConversationPhase.aiSpeaking => Colors.blue,
          ConversationPhase.duplex => Colors.orange,
        };
        return Chip(
          avatar: Icon(_phaseIcon(phase), color: color),
          label: Text(phase.name.toUpperCase()),
        );
      },
    );
  }

  IconData _phaseIcon(ConversationPhase phase) => switch (phase) {
        ConversationPhase.idle => Icons.stop_circle_outlined,
        ConversationPhase.listening => Icons.hearing,
        ConversationPhase.aiSpeaking => Icons.graphic_eq,
        ConversationPhase.duplex => Icons.swap_vert,
      };
}

class _EngineControls extends StatelessWidget {
  const _EngineControls();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        Command<AppViewModel>(
          command: (vm) => vm.startEngineCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.icon(
            onPressed: canExecute ? execute : null,
            icon: isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Start Engine'),
          ),
        ),
        Command<AppViewModel>(
          command: (vm) => vm.stopEngineCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.tonalIcon(
            onPressed: canExecute ? execute : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Engine'),
          ),
        ),
        Bind.viewModel<AppViewModel>(
          builder: (context, vm) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Engine: ${vm.engineState.value.name}'),
          ),
        ),
      ],
    );
  }
}

class _ConversationControls extends StatelessWidget {
  const _ConversationControls();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        Command<ConversationViewModel>(
          command: (vm) => vm.startConversationCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.icon(
            onPressed: canExecute ? execute : null,
            icon: isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic),
            label: const Text('Start Conversation'),
          ),
        ),
        Command<ConversationViewModel>(
          command: (vm) => vm.stopConversationCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.tonalIcon(
            onPressed: canExecute ? execute : null,
            icon: const Icon(Icons.mic_off),
            label: const Text('Stop Conversation'),
          ),
        ),
        Command<ConversationViewModel>(
          command: (vm) => vm.bargeInCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.tonalIcon(
            onPressed: canExecute ? execute : null,
            icon: const Icon(Icons.front_hand),
            label: const Text('Barge-in'),
          ),
        ),
      ],
    );
  }
}

class _AiResponseControls extends StatelessWidget {
  const _AiResponseControls();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trigger AI Response', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Command.param<ConversationViewModel, String>(
          command: (vm) => vm.triggerAiResponseCommand,
          builder: (context, execute, canExecute, isRunning) => Wrap(
            spacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: canExecute('assets/pcm/ai_response_short.pcm')
                    ? () => execute('assets/pcm/ai_response_short.pcm')
                    : null,
                child: const Text('Short (3s)'),
              ),
              FilledButton.tonal(
                onPressed: canExecute('assets/pcm/ai_response_long.pcm')
                    ? () => execute('assets/pcm/ai_response_long.pcm')
                    : null,
                child: const Text('Long (10s)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Bind.viewModel<ConversationViewModel>(
          builder: (context, vm) => LinearProgressIndicator(
            value: vm.aiResponseProgress.value <= 0
                ? null
                : vm.aiResponseProgress.value,
          ),
        ),
      ],
    );
  }
}

class _RecordingControls extends StatelessWidget {
  const _RecordingControls();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture Recording (AEC Verification)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Recording is automatic during conversation. After stopping, play back to hear if AEC removed the echo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // Recording status (automatic during conversation)
            Bind.viewModel<ConversationViewModel>(
              builder: (context, vm) => Row(
                children: [
                  Icon(
                    vm.isRecording.value ? Icons.fiber_manual_record : Icons.mic_none,
                    color: vm.isRecording.value ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(vm.isRecording.value
                      ? 'Recording… ${(vm.recordingDurationMs.value / 1000).toStringAsFixed(1)}s'
                      : vm.hasRecording.value
                          ? 'Recorded ${(vm.recordingDurationMs.value / 1000).toStringAsFixed(1)}s'
                          : 'Start a conversation to record'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                Command<ConversationViewModel>(
                  command: (vm) => vm.playCaptureCommand,
                  builder: (context, execute, canExecute, isRunning) =>
                      FilledButton.tonalIcon(
                    onPressed: canExecute ? execute : null,
                    icon: isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Play Capture'),
                  ),
                ),
                Command<ConversationViewModel>(
                  command: (vm) => vm.clearRecordingCommand,
                  builder: (context, execute, canExecute, isRunning) =>
                      FilledButton.tonalIcon(
                    onPressed: canExecute ? execute : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Bind<ConversationViewModel, int>(
              bind: (vm) => vm.captureFrameCount,
              builder: (context, value, _) =>
                  Text('Capture frames: $value'),
            ),
            Bind<ConversationViewModel, int>(
              bind: (vm) => vm.droppedFrames,
              builder: (context, value, _) =>
                  Text('Dropped frames: $value'),
            ),
            Bind<ConversationViewModel, double>(
              bind: (vm) => vm.estimatedLatencyMs,
              builder: (context, value, _) =>
                  Text('Est. latency: ${value.toStringAsFixed(1)} ms'),
            ),
            Bind<ConversationViewModel, int>(
              bind: (vm) => vm.playbackFrameCount,
              builder: (context, value, _) =>
                  Text('Playback frames: $value'),
            ),
          ],
        ),
      ),
    );
  }
}