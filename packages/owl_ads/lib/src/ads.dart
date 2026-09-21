import 'events.dart';
import 'models.dart';

/// Provider-neutral advertising operations supported by the first release.
abstract interface class Ads {
  bool get initialized;

  Stream<AdEvent> get events;

  Future<void> init(AdConsent consent);

  Future<void> updateConsent(AdConsent consent);

  Future<void> loadReward(AdPlacement placement, {RewardOptions? options});

  Future<bool> isRewardReady(AdPlacement placement);

  /// Completes after the ad closes or a show failure is reported.
  Future<RewardResult> showReward(AdPlacement placement);

  Future<void> loadInsert(AdPlacement placement);

  Future<bool> isInsertReady(AdPlacement placement);

  /// Completes after the ad closes and throws on a show failure.
  Future<void> showInsert(AdPlacement placement);

  Future<void> dispose();
}
