import 'dart:async';

import 'package:flutter/material.dart';
import 'package:owl_ads_gromore/owl_ads_gromore.dart';

import 'example_config.dart';

void main() => runApp(const GroMoreExampleApp());

class GroMoreExampleApp extends StatelessWidget {
  const GroMoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GroMore real-ad example',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const GroMoreExampleScreen(),
  );
}

class GroMoreExampleScreen extends StatefulWidget {
  const GroMoreExampleScreen({super.key});

  @override
  State<GroMoreExampleScreen> createState() => _GroMoreExampleScreenState();
}

class _GroMoreExampleScreenState extends State<GroMoreExampleScreen> {
  static final rewardPlacement = AdPlacement('example_reward');
  static final insertPlacement = AdPlacement('example_insert');

  GroMoreAds? _ads;
  StreamSubscription<AdEvent>? _eventsSubscription;
  bool _consentAccepted = false;
  bool _busy = false;
  bool _rewardReady = false;
  bool _insertReady = false;
  final List<String> _log = <String>[];

  List<String> get _missing => ExampleConfig.missingRequiredKeys;

  @override
  void dispose() {
    unawaited(_eventsSubscription?.cancel());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } on Object catch (error) {
      _append('ERROR $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _initialize() => _run(() async {
    ExampleConfig.requireRealCredentials();
    if (!_consentAccepted) {
      throw StateError('Accept the host privacy policy before initialization.');
    }
    final ads = _ads ??= GroMoreAds.configure(
      GroMoreConfig(
        androidAppId: ExampleConfig.androidAppId,
        iosAppId: ExampleConfig.iosAppId,
        debugLogging: true,
        units: <AdPlacement, GroMoreAdUnit>{
          rewardPlacement: GroMoreAdUnit(
            type: AdType.reward,
            androidCodeId: ExampleConfig.rewardAndroidCodeId,
            iosCodeId: ExampleConfig.rewardIosCodeId,
          ),
          insertPlacement: GroMoreAdUnit(
            type: AdType.insert,
            androidCodeId: ExampleConfig.insertAndroidCodeId,
            iosCodeId: ExampleConfig.insertIosCodeId,
          ),
        },
      ),
    );
    _eventsSubscription ??= ads.events.listen(
      (event) => _append(
        '${event.kind.name} ${event.adType.name}/'
        '${event.placement.name} generation=${event.requestGeneration}',
      ),
    );
    await ads.init(
      AdConsent(accepted: true, personalizedAds: _consentAccepted),
    );
    _append('initialized');
  });

  Future<void> _withdrawConsent() => _run(() async {
    setState(() => _consentAccepted = false);
    await _ads?.updateConsent(const AdConsent(accepted: false));
    setState(() {
      _rewardReady = false;
      _insertReady = false;
    });
    _append('consent withdrawn; new requests are blocked');
  });

  Future<void> _loadReward() => _run(() async {
    await _requireAds.loadReward(
      rewardPlacement,
      options: RewardOptions(
        userId: ExampleConfig.rewardUserId,
        rewardName: ExampleConfig.rewardName,
        rewardAmount: ExampleConfig.rewardAmount,
        customData: ExampleConfig.rewardCustomData,
      ),
    );
    final ready = await _requireAds.isRewardReady(rewardPlacement);
    setState(() => _rewardReady = ready);
  });

  Future<void> _showReward() => _run(() async {
    final result = await _requireAds.showReward(rewardPlacement);
    setState(() => _rewardReady = false);
    _append(
      'reward close: rewarded=${result.rewarded}, '
      'verified=${result.verified}; backend SSV remains authoritative',
    );
  });

  Future<void> _loadInsert() => _run(() async {
    await _requireAds.loadInsert(insertPlacement);
    final ready = await _requireAds.isInsertReady(insertPlacement);
    setState(() => _insertReady = ready);
  });

  Future<void> _showInsert() => _run(() async {
    await _requireAds.showInsert(insertPlacement);
    setState(() => _insertReady = false);
    _append('insert closed');
  });

  GroMoreAds get _requireAds {
    final ads = _ads;
    if (ads == null || !ads.initialized) {
      throw StateError('Initialize GroMore first.');
    }
    return ads;
  }

  void _append(String message) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, message);
      if (_log.length > 80) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    return Scaffold(
      appBar: AppBar(title: const Text('GroMore real-ad example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (missing.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Missing real credentials: ${missing.join(', ')}. '
                  'See dart_defines.example.json.',
                ),
              ),
            ),
          CheckboxListTile(
            value: _consentAccepted,
            title: const Text('Host privacy policy accepted'),
            subtitle: const Text(
              'This example does not request Android permissions or iOS ATT.',
            ),
            onChanged: _busy
                ? null
                : (value) => setState(() => _consentAccepted = value ?? false),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _busy || missing.isNotEmpty ? null : _initialize,
                child: const Text('Initialize'),
              ),
              OutlinedButton(
                onPressed: _busy || _ads == null ? null : _withdrawConsent,
                child: const Text('Withdraw consent'),
              ),
              FilledButton.tonal(
                onPressed: _busy || _ads?.initialized != true
                    ? null
                    : _loadReward,
                child: const Text('Load reward'),
              ),
              FilledButton.tonal(
                onPressed: _busy || !_rewardReady ? null : _showReward,
                child: Text('Show reward (ready=$_rewardReady)'),
              ),
              FilledButton.tonal(
                onPressed: _busy || _ads?.initialized != true
                    ? null
                    : _loadInsert,
                child: const Text('Load insert'),
              ),
              FilledButton.tonal(
                onPressed: _busy || !_insertReady ? null : _showInsert,
                child: Text('Show insert (ready=$_insertReady)'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Domain events and outcomes'),
          const Divider(),
          for (final entry in _log) SelectableText(entry),
        ],
      ),
    );
  }
}
