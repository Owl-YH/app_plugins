import 'dart:async';

import 'package:flutter/material.dart';
import 'package:owl_haptics/owl_haptics.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  OwlHapticHandle? _active;
  String _status = 'Idle';

  @override
  void dispose() {
    unawaited(_active?.cancel());
    unawaited(OwlHaptics.stop());
    super.dispose();
  }

  void _play(OwlHaptic haptic) {
    final previous = _active;
    final current = OwlHaptics.play(haptic);
    _active = current;
    unawaited(previous?.cancel());
    setState(() => _status = 'Starting');
    unawaited(
      current.started
          .then((_) {
            if (mounted && identical(_active, current)) {
              setState(() => _status = 'Started');
            }
          })
          .catchError((Object error) {
            if (mounted && identical(_active, current)) {
              setState(() => _status = 'Failed: $error');
            }
          }),
    );
  }

  void _cancel() {
    final current = _active;
    _active = null;
    unawaited(current?.cancel());
    setState(() => _status = 'Canceled');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('owl_haptics')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_status, key: const ValueKey('status')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _play(const OwlHaptic.selection()),
              child: const Text('Selection'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.impact(OwlHapticStrength.light)),
              child: const Text('Light impact'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.impact(OwlHapticStrength.medium)),
              child: const Text('Medium impact'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.impact(OwlHapticStrength.heavy)),
              child: const Text('Heavy impact'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.outcome(OwlHapticOutcome.success)),
              child: const Text('Success outcome'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.outcome(OwlHapticOutcome.warning)),
              child: const Text('Warning outcome'),
            ),
            FilledButton(
              onPressed: () =>
                  _play(const OwlHaptic.outcome(OwlHapticOutcome.error)),
              child: const Text('Error outcome'),
            ),
            FilledButton(
              onPressed: () => _play(
                OwlHaptic.sequence([
                  for (var index = 0; index < 6; index += 1)
                    OwlHapticPulse(
                      at: Duration(milliseconds: index * 100),
                      strength: index < 2
                          ? OwlHapticStrength.light
                          : index < 4
                          ? OwlHapticStrength.medium
                          : OwlHapticStrength.heavy,
                    ),
                ]),
              ),
              child: const Text('Six-pulse sequence'),
            ),
            OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
