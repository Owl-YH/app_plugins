import 'dart:collection';

import 'package:owl_ads/owl_ads.dart';

final class GroMoreAdUnit {
  factory GroMoreAdUnit({
    required AdType type,
    required String androidCodeId,
    required String iosCodeId,
  }) {
    if (!supportedAdTypes.contains(type)) {
      rejectUnsupportedAdType(type);
    }
    final android = androidCodeId.trim();
    final ios = iosCodeId.trim();
    if (android.isEmpty || ios.isEmpty) {
      throw AdsException(
        AdErrorCode.configurationInvalid,
        'Every GroMore ad unit requires non-empty Android and iOS Code IDs.',
      );
    }
    return GroMoreAdUnit._(type: type, androidCodeId: android, iosCodeId: ios);
  }

  const GroMoreAdUnit._({
    required this.type,
    required this.androidCodeId,
    required this.iosCodeId,
  });

  final AdType type;
  final String androidCodeId;
  final String iosCodeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroMoreAdUnit &&
          other.type == type &&
          other.androidCodeId == androidCodeId &&
          other.iosCodeId == iosCodeId;

  @override
  int get hashCode => Object.hash(type, androidCodeId, iosCodeId);
}

/// Provider-specific optional data access. Every field is denied by default.
///
/// These flags only control verified GroMore privacy hooks. Android runtime
/// permissions, iOS ATT, Info.plist usage descriptions, and host privacy policy
/// presentation remain the application's responsibility.
final class GroMoreAccess {
  const GroMoreAccess({
    this.canUseLocation = false,
    this.canUsePhoneState = false,
    this.canUseWifiState = false,
    this.canUseWriteExternalStorage = false,
    this.canUseOaid = false,
    this.canUseAndroidId = false,
    this.canUseInstalledApps = false,
    this.canUseRecordAudio = false,
    this.canUseIdfa = false,
    this.canUploadDeviceInfo = false,
  });

  final bool canUseLocation;
  final bool canUsePhoneState;
  final bool canUseWifiState;
  final bool canUseWriteExternalStorage;
  final bool canUseOaid;
  final bool canUseAndroidId;
  final bool canUseInstalledApps;
  final bool canUseRecordAudio;
  final bool canUseIdfa;
  final bool canUploadDeviceInfo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroMoreAccess &&
          other.canUseLocation == canUseLocation &&
          other.canUsePhoneState == canUsePhoneState &&
          other.canUseWifiState == canUseWifiState &&
          other.canUseWriteExternalStorage == canUseWriteExternalStorage &&
          other.canUseOaid == canUseOaid &&
          other.canUseAndroidId == canUseAndroidId &&
          other.canUseInstalledApps == canUseInstalledApps &&
          other.canUseRecordAudio == canUseRecordAudio &&
          other.canUseIdfa == canUseIdfa &&
          other.canUploadDeviceInfo == canUploadDeviceInfo;

  @override
  int get hashCode => Object.hashAll(<bool>[
    canUseLocation,
    canUsePhoneState,
    canUseWifiState,
    canUseWriteExternalStorage,
    canUseOaid,
    canUseAndroidId,
    canUseInstalledApps,
    canUseRecordAudio,
    canUseIdfa,
    canUploadDeviceInfo,
  ]);
}

final class GroMoreConfig {
  factory GroMoreConfig({
    required String androidAppId,
    required String iosAppId,
    required Map<AdPlacement, GroMoreAdUnit> units,
    GroMoreAccess access = const GroMoreAccess(),
    bool debugLogging = false,
  }) {
    final android = androidAppId.trim();
    final ios = iosAppId.trim();
    if (android.isEmpty || ios.isEmpty) {
      throw AdsException(
        AdErrorCode.configurationInvalid,
        'GroMore requires non-empty Android and iOS App IDs.',
      );
    }
    if (units.isEmpty) {
      throw AdsException(
        AdErrorCode.configurationInvalid,
        'At least one GroMore ad unit is required.',
      );
    }
    final copy = Map<AdPlacement, GroMoreAdUnit>.of(units);
    if (copy.length != units.length) {
      throw AdsException(
        AdErrorCode.configurationInvalid,
        'GroMore placement names must be unique.',
      );
    }
    return GroMoreConfig._(
      androidAppId: android,
      iosAppId: ios,
      units: UnmodifiableMapView(copy),
      access: access,
      debugLogging: debugLogging,
    );
  }

  const GroMoreConfig._({
    required this.androidAppId,
    required this.iosAppId,
    required this.units,
    required this.access,
    required this.debugLogging,
  });

  final String androidAppId;
  final String iosAppId;
  final Map<AdPlacement, GroMoreAdUnit> units;
  final GroMoreAccess access;
  final bool debugLogging;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroMoreConfig &&
          other.androidAppId == androidAppId &&
          other.iosAppId == iosAppId &&
          other.access == access &&
          other.debugLogging == debugLogging &&
          _unitMapsEqual(other.units, units);

  @override
  int get hashCode {
    final entries = units.entries.toList()
      ..sort((left, right) => left.key.name.compareTo(right.key.name));
    return Object.hash(
      androidAppId,
      iosAppId,
      access,
      debugLogging,
      Object.hashAll(
        entries.map((entry) => Object.hash(entry.key, entry.value)),
      ),
    );
  }

  GroMoreAdUnit unitFor(AdPlacement placement, AdType expectedType) {
    final unit = units[placement];
    if (unit == null) {
      throw AdsException(
        AdErrorCode.invalidPlacement,
        'No GroMore ad unit is configured for ${placement.name}.',
      );
    }
    if (unit.type != expectedType) {
      throw AdsException(
        AdErrorCode.configurationInvalid,
        'Placement ${placement.name} is ${unit.type.name}, not '
        '${expectedType.name}.',
      );
    }
    return unit;
  }
}

bool _unitMapsEqual(
  Map<AdPlacement, GroMoreAdUnit> left,
  Map<AdPlacement, GroMoreAdUnit> right,
) {
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
