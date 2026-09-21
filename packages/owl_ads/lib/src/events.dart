import 'models.dart';

enum AdEventKind { loaded, shown, clicked, closed, failed, rewarded, revenue }

/// Normalized analytics and diagnostic event.
final class AdEvent {
  const AdEvent({
    required this.kind,
    required this.placement,
    required this.adType,
    required this.requestGeneration,
    this.error,
    this.reward,
    this.revenue,
  });

  final AdEventKind kind;
  final AdPlacement placement;
  final AdType adType;
  final int requestGeneration;
  final AdsException? error;
  final RewardResult? reward;
  final AdRevenue? revenue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdEvent &&
          other.kind == kind &&
          other.placement == placement &&
          other.adType == adType &&
          other.requestGeneration == requestGeneration &&
          other.error == error &&
          other.reward == reward &&
          other.revenue == revenue;

  @override
  int get hashCode => Object.hash(
    kind,
    placement,
    adType,
    requestGeneration,
    error,
    reward,
    revenue,
  );
}
