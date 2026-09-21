/// Ad formats recognized by the provider-neutral domain.
enum AdType { reward, insert, splash, banner, feed, draw }

/// Formats implemented by the first release.
const Set<AdType> supportedAdTypes = <AdType>{AdType.reward, AdType.insert};

enum AdReadiness { idle, loading, ready, showing, blocked }

/// Stable application-owned identity. It never contains a provider Code ID.
final class AdPlacement {
  factory AdPlacement(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw AdsException(
        AdErrorCode.invalidPlacement,
        'Ad placement name must not be empty.',
      );
    }
    return AdPlacement._(normalized);
  }

  const AdPlacement._(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AdPlacement && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AdPlacement($name)';
}

/// Host policy acceptance and personalized-ad preference.
final class AdConsent {
  const AdConsent({required this.accepted, this.personalizedAds = false});

  final bool accepted;
  final bool personalizedAds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdConsent &&
          other.accepted == accepted &&
          other.personalizedAds == personalizedAds;

  @override
  int get hashCode => Object.hash(accepted, personalizedAds);
}

/// Optional reward metadata forwarded to GroMore's request model.
final class RewardOptions {
  const RewardOptions({
    this.userId,
    this.rewardName,
    this.rewardAmount,
    this.customData,
  });

  final String? userId;
  final String? rewardName;
  final int? rewardAmount;

  /// Opaque host value forwarded through a provider's verified server-side
  /// verification field. It is correlation data, not proof of settlement.
  final String? customData;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardOptions &&
          other.userId == userId &&
          other.rewardName == rewardName &&
          other.rewardAmount == rewardAmount &&
          other.customData == customData;

  @override
  int get hashCode => Object.hash(userId, rewardName, rewardAmount, customData);
}

/// Reward state accumulated until the native ad closes.
final class RewardResult {
  const RewardResult({
    required this.rewarded,
    required this.verified,
    this.rewardName,
    this.rewardAmount,
  });

  const RewardResult.notRewarded()
    : rewarded = false,
      verified = false,
      rewardName = null,
      rewardAmount = null;

  final bool rewarded;
  final bool verified;
  final String? rewardName;
  final int? rewardAmount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardResult &&
          other.rewarded == rewarded &&
          other.verified == verified &&
          other.rewardName == rewardName &&
          other.rewardAmount == rewardAmount;

  @override
  int get hashCode => Object.hash(rewarded, verified, rewardName, rewardAmount);
}

/// GroMore exposes eCPM as a nullable string and does not document a currency
/// or numeric precision contract. The raw value is deliberately preserved.
final class AdRevenue {
  const AdRevenue({
    this.networkName,
    this.networkPlacementId,
    this.rawEcpm,
    this.requestId,
  });

  final String? networkName;
  final String? networkPlacementId;
  final String? rawEcpm;
  final String? requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdRevenue &&
          other.networkName == networkName &&
          other.networkPlacementId == networkPlacementId &&
          other.rawEcpm == rawEcpm &&
          other.requestId == requestId;

  @override
  int get hashCode =>
      Object.hash(networkName, networkPlacementId, rawEcpm, requestId);
}

/// Stable application-facing error codes.
enum AdErrorCode {
  invalidPlacement,
  unsupportedAdFormat,
  configurationInvalid,
  configurationConflict,
  consentRequired,
  restartRequired,
  initializationFailed,
  invalidState,
  alreadyLoading,
  notReady,
  presenterUnavailable,
  nativeLoadFailed,
  nativeShowFailed,
  disposed,
  nativeError,
  unknown,
}

/// Normalized failure with provider diagnostics kept separate.
final class AdsException implements Exception {
  AdsException(
    this.code,
    this.message, {
    this.nativeCode,
    this.nativeDomain,
    this.nativeMessage,
    Map<String, String> nativeDetails = const <String, String>{},
  }) : nativeDetails = Map<String, String>.unmodifiable(nativeDetails);

  final AdErrorCode code;
  final String message;
  final String? nativeCode;
  final String? nativeDomain;
  final String? nativeMessage;
  final Map<String, String> nativeDetails;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdsException &&
          other.code == code &&
          other.message == message &&
          other.nativeCode == nativeCode &&
          other.nativeDomain == nativeDomain &&
          other.nativeMessage == nativeMessage &&
          _mapsEqual(other.nativeDetails, nativeDetails);

  @override
  int get hashCode => Object.hash(
    code,
    message,
    nativeCode,
    nativeDomain,
    nativeMessage,
    Object.hashAll(
      (nativeDetails.keys.toList()..sort()).map(
        (key) => Object.hash(key, nativeDetails[key]),
      ),
    ),
  );

  @override
  String toString() => 'AdsException(${code.name}): $message';
}

bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// Produces a stable unsupported-format result before a provider is invoked.
Never rejectUnsupportedAdType(AdType type) {
  throw AdsException(
    AdErrorCode.unsupportedAdFormat,
    'Ad format ${type.name} is not supported by this release.',
  );
}
