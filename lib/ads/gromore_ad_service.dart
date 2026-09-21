import 'package:owl_ads_gromore/owl_ads_gromore.dart';

/// Stateless composition boundary around the isolate-scoped GroMore runtime.
final class GroMorePlatformService {
  const GroMorePlatformService();

  GroMoreAds obtain(GroMoreConfig config) => GroMoreAds.configure(config);
}

/// Owns the stateful provider instance while keeping it out of the widget tree.
final class GroMoreRepository {
  GroMoreRepository(this._service);

  final GroMorePlatformService _service;
  GroMoreAds? _ads;
  bool _disposed = false;

  bool get hasProvider => _ads != null;
  bool get initialized => _ads?.initialized ?? false;

  Stream<AdEvent> get events => _requireProvider.events;

  void ensureProvider(GroMoreConfig config) {
    if (_disposed) {
      throw StateError('GroMore Runtime 已终止；请重启应用后重新初始化。');
    }
    _ads ??= _service.obtain(config);
  }

  Future<void> initialize(AdConsent consent) => _requireProvider.init(consent);

  Future<void> updateConsent(AdConsent consent) async {
    await _ads?.updateConsent(consent);
  }

  Future<void> loadReward(
    AdPlacement placement, {
    required RewardOptions options,
  }) => _requireAds.loadReward(placement, options: options);

  Future<bool> isRewardReady(AdPlacement placement) =>
      _requireAds.isRewardReady(placement);

  Future<RewardResult> showReward(AdPlacement placement) =>
      _requireAds.showReward(placement);

  Future<void> loadInsert(AdPlacement placement) =>
      _requireAds.loadInsert(placement);

  Future<bool> isInsertReady(AdPlacement placement) =>
      _requireAds.isInsertReady(placement);

  Future<void> showInsert(AdPlacement placement) =>
      _requireAds.showInsert(placement);

  Future<void> disposeProvider() async {
    final ads = _ads;
    _disposed = true;
    await ads?.dispose();
  }

  GroMoreAds get _requireProvider {
    final ads = _ads;
    if (ads == null) {
      throw StateError('请先完成 GroMore 初始化。');
    }
    return ads;
  }

  GroMoreAds get _requireAds => _requireProvider;
}
