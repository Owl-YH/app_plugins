import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/gromore_api.g.dart',
    dartPackageName: 'owl_ads_gromore',
    kotlinOut:
        'android/src/main/kotlin/com/owlllwo/plugins/gromore/GromoreApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.owlllwo.plugins.gromore'),
    swiftOut: 'ios/owl_ads_gromore/Sources/owl_ads_gromore/GromoreApi.g.swift',
  ),
)
enum NativeAdType { reward, insert }

enum NativeEventKind {
  loaded,
  shown,
  clicked,
  closed,
  failed,
  rewarded,
  revenue,
  unknown,
}

class NativeConsent {
  NativeConsent({required this.accepted, required this.personalizedAds});

  bool accepted;
  bool personalizedAds;
}

class NativeAccess {
  NativeAccess({
    required this.canUseLocation,
    required this.canUsePhoneState,
    required this.canUseWifiState,
    required this.canUseWriteExternalStorage,
    required this.canUseOaid,
    required this.canUseAndroidId,
    required this.canUseInstalledApps,
    required this.canUseRecordAudio,
    required this.canUseIdfa,
    required this.canUploadDeviceInfo,
  });

  bool canUseLocation;
  bool canUsePhoneState;
  bool canUseWifiState;
  bool canUseWriteExternalStorage;
  bool canUseOaid;
  bool canUseAndroidId;
  bool canUseInstalledApps;
  bool canUseRecordAudio;
  bool canUseIdfa;
  bool canUploadDeviceInfo;
}

class NativeInitializationRequest {
  NativeInitializationRequest({
    required this.appId,
    required this.consent,
    required this.access,
    required this.debugLogging,
  });

  String appId;
  NativeConsent consent;
  NativeAccess access;
  bool debugLogging;
}

class NativePrivacyUpdate {
  NativePrivacyUpdate({required this.consent, required this.access});

  NativeConsent consent;
  NativeAccess access;
}

class NativeRewardOptions {
  NativeRewardOptions({
    this.userId,
    this.rewardName,
    this.rewardAmount,
    this.customData,
  });

  String? userId;
  String? rewardName;
  int? rewardAmount;
  String? customData;
}

class NativeAdRequest {
  NativeAdRequest({
    required this.placement,
    required this.adType,
    required this.codeId,
    required this.generation,
    this.rewardOptions,
  });

  String placement;
  NativeAdType adType;
  String codeId;
  int generation;
  NativeRewardOptions? rewardOptions;
}

class NativeAdIdentity {
  NativeAdIdentity({
    required this.placement,
    required this.adType,
    required this.generation,
  });

  String placement;
  NativeAdType adType;
  int generation;
}

class NativeDiagnostic {
  NativeDiagnostic({
    required this.normalizedCode,
    required this.message,
    this.nativeCode,
    this.nativeDomain,
    this.nativeMessage,
    required this.details,
  });

  String normalizedCode;
  String message;
  String? nativeCode;
  String? nativeDomain;
  String? nativeMessage;
  Map<String, String> details;
}

class NativeRewardResult {
  NativeRewardResult({
    required this.rewarded,
    required this.verified,
    this.rewardName,
    this.rewardAmount,
  });

  bool rewarded;
  bool verified;
  String? rewardName;
  int? rewardAmount;
}

class NativeRevenue {
  NativeRevenue({
    this.networkName,
    this.networkPlacementId,
    this.rawEcpm,
    this.requestId,
  });

  String? networkName;
  String? networkPlacementId;
  String? rawEcpm;
  String? requestId;
}

class NativeShowResult {
  NativeShowResult({this.reward});

  NativeRewardResult? reward;
}

class NativeAdEvent {
  NativeAdEvent({
    required this.kind,
    required this.placement,
    required this.adType,
    required this.generation,
    this.error,
    this.reward,
    this.revenue,
  });

  NativeEventKind kind;
  String placement;
  NativeAdType adType;
  int generation;
  NativeDiagnostic? error;
  NativeRewardResult? reward;
  NativeRevenue? revenue;
}

@HostApi()
abstract class GroMoreHostApi {
  @async
  void initialize(NativeInitializationRequest request);

  @async
  void updatePrivacy(NativePrivacyUpdate request);

  @async
  void loadAd(NativeAdRequest request);

  @async
  bool isReady(NativeAdIdentity identity);

  @async
  NativeShowResult showAd(NativeAdIdentity identity);

  @async
  void dispose();
}

@FlutterApi()
abstract class GroMoreFlutterApi {
  void onEvent(NativeAdEvent event);
}
