import 'package:flutter_test/flutter_test.dart';
import 'package:owl_ads/owl_ads.dart';
import 'package:owl_ads_gromore/src/native_mapper.dart';
import 'package:owl_ads_gromore/src/pigeon/gromore_api.g.dart';

void main() {
  test('unknown future error names retain native diagnostics', () {
    final mapped = fromNativeDiagnostic(
      NativeDiagnostic(
        normalizedCode: 'futureProviderCode',
        message: 'future failure',
        nativeCode: '90001',
        nativeDomain: 'GroMore',
        nativeMessage: null,
        details: <String, String>{'requestId': 'request-1'},
      ),
    );
    expect(mapped.code, AdErrorCode.nativeError);
    expect(mapped.nativeCode, '90001');
    expect(mapped.nativeMessage, isNull);
    expect(mapped.nativeDetails['requestId'], 'request-1');
  });

  test('unknown future event sentinel is safely ignored', () {
    expect(
      fromNativeEvent(
        NativeAdEvent(
          kind: NativeEventKind.unknown,
          placement: 'reward',
          adType: NativeAdType.reward,
          generation: 4,
        ),
      ),
      isNull,
    );
  });

  test('event mapping preserves generation and nullable revenue fields', () {
    final mapped = fromNativeEvent(
      NativeAdEvent(
        kind: NativeEventKind.revenue,
        placement: 'insert',
        adType: NativeAdType.insert,
        generation: 9,
        revenue: NativeRevenue(rawEcpm: '88.3'),
      ),
    )!;
    expect(mapped.requestGeneration, 9);
    expect(mapped.revenue?.rawEcpm, '88.3');
    expect(mapped.revenue?.networkName, isNull);
  });
}
