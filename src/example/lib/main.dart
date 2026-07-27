import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:boat/boat.dart';

void main() {
  runApp(const BoatExampleApp());
}

class BoatExampleApp extends StatelessWidget {
  const BoatExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boat Engine',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const EngineHarness(),
    );
  }
}

class EngineHarness extends StatefulWidget {
  const EngineHarness({super.key});

  @override
  State<EngineHarness> createState() => _EngineHarnessState();
}

class _EngineHarnessState extends State<EngineHarness> {
  final _engine = BoatEngine();
  final _log = <String>[];
  StreamSubscription<AudioFrame>? _captureSub;
  StreamSubscription<BoatEvent>? _eventSub;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _eventSub = _engine.events.listen((e) {
      _addLog('EVENT: $e');
    });
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    _eventSub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    setState(() => _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 23)} $msg'));
    if (_log.length > 100) _log.removeLast();
  }

  Future<void> _requestPermission() async {
    final status = await BoatPermission.request(PermissionType.microphone);
    _addLog('PERMISSION: $status');
  }

  Future<void> _start() async {
    try {
      _captureSub = _engine.captureFrames.listen((frame) {
        _frameCount++;
        if (_frameCount % 50 == 0) {
          _addLog('Frame #${frame.sequenceNumber} (${frame.duration.inMilliseconds}ms, ${frame.byteLength}B)');
        }
      });
      await _engine.start();
      _addLog('Engine started — state: ${_engine.state}');
    } catch (e) {
      _addLog('START FAILED: $e');
    }
  }

  Future<void> _stop() async {
    await _captureSub?.cancel();
    _captureSub = null;
    await _engine.stop();
    _addLog('Engine stopped — state: ${_engine.state}');
  }

  Future<void> _dispose() async {
    await _captureSub?.cancel();
    await _eventSub?.cancel();
    await _engine.dispose();
    _addLog('Engine disposed');
  }

  void _playTone() {
    const sampleRate = 16000;
    const samples = sampleRate * 20 ~/ 1000;
    final pcm = ByteData(samples * 2);
    for (var i = 0; i < samples; i++) {
      final t = i / sampleRate;
      final value = (32767 * 0.3 * _sin(2 * 3.14159 * 440 * t)).round();
      pcm.setInt16(i * 2, value, Endian.little);
    }
    _engine.playRaw(pcm.buffer.asUint8List());
    _addLog('Played 20ms 440Hz tone');
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159);
    if (x > 3.14159) x -= 2 * 3.14159;
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  Future<void> _showDiagnostics() async {
    try {
      final diag = await _engine.diagnostics;
      _addLog('DIAG: $diag');
    } catch (e) {
      _addLog('DIAG FAILED: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boat Engine Harness')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _requestPermission, child: const Text('Request Mic')),
                FilledButton(onPressed: _start, child: const Text('Start')),
                FilledButton.tonal(onPressed: _stop, child: const Text('Stop')),
                FilledButton.tonal(onPressed: _playTone, child: const Text('Play Tone')),
                FilledButton.tonal(onPressed: _showDiagnostics, child: const Text('Diagnostics')),
                FilledButton.tonal(onPressed: _dispose, child: const Text('Dispose')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _log.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(_log[i], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
