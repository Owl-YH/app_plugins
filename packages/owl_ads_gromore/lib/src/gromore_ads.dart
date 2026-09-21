import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:owl_ads/owl_ads.dart';

import 'gromore_config.dart';
import 'native_mapper.dart';
import 'pigeon/gromore_api.g.dart';
import 'session_registry.dart';

enum _ProviderState { created, initializing, initialized, disposed }

final class GroMoreAds implements Ads, GroMoreFlutterApi {
  GroMoreAds._(this.config)
    : _hostApi = GroMoreHostApi(),
      _events = StreamController<AdEvent>.broadcast(sync: true) {
    GroMoreFlutterApi.setUp(this);
  }

  static GroMoreAds? _shared;

  /// Returns the single GroMore runtime owned by this Dart isolate.
  ///
  /// Equivalent configuration is idempotent. GroMore's underlying SDK is
  /// process-wide, so a conflicting configuration is rejected instead of
  /// silently replacing callbacks or native state.
  static GroMoreAds configure(GroMoreConfig config) {
    final existing = _shared;
    if (existing == null) {
      return _shared = GroMoreAds._(config);
    }
    if (existing._state == _ProviderState.disposed) {
      throw AdsException(
        AdErrorCode.disposed,
        'The isolate-scoped GroMore runtime was disposed and cannot be recreated.',
      );
    }
    if (existing.config != config) {
      throw AdsException(
        AdErrorCode.configurationConflict,
        'GroMore is already configured in this isolate with another immutable configuration.',
      );
    }
    return existing;
  }

  final GroMoreConfig config;
  final GroMoreHostApi _hostApi;
  static const MethodChannel _iosHostChannel = MethodChannel(
    'com.owlllwo.plugins.gromore/methods',
  );
  final StreamController<AdEvent> _events;
  final AdSessionRegistry _sessions = AdSessionRegistry();

  _ProviderState _state = _ProviderState.created;
  AdConsent _consent = const AdConsent(accepted: false);
  Future<void>? _initializationFuture;
  AdConsent? _initializationConsent;
  int _lifecycleEpoch = 0;

  @override
  bool get initialized => _state == _ProviderState.initialized;

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> init(AdConsent consent) {
    _ensureNotDisposed();
    _ensureSupportedPlatform();
    _ensureConsent(consent);
    if (_state == _ProviderState.initialized) {
      return updateConsent(consent);
    }
    if (_state == _ProviderState.initializing) {
      if (_initializationConsent != consent) {
        throw AdsException(
          AdErrorCode.configurationConflict,
          'GroMore initialization is already in progress with different initial consent.',
        );
      }
      return _initializationFuture!;
    }
    _state = _ProviderState.initializing;
    _consent = consent;
    _initializationConsent = consent;
    final epoch = _lifecycleEpoch;
    final future = _initialize(consent, epoch);
    _initializationFuture = future;
    return future;
  }

  Future<void> _initialize(AdConsent consent, int epoch) async {
    try {
      final request = NativeInitializationRequest(
        appId: _currentAppId,
        consent: toNativeConsent(consent),
        access: toNativeAccess(config.access),
        debugLogging: config.debugLogging,
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _iosHostChannel.invokeMethod<void>('initialize', {
          'appId': request.appId,
          'consent': _consentMap(request.consent),
          'access': _accessMap(request.access),
          'debugLogging': request.debugLogging,
        });
      } else {
        await _hostApi.initialize(request);
      }
      if (_state == _ProviderState.disposed || epoch != _lifecycleEpoch) {
        throw AdsException(
          AdErrorCode.disposed,
          'GroMore was disposed before initialization completed.',
        );
      }
      _state = _ProviderState.initialized;
    } on PlatformException catch (error) {
      if (_state != _ProviderState.disposed && epoch == _lifecycleEpoch) {
        _state = _ProviderState.created;
      }
      throw fromPlatformException(
        error,
        fallback: AdErrorCode.initializationFailed,
      );
    } finally {
      if (epoch == _lifecycleEpoch) {
        _initializationFuture = null;
        _initializationConsent = null;
      }
    }
  }

