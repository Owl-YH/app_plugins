import 'package:flutter_test/flutter_test.dart';
import 'package:owl_ads_gromore/owl_ads_gromore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('access is deny-by-default', () {
    const access = GroMoreAccess();
    expect(access.canUseLocation, isFalse);
    expect(access.canUsePhoneState, isFalse);
    expect(access.canUseWifiState, isFalse);
    expect(access.canUseWriteExternalStorage, isFalse);
    expect(access.canUseOaid, isFalse);
    expect(access.canUseAndroidId, isFalse);
    expect(access.canUseInstalledApps, isFalse);
    expect(access.canUseRecordAudio, isFalse);
    expect(access.canUseIdfa, isFalse);
    expect(access.canUploadDeviceInfo, isFalse);
  });

  test('config copies its placement map and resolves typed units', () {
    final placement = AdPlacement('reward');
    final source = <AdPlacement, GroMoreAdUnit>{
      placement: GroMoreAdUnit(
        type: AdType.reward,
        androidCodeId: 'android-code',
        iosCodeId: 'ios-code',
      ),
    };
    final config = GroMoreConfig(
      androidAppId: 'android-app',
      iosAppId: 'ios-app',
      units: source,
    );
    source.clear();
    expect(
      config.unitFor(placement, AdType.reward).androidCodeId,
      'android-code',
    );
    expect(() => config.units.clear(), throwsUnsupportedError);
  });

  test('unsupported and mismatched formats fail before native invocation', () {
    expect(
      () => GroMoreAdUnit(
        type: AdType.banner,
        androidCodeId: 'android',
        iosCodeId: 'ios',
      ),
      throwsA(
        isA<AdsException>().having(
          (error) => error.code,
          'code',
          AdErrorCode.unsupportedAdFormat,
        ),
      ),
    );
    final placement = AdPlacement('insert');
    final config = GroMoreConfig(
      androidAppId: 'android-app',
      iosAppId: 'ios-app',
      units: <AdPlacement, GroMoreAdUnit>{
        placement: GroMoreAdUnit(
          type: AdType.insert,
          androidCodeId: 'android',
          iosCodeId: 'ios',
        ),
      },
    );
    expect(
      () => config.unitFor(placement, AdType.reward),
      throwsA(isA<AdsException>()),
    );
  });

  test(
    'equivalent configs have stable value equality independent of map order',
    () {
      final reward = AdPlacement('reward-equality');
      final insert = AdPlacement('insert-equality');
      final rewardUnit = GroMoreAdUnit(
        type: AdType.reward,
        androidCodeId: 'reward-android',
        iosCodeId: 'reward-ios',
      );
      final insertUnit = GroMoreAdUnit(
        type: AdType.insert,
        androidCodeId: 'insert-android',
        iosCodeId: 'insert-ios',
      );
      final first = GroMoreConfig(
        androidAppId: 'android-equality',
        iosAppId: 'ios-equality',
        units: <AdPlacement, GroMoreAdUnit>{
          reward: rewardUnit,
          insert: insertUnit,
        },
      );
      final second = GroMoreConfig(
        androidAppId: 'android-equality',
        iosAppId: 'ios-equality',
        units: <AdPlacement, GroMoreAdUnit>{
          insert: insertUnit,
          reward: rewardUnit,
        },
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    },
  );

  test(
    'GroMore runtime is isolate-scoped and terminal across init disposal',
    () async {
      final placement = AdPlacement('singleton-reward');
      GroMoreConfig config(String appId) => GroMoreConfig(
        androidAppId: appId,
        iosAppId: 'ios-singleton',
        units: <AdPlacement, GroMoreAdUnit>{
          placement: GroMoreAdUnit(
            type: AdType.reward,
            androidCodeId: 'android-code',
            iosCodeId: 'ios-code',
          ),
        },
      );

      final first = GroMoreAds.configure(config('android-singleton'));
      final second = GroMoreAds.configure(config('android-singleton'));

      expect(identical(first, second), isTrue);
      expect(
        () => GroMoreAds.configure(config('another-android-app')),
        throwsA(
          isA<AdsException>().having(
            (error) => error.code,
            'code',
            AdErrorCode.configurationConflict,
          ),
        ),
      );

      const consent = AdConsent(accepted: true);
      final firstInitialization = first.init(consent);
      final joinedInitialization = first.init(consent);
      expect(identical(firstInitialization, joinedInitialization), isTrue);

      final disposal = first.dispose();
      await expectLater(firstInitialization, throwsA(anything));
      await expectLater(disposal, throwsA(anything));
      expect(first.initialized, isFalse);
      expect(
        () => GroMoreAds.configure(config('android-singleton')),
        throwsA(
          isA<AdsException>().having(
            (error) => error.code,
            'code',
            AdErrorCode.disposed,
          ),
        ),
      );
    },
  );
}
