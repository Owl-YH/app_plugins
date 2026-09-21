final class ExampleConfig {
  const ExampleConfig._();

  static const androidAppId = String.fromEnvironment('GROMORE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('GROMORE_IOS_APP_ID');
  static const rewardAndroidCodeId = String.fromEnvironment(
    'GROMORE_REWARD_ANDROID_CODE_ID',
  );
  static const rewardIosCodeId = String.fromEnvironment(
    'GROMORE_REWARD_IOS_CODE_ID',
  );
  static const insertAndroidCodeId = String.fromEnvironment(
    'GROMORE_INSERT_ANDROID_CODE_ID',
  );
  static const insertIosCodeId = String.fromEnvironment(
    'GROMORE_INSERT_IOS_CODE_ID',
  );
  static const testDeviceIds = String.fromEnvironment(
    'GROMORE_TEST_DEVICE_IDS',
  );
  static const rewardUserId = String.fromEnvironment('GROMORE_REWARD_USER_ID');
  static const rewardName = String.fromEnvironment('GROMORE_REWARD_NAME');
  static const rewardAmount = int.fromEnvironment('GROMORE_REWARD_AMOUNT');
  static const rewardCustomData = String.fromEnvironment(
    'GROMORE_REWARD_CUSTOM_DATA',
  );

  static List<String> get missingRequiredKeys {
    final values = <String, String>{
      'GROMORE_ANDROID_APP_ID': androidAppId,
      'GROMORE_IOS_APP_ID': iosAppId,
      'GROMORE_REWARD_ANDROID_CODE_ID': rewardAndroidCodeId,
      'GROMORE_REWARD_IOS_CODE_ID': rewardIosCodeId,
      'GROMORE_INSERT_ANDROID_CODE_ID': insertAndroidCodeId,
      'GROMORE_INSERT_IOS_CODE_ID': insertIosCodeId,
      'GROMORE_REWARD_USER_ID': rewardUserId,
      'GROMORE_REWARD_NAME': rewardName,
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

  static void requireRealCredentials() {
    final missing = missingRequiredKeys;
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing real GroMore credentials: ${missing.join(', ')}. '
        'Copy dart_defines.example.json to the ignored dart_defines.json, '
        'replace every placeholder, then run with '
        '--dart-define-from-file=dart_defines.json.',
      );
    }
  }
}
