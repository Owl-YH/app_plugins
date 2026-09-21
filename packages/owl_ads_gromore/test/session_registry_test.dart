import 'package:flutter_test/flutter_test.dart';
import 'package:owl_ads/owl_ads.dart';
import 'package:owl_ads_gromore/src/session_registry.dart';

void main() {
  test('load, show, and close follow one-shot event ordering', () {
    final registry = AdSessionRegistry();
    final placement = AdPlacement('reward');
    final generation = registry.beginLoad(placement, AdType.reward)!;

    expect(
      () => registry.beginLoad(placement, AdType.reward),
      throwsA(
        isA<AdsException>().having(
          (error) => error.code,
          'code',
          AdErrorCode.alreadyLoading,
        ),
      ),
    );
    expect(registry.markReady(placement, AdType.reward, generation), isTrue);
    expect(registry.beginLoad(placement, AdType.reward), isNull);

    registry.beginShow(placement, AdType.reward, generation);
    expect(
      registry.accepts(placement, AdType.reward, generation, AdEventKind.shown),
      isTrue,
    );
    expect(
      registry.accepts(
        placement,
        AdType.reward,
        generation,
        AdEventKind.rewarded,
      ),
      isTrue,
    );
    expect(registry.finish(placement, AdType.reward, generation), isTrue);
    expect(registry.readiness(placement, AdType.reward), AdReadiness.idle);
  });

  test('invalidation rejects stale callbacks and blocks old generations', () {
    final registry = AdSessionRegistry();
    final placement = AdPlacement('insert');
    final generation = registry.beginLoad(placement, AdType.insert)!;
    final invalidated = registry.invalidateAll(blocked: true);

    expect(invalidated, hasLength(1));
    expect(registry.markReady(placement, AdType.insert, generation), isFalse);
    expect(
      registry.accepts(
        placement,
        AdType.insert,
        generation,
        AdEventKind.loaded,
      ),
      isFalse,
    );
  });

  test('show without a ready object returns notReady', () {
    final registry = AdSessionRegistry();
    final placement = AdPlacement('reward');
    expect(
      () => registry.beginShow(placement, AdType.reward, 0),
      throwsA(
        isA<AdsException>().having(
          (error) => error.code,
          'code',
          AdErrorCode.notReady,
        ),
      ),
    );
  });

  test('different placements keep independent generations and state', () {
    final registry = AdSessionRegistry();
    final first = AdPlacement('reward-first');
    final second = AdPlacement('reward-second');

    final firstGeneration = registry.beginLoad(first, AdType.reward)!;
    final secondGeneration = registry.beginLoad(second, AdType.reward)!;
    expect(registry.markReady(first, AdType.reward, firstGeneration), isTrue);
    expect(registry.readiness(second, AdType.reward), AdReadiness.loading);
    expect(secondGeneration, 1);
  });

  test('reward and revenue events are accepted once per generation', () {
    final registry = AdSessionRegistry();
    final placement = AdPlacement('deduplicated-reward');
    final generation = registry.beginLoad(placement, AdType.reward)!;
    registry.markReady(placement, AdType.reward, generation);
    registry.beginShow(placement, AdType.reward, generation);

    expect(
      registry.accepts(
        placement,
        AdType.reward,
        generation,
        AdEventKind.rewarded,
      ),
      isTrue,
    );
    expect(
      registry.accepts(
        placement,
        AdType.reward,
        generation,
        AdEventKind.rewarded,
      ),
      isFalse,
    );
    expect(
      registry.accepts(
        placement,
        AdType.reward,
        generation,
        AdEventKind.revenue,
      ),
      isTrue,
    );
    expect(
      registry.accepts(
        placement,
        AdType.reward,
        generation,
        AdEventKind.revenue,
      ),
      isFalse,
    );
  });
}