  @override
  Future<void> updateConsent(AdConsent consent) async {
    _ensureNotDisposed();
    _consent = consent;
    if (!consent.accepted) {
      final invalidated = _sessions.invalidateAll(blocked: true);
      for (final session in invalidated) {
        _events.add(
          AdEvent(
            kind: AdEventKind.failed,
            placement: session.placement,
            adType: session.adType,
            requestGeneration: session.generation,
            error: AdsException(
              AdErrorCode.consentRequired,
              'Consent was withdrawn; the native ad session was invalidated.',
            ),
          ),
        );
      }
    }
    if (_state != _ProviderState.initialized) {
      return;
    }
    try {
      final request = NativePrivacyUpdate(
        consent: toNativeConsent(consent),
        access: toNativeAccess(config.access),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _iosHostChannel.invokeMethod<void>('updatePrivacy', {
          'consent': _consentMap(request.consent),
          'access': _accessMap(request.access),
        });
      } else {
        await _hostApi.updatePrivacy(request);
      }
    } on PlatformException catch (error) {
      throw fromPlatformException(error, fallback: AdErrorCode.restartRequired);
    }
  }

  @override
  Future<void> loadReward(AdPlacement placement, {RewardOptions? options}) =>
      _load(placement, AdType.reward, rewardOptions: options);

  @override
  Future<bool> isRewardReady(AdPlacement placement) =>
      _isReady(placement, AdType.reward);

  @override
  Future<RewardResult> showReward(AdPlacement placement) async {
    final result = await _show(placement, AdType.reward);
    return fromNativeReward(result.reward);
  }

  @override
  Future<void> loadInsert(AdPlacement placement) =>
      _load(placement, AdType.insert);

  @override
  Future<bool> isInsertReady(AdPlacement placement) =>
      _isReady(placement, AdType.insert);

  @override
  Future<void> showInsert(AdPlacement placement) async {
    await _show(placement, AdType.insert);
  }

  Future<void> _load(
    AdPlacement placement,
    AdType type, {
    RewardOptions? rewardOptions,
  }) async {
    _ensureOperational();
    final unit = config.unitFor(placement, type);
    final generation = _sessions.beginLoad(placement, type);
    if (generation == null) {
      return;
    }
    try {
      final request = NativeAdRequest(
        placement: placement.name,
        adType: toNativeAdType(type),
        codeId: _currentCodeId(unit),
        generation: generation,
        rewardOptions: rewardOptions == null
            ? null
            : NativeRewardOptions(
                userId: rewardOptions.userId,
                rewardName: rewardOptions.rewardName,
                rewardAmount: rewardOptions.rewardAmount,
                customData: rewardOptions.customData,
              ),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _iosHostChannel.invokeMethod<void>('loadAd', {
          'placement': request.placement,
          'adType': request.adType.name,
          'codeId': request.codeId,
          'generation': request.generation,
          'rewardOptions': request.rewardOptions == null
              ? null
              : {
                  'userId': request.rewardOptions!.userId,
                  'rewardName': request.rewardOptions!.rewardName,
                  'rewardAmount': request.rewardOptions!.rewardAmount,
                  'customData': request.rewardOptions!.customData,
                },
        });
      } else {
        await _hostApi.loadAd(request);
      }
      _sessions.markReady(placement, type, generation);
    } on PlatformException catch (error) {
      _sessions.finish(placement, type, generation);
      throw fromPlatformException(
        error,
        fallback: AdErrorCode.nativeLoadFailed,
      );
    }
  }

  Future<bool> _isReady(AdPlacement placement, AdType type) async {
    _ensureOperational();
    config.unitFor(placement, type);
    if (_sessions.readiness(placement, type) != AdReadiness.ready) {
      return false;
    }
    final generation = _sessions.currentGeneration(placement, type);
    try {
      final identity = NativeAdIdentity(
        placement: placement.name,
        adType: toNativeAdType(type),
        generation: generation,
      );
      final ready = defaultTargetPlatform == TargetPlatform.iOS
          ? await _iosHostChannel.invokeMethod<bool>(
                  'isReady',
                  _identityMap(identity),
                ) ??
                false
          : await _hostApi.isReady(identity);
      if (!ready) {
        _sessions.finish(placement, type, generation);
      }
      return ready;
    } on PlatformException catch (error) {
      throw fromPlatformException(error, fallback: AdErrorCode.nativeError);
    }
  }

