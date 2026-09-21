import 'package:owl_ads/owl_ads.dart';
import 'package:test/test.dart';

void main() {
  group('domain values', () {
    test('placement trims and compares by stable name', () {
      expect(AdPlacement(' reward '), AdPlacement('reward'));
      expect(AdPlacement('reward').hashCode, AdPlacement('reward').hashCode);
    });

    test('empty placement is rejected with a normalized error', () {
      expect(
        () => AdPlacement('  '),
        throwsA(
          isA<AdsException>().having(
            (error) => error.code,
            'code',
            AdErrorCode.invalidPlacement,
          ),
        ),
      );
    });

    test('consent, reward, and revenue have value equality', () {
      expect(
        const AdConsent(accepted: true, personalizedAds: true),
        const AdConsent(accepted: true, personalizedAds: true),
      );
      expect(
        const RewardOptions(
          userId: 'user-1',
          rewardName: 'coin',
          rewardAmount: 3,
          customData: 'order-1',
        ),
        const RewardOptions(
          userId: 'user-1',
          rewardName: 'coin',
          rewardAmount: 3,
          customData: 'order-1',
        ),
      );
      expect(
        const RewardResult(
          rewarded: true,
          verified: true,
          rewardName: 'coin',
          rewardAmount: 3,
        ),
        const RewardResult(
          rewarded: true,
          verified: true,
          rewardName: 'coin',
          rewardAmount: 3,
        ),
      );
      expect(
        const AdRevenue(rawEcpm: '120.5', networkName: 'pangle'),
        const AdRevenue(rawEcpm: '120.5', networkName: 'pangle'),
      );
    });

    test('unsupported formats produce an explicit result', () {
      for (final type in <AdType>[
        AdType.splash,
        AdType.banner,
        AdType.feed,
        AdType.draw,
      ]) {
        expect(
          () => rejectUnsupportedAdType(type),
          throwsA(
            isA<AdsException>().having(
              (error) => error.code,
              'code',
              AdErrorCode.unsupportedAdFormat,
            ),
          ),
        );
      }
    });
  });

  test('event equality retains placement, type, generation, and payload', () {
    final placement = AdPlacement('reward');
    const reward = RewardResult(rewarded: true, verified: false);
    expect(
      AdEvent(
        kind: AdEventKind.rewarded,
        placement: placement,
        adType: AdType.reward,
        requestGeneration: 2,
        reward: reward,
      ),
      AdEvent(
        kind: AdEventKind.rewarded,
        placement: placement,
        adType: AdType.reward,
        requestGeneration: 2,
        reward: reward,
      ),
    );
  });
}
