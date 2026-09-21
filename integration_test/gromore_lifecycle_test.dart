import 'package:demo/ads/gromore_ad_service.dart';
import 'package:demo/ads/gromore_demo_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:owl_ads_gromore/owl_ads_gromore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const expectLoadFailure = bool.fromEnvironment('GROMORE_EXPECT_LOAD_FAILURE');

  testWidgets(
    'real GroMore runtime is shared, loads once, and disposes terminally',
    (tester) async {
      GroMoreDemoConfig.requireComplete();
      const consent = AdConsent(accepted: true, personalizedAds: false);
      final first = GroMoreRepository(const GroMorePlatformService());
      final second = GroMoreRepository(const GroMorePlatformService());

      try {
        final config = GroMoreDemoConfig.createProviderConfig();
        first.ensureProvider(config);
        second.ensureProvider(config);
        try {
          await Future.wait(<Future<void>>[
            first.initialize(consent),
            second.initialize(consent),
          ]);
        } on AdsException catch (error) {
          fail(
            'Real GroMore initialization failed: '
            'code=${error.code.name}, nativeCode=${error.nativeCode}, '
            'nativeDomain=${error.nativeDomain}, '
            'nativeMessage=${error.nativeMessage}, '
            'nativeDetails=${error.nativeDetails}',
          );
        }
        expect(first.initialized, isTrue);
        expect(second.initialized, isTrue);

        try {
          await second.loadReward(
            GroMoreDemoConfig.rewardPlacement,
            options: GroMoreDemoConfig.rewardOptions,
          );
        } on AdsException catch (error) {
          if (!expectLoadFailure) rethrow;
          expect(error.code, AdErrorCode.nativeLoadFailed);
          expect(
            await second.isRewardReady(GroMoreDemoConfig.rewardPlacement),
            isFalse,
          );
          return;
        }
        if (expectLoadFailure) {
          fail('Expected the real SDK load to return nativeLoadFailed.');
        }
        expect(
          await second.isRewardReady(GroMoreDemoConfig.rewardPlacement),
          isTrue,
        );

        await first.disposeProvider();
        expect(first.hasProvider, isTrue);
        await expectLater(
          second.isRewardReady(GroMoreDemoConfig.rewardPlacement),
          throwsA(
            isA<AdsException>().having(
              (error) => error.code,
              'code',
              AdErrorCode.disposed,
            ),
          ),
        );
      } finally {
        await first.disposeProvider();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