  Future<NativeShowResult> _show(AdPlacement placement, AdType type) async {
    _ensureOperational();
    config.unitFor(placement, type);
    final generation = _sessions.currentGeneration(placement, type);
    if (!await _isReady(placement, type)) {
      throw AdsException(
        AdErrorCode.notReady,
        '${placement.name} does not have a ready ${type.name} ad.',
      );
    }
    _sessions.beginShow(placement, type, generation);
    try {
      final identity = NativeAdIdentity(
        placement: placement.name,
        adType: toNativeAdType(type),
        generation: generation,
      );
      final NativeShowResult result;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final value = await _iosHostChannel.invokeMapMethod<String, Object?>(
          'showAd',
          _identityMap(identity),
        );
        final reward = value?['reward'];
        final rewardMap = reward is Map<Object?, Object?> ? reward : null;
        result = NativeShowResult(
          reward: rewardMap == null
              ? null
              : NativeRewardResult(
                  rewarded: rewardMap['rewarded']! as bool,
                  verified: rewardMap['verified']! as bool,
                  rewardName: rewardMap['rewardName'] as String?,
                  rewardAmount: rewardMap['rewardAmount'] as int?,
                ),
        );
      } else {
        result = await _hostApi.showAd(identity);
      }
      _sessions.finish(placement, type, generation);
      return result;
    } on PlatformException catch (error) {
      _sessions.finish(placement, type, generation);
      throw fromPlatformException(
        error,
        fallback: AdErrorCode.nativeShowFailed,
      );
    }
  }

  @override
  void onEvent(NativeAdEvent event) {
    if (_state == _ProviderState.disposed) {
      return;
    }
    final mapped = fromNativeEvent(event);
    if (mapped == null ||
        !_sessions.accepts(
          mapped.placement,
          mapped.adType,
          mapped.requestGeneration,
          mapped.kind,
        )) {
      return;
    }
    if (mapped.kind == AdEventKind.loaded) {
      _sessions.markReady(
        mapped.placement,
        mapped.adType,
        mapped.requestGeneration,
      );
    }
    _events.add(mapped);
    if (mapped.kind == AdEventKind.closed ||
        mapped.kind == AdEventKind.failed) {
      _sessions.finish(
        mapped.placement,
        mapped.adType,
        mapped.requestGeneration,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_state == _ProviderState.disposed) {
      return;
    }
    _lifecycleEpoch += 1;
    _state = _ProviderState.disposed;
    _initializationFuture = null;
    _initializationConsent = null;
    _sessions.invalidateAll(blocked: true);
    GroMoreFlutterApi.setUp(null);
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _iosHostChannel.invokeMethod<void>('dispose');
      } else {
        await _hostApi.dispose();
      }
    } finally {
      await _events.close();
    }
  }

  String get _currentAppId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return config.androidAppId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return config.iosAppId;
    }
    throw AdsException(
      AdErrorCode.unsupportedAdFormat,
      'owl_ads_gromore supports Android and iOS only.',
    );
  }

  String _currentCodeId(GroMoreAdUnit unit) =>
      defaultTargetPlatform == TargetPlatform.android
      ? unit.androidCodeId
      : unit.iosCodeId;

  void _ensureOperational() {
    _ensureNotDisposed();
    _ensureSupportedPlatform();
    _ensureConsent(_consent);
    if (_state != _ProviderState.initialized) {
      throw AdsException(
        AdErrorCode.invalidState,
        'GroMore must be initialized successfully before loading or showing.',
      );
    }
  }

  void _ensureNotDisposed() {
    if (_state == _ProviderState.disposed) {
      throw AdsException(
        AdErrorCode.disposed,
        'This GroMoreAds instance has been disposed.',
      );
    }
  }

  void _ensureConsent(AdConsent consent) {
    if (!consent.accepted) {
      throw AdsException(
        AdErrorCode.consentRequired,
        'Host privacy-policy consent is required before advertising work.',
      );
    }
  }

  void _ensureSupportedPlatform() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw AdsException(
        AdErrorCode.unsupportedAdFormat,
        'owl_ads_gromore supports Android and iOS only.',
      );
    }
  }

  static Map<String, Object?> _consentMap(NativeConsent consent) => {
    'accepted': consent.accepted,
    'personalizedAds': consent.personalizedAds,
  };

  static Map<String, Object?> _accessMap(NativeAccess access) => {
    'canUseLocation': access.canUseLocation,
    'canUsePhoneState': access.canUsePhoneState,
    'canUseWifiState': access.canUseWifiState,
    'canUseWriteExternalStorage': access.canUseWriteExternalStorage,
    'canUseOaid': access.canUseOaid,
    'canUseAndroidId': access.canUseAndroidId,
    'canUseInstalledApps': access.canUseInstalledApps,
    'canUseRecordAudio': access.canUseRecordAudio,
    'canUseIdfa': access.canUseIdfa,
    'canUploadDeviceInfo': access.canUploadDeviceInfo,
  };

  static Map<String, Object?> _identityMap(NativeAdIdentity identity) => {
    'placement': identity.placement,
    'adType': identity.adType.name,
    'generation': identity.generation,
  };
}
