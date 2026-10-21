import 'package:boat/boat_media.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

import '../viewmodels/media_viewmodel.dart';

/// Exercises the media bus: playback, transport, and mutual exclusion.
///
/// Works with the voice engine stopped — that is the point of the media bus.
class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Fairy.of<MediaViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Media Playback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(vm: vm),
          Bind<MediaViewModel, String?>(
            bind: (vm) => vm.preemptionReason,
            builder: (context, reason, _) => reason == null
                ? const SizedBox.shrink()
                : Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.pause_circle_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Media preempted — the voice engine took the '
                              'audio session ($reason).',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Session',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: vm.start,
                    child: const Text('Start media'),
                  ),
                  OutlinedButton(
                    onPressed: vm.stop,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Sources',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => vm.playAsset('assets/wav/click.wav'),
                    child: const Text('Play WAV asset'),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        vm.playAsset('assets/wav/click.wav', loop: true),
                    child: const Text('Play looping'),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Transport',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: vm.pause,
                    child: const Text('Pause'),
                  ),
                  OutlinedButton(
                    onPressed: vm.resume,
                    child: const Text('Resume'),
                  ),
                  OutlinedButton(
                    onPressed: () => vm.seekToFraction(0.5),
                    child: const Text('Seek 50%'),
                  ),
                  OutlinedButton(
                    onPressed: vm.flush,
                    child: const Text('Flush'),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Volume',
            children: [
              Bind<MediaViewModel, double>(
                bind: (vm) => vm.volume,
                builder: (context, volume, _) => Slider(
                  value: volume,
                  onChanged: vm.setVolume,
                ),
              ),
            ],
          ),
          _Section(
            title: 'Event log',
            children: [
              Bind<MediaViewModel, List<String>>(
                bind: (vm) => vm.log,
                builder: (context, lines, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines.reversed.take(12))
                      Text(line, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vm});

  final MediaViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bind<MediaViewModel, BoatMediaState>(
              bind: (vm) => vm.state,
              builder: (context, state, _) => Text(
                'State: ${state.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Bind<MediaViewModel, int>(
              bind: (vm) => vm.positionMs,
              builder: (context, pos, _) => Bind<MediaViewModel, int>(
                bind: (vm) => vm.durationMs,
                builder: (context, dur, _) => Text(
                  dur < 0
                      ? 'Position: ${pos}ms (duration unknown)'
                      : 'Position: ${pos}ms / ${dur}ms',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Bind<MediaViewModel, String?>(
              bind: (vm) => vm.lastError,
              builder: (context, error, _) => error == null
                  ? const SizedBox.shrink()
                  : Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
