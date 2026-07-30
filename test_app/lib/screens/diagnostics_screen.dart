import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/diagnostics_viewmodel.dart';

/// Diagnostics dashboard: refresh and display [BoatDiagnostics] — effect
/// status, route, frame counts, uptime.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (locator) => DiagnosticsViewModel(locator.get<AppViewModel>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Diagnostics')),
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
      children: [
        Command<DiagnosticsViewModel>(
          command: (vm) => vm.refreshCommand,
          builder: (context, execute, canExecute, isRunning) => FilledButton.icon(
            onPressed: canExecute ? execute : null,
            icon: isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 16),
        Bind.viewModel<DiagnosticsViewModel>(
          builder: (context, vm) {
            final diag = vm.diagnostics.value;
            if (diag == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No diagnostics yet. Tap Refresh.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard('Device', '${diag.deviceModel} (${diag.osVersion})'),
                _InfoCard('Audio session', '${diag.audioSessionId}'),
                _InfoCard('Route', diag.currentRoute.name),
                _InfoCard('Available routes',
                    diag.availableRoutes.map((r) => r.name).join(', ')),
                if (diag.scoDeviceConnected)
                  _InfoCard('BT SCO link', 'ACTIVE — capture degraded (8 kHz)'),
                _InfoCard('Capture frames', '${diag.captureFrameCount}'),
                _InfoCard('Playback frames', '${diag.playbackFrameCount}'),
                _InfoCard('Uptime', '${diag.uptime.inSeconds}s'),
                const SizedBox(height: 8),
                Text('Effect status',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final entry in diag.effectStatus.entries)
                  _EffectCard(entry.key.name, entry.value),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value),
      ),
    );
  }
}

class _EffectCard extends StatelessWidget {
  final String name;
  final EffectStatus status;
  const _EffectCard(this.name, this.status);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name.toUpperCase()),
        subtitle: Text(
          'supported: ${status.supported}  available: ${status.available}  active: ${status.active}',
        ),
        trailing: Icon(
          status.active ? Icons.check_circle : Icons.cancel,
          color: status.active ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}