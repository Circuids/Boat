import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';

/// Settings screen: toggles for AEC/AGC/NS, sample rate, speaker mode, route,
/// and a reconfigure button that hot-applies the config to the running engine.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (locator) => SettingsViewModel(locator.get<AppViewModel>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
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
        _EffectToggles(),
        SizedBox(height: 16),
        _SampleRateSelector(),
        SizedBox(height: 16),
        _RouteSelector(),
        SizedBox(height: 24),
        _ReconfigureButton(),
      ],
    );
  }
}

class _EffectToggles extends StatelessWidget {
  const _EffectToggles();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _ToggleTile('AEC', (vm) => vm.aec),
          _ToggleTile('AGC', (vm) => vm.agc),
          _ToggleTile('Noise Suppression', (vm) => vm.noiseSuppression),
          _ToggleTile('Speaker Mode', (vm) => vm.speakerMode),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final ObservableProperty<bool> Function(SettingsViewModel vm) selector;
  const _ToggleTile(this.title, this.selector);

  @override
  Widget build(BuildContext context) {
    return Bind<SettingsViewModel, bool>(
      bind: selector,
      builder: (context, value, update) => SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: update,
      ),
    );
  }
}

class _SampleRateSelector extends StatelessWidget {
  const _SampleRateSelector();

  @override
  Widget build(BuildContext context) {
    const rates = [8000, 16000, 32000, 48000];
    return Bind.viewModel<SettingsViewModel>(
      builder: (context, vm) => Card(
        child: ListTile(
          title: const Text('Sample rate'),
          trailing: DropdownButton<int>(
            value: vm.sampleRate.value,
            items: rates
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text('$r Hz'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) vm.sampleRate.value = v;
            },
          ),
        ),
      ),
    );
  }
}

class _RouteSelector extends StatelessWidget {
  const _RouteSelector();

  @override
  Widget build(BuildContext context) {
    final routes = AudioRoute.values;
    return Bind.viewModel<SettingsViewModel>(
      builder: (context, vm) => Card(
        child: ListTile(
          title: const Text('Preferred route'),
          trailing: DropdownButton<AudioRoute>(
            value: vm.preferredRoute.value,
            items: routes
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) vm.preferredRoute.value = v;
            },
          ),
        ),
      ),
    );
  }
}

class _ReconfigureButton extends StatelessWidget {
  const _ReconfigureButton();

  @override
  Widget build(BuildContext context) {
    return Command<SettingsViewModel>(
      command: (vm) => vm.reconfigureCommand,
      builder: (context, execute, canExecute, isRunning) => FilledButton.icon(
        onPressed: canExecute ? execute : null,
        icon: isRunning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.tune),
        label: const Text('Reconfigure Engine'),
      ),
    );
  }
}