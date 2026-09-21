import 'package:owl_ads_gromore/owl_ads_gromore.dart';

final class GroMoreDemoConfig {
  const GroMoreDemoConfig._();

  static final rewardPlacement = AdPlacement('demo_reward');
  static final insertPlacement = AdPlacement('demo_insert');

  static const androidAppId = String.fromEnvironment('GROMORE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('GROMORE_IOS_APP_ID');
  static const rewardAndroidCodeId = String.fromEnvironment('GROMORE_REWARD_ANDROID_CODE_ID');
  static const rewardIosCodeId = String.fromEnvironment('GROMORE_REWARD_IOS_CODE_ID');
  static const insertAndroidCodeId = String.fromEnvironment('GROMORE_INSERT_ANDROID_CODE_ID');
  static const insertIosCodeId = String.fromEnvironment('GROMORE_INSERT_IOS_CODE_ID');
  static const rewardUserId = String.fromEnvironment('GROMORE_REWARD_USER_ID');
  static const rewardName = String.fromEnvironment('GROMORE_REWARD_NAME');
  static const rewardAmount = int.fromEnvironment('GROMORE_REWARD_AMOUNT');
  static const rewardCustomData = String.fromEnvironment('GROMORE_REWARD_CUSTOM_DATA');

  static List<String> get missingRequiredKeys {
    final values = <String, String>{
      'GROMORE_IOS_APP_ID': iosAppId,
      'GROMORE_ANDROID_APP_ID': androidAppId,

      'GROMORE_REWARD_IOS_CODE_ID': rewardIosCodeId,
      'GROMORE_REWARD_ANDROID_CODE_ID': rewardAndroidCodeId,

      'GROMORE_INSERT_IOS_CODE_ID': insertIosCodeId,
      'GROMORE_INSERT_ANDROID_CODE_ID': insertAndroidCodeId,

      'GROMORE_REWARD_NAME': rewardName,
      'GROMORE_REWARD_USER_ID': rewardUserId,
    };
    final missing = values.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();
    if (rewardAmount <= 0) {
      missing.add('GROMORE_REWARD_AMOUNT');
    }
    return List.unmodifiable(missing);
  }

  static bool get isComplete => missingRequiredKeys.isEmpty;

  static GroMoreConfig createProviderConfig() {
    requireComplete();
    return GroMoreConfig(
      units: <AdPlacement, GroMoreAdUnit>{
        rewardPlacement: GroMoreAdUnit(
          type: AdType.reward,
          iosCodeId: rewardIosCodeId,
          androidCodeId: rewardAndroidCodeId,
        ),
        insertPlacement: GroMoreAdUnit(
          type: AdType.insert,
          iosCodeId: insertIosCodeId,
          androidCodeId: insertAndroidCodeId,
        ),
      },
      access: const GroMoreAccess(),
      iosAppId: iosAppId,
      debugLogging: true,
      androidAppId: androidAppId,
    );
  }

  static RewardOptions get rewardOptions => RewardOptions(
    userId: rewardUserId,
    rewardName: rewardName,
    rewardAmount: rewardAmount,
    customData: rewardCustomData,
  );

  static void requireComplete() {
    final missing = missingRequiredKeys;
    if (missing.isNotEmpty) {
      throw StateError(
        '缺少真实 GroMore 配置：${missing.join(', ')}。请复制 '
        'dart_defines.example.json 到已忽略的 dart_defines.json，替换所有占位值，'
        '并使用 --dart-define-from-file=dart_defines.json 启动。',
      );
    }
  }
}
