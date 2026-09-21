import 'package:flutter/services.dart';
import 'package:owl_ads/owl_ads.dart';

import 'gromore_config.dart';
import 'pigeon/gromore_api.g.dart';

NativeConsent toNativeConsent(AdConsent consent) => NativeConsent(
  accepted: consent.accepted,
  personalizedAds: consent.personalizedAds,
);

NativeAccess toNativeAccess(GroMoreAccess access) => NativeAccess(
  canUseLocation: access.canUseLocation,
  canUsePhoneState: access.canUsePhoneState,
  canUseWifiState: access.canUseWifiState,
  canUseWriteExternalStorage: access.canUseWriteExternalStorage,
  canUseOaid: access.canUseOaid,
  canUseAndroidId: access.canUseAndroidId,
  canUseInstalledApps: access.canUseInstalledApps,
  canUseRecordAudio: access.canUseRecordAudio,
  canUseIdfa: access.canUseIdfa,
  canUploadDeviceInfo: access.canUploadDeviceInfo,
);

NativeAdType toNativeAdType(AdType type) => switch (type) {
  AdType.reward => NativeAdType.reward,
  AdType.insert => NativeAdType.insert,
  _ => rejectUnsupportedAdType(type),
};

AdType fromNativeAdType(NativeAdType type) => switch (type) {
  NativeAdType.reward => AdType.reward,
  NativeAdType.insert => AdType.insert,
};

AdErrorCode normalizedCode(String value) {
  for (final code in AdErrorCode.values) {
    if (code.name == value) {
      return code;
    }
  }
  return AdErrorCode.nativeError;
}

AdsException fromNativeDiagnostic(NativeDiagnostic diagnostic) => AdsException(
  normalizedCode(diagnostic.normalizedCode),
  diagnostic.message,
  nativeCode: diagnostic.nativeCode,
  nativeDomain: diagnostic.nativeDomain,
  nativeMessage: diagnostic.nativeMessage,
  nativeDetails: Map<String, String>.unmodifiable(diagnostic.details),
);

AdsException fromPlatformException(
  PlatformException error, {
  required AdErrorCode fallback,
}) {
  final details = <String, String>{};
  if (error.details is Map<Object?, Object?>) {
    for (final entry in (error.details as Map<Object?, Object?>).entries) {
      if (entry.key != null && entry.value != null) {
        details[entry.key.toString()] = entry.value.toString();
      }
    }
  }
  final mapped = normalizedCode(error.code);
  return AdsException(
    mapped == AdErrorCode.nativeError ? fallback : mapped,
    error.message ?? 'GroMore platform operation failed.',
    nativeCode: details['nativeCode'] ?? error.code,
    nativeDomain: details['nativeDomain'],
    nativeMessage: details['nativeMessage'] ?? error.message,
    nativeDetails: Map<String, String>.unmodifiable(details),
  );
}

RewardResult fromNativeReward(NativeRewardResult? reward) => RewardResult(
  rewarded: reward?.rewarded ?? false,
  verified: reward?.verified ?? false,
  rewardName: reward?.rewardName,
  rewardAmount: reward?.rewardAmount,
);

AdEvent? fromNativeEvent(NativeAdEvent event) {
  final kind = switch (event.kind) {
    NativeEventKind.loaded => AdEventKind.loaded,
    NativeEventKind.shown => AdEventKind.shown,
    NativeEventKind.clicked => AdEventKind.clicked,
    NativeEventKind.closed => AdEventKind.closed,
    NativeEventKind.failed => AdEventKind.failed,
    NativeEventKind.rewarded => AdEventKind.rewarded,
    NativeEventKind.revenue => AdEventKind.revenue,
    NativeEventKind.unknown => null,
  };
  if (kind == null) {
    return null;
  }
  final revenue = event.revenue;
  return AdEvent(
    kind: kind,
    placement: AdPlacement(event.placement),
    adType: fromNativeAdType(event.adType),
    requestGeneration: event.generation,
    error: event.error == null ? null : fromNativeDiagnostic(event.error!),
    reward: event.reward == null ? null : fromNativeReward(event.reward),
    revenue: revenue == null
        ? null
        : AdRevenue(
            networkName: revenue.networkName,
            networkPlacementId: revenue.networkPlacementId,
            rawEcpm: revenue.rawEcpm,
            requestId: revenue.requestId,
          ),
  );
}
