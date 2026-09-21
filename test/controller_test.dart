import 'package:demo/ads/gromore_ad_controller.dart';
import 'package:demo/nfc/nfc_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NFC controller keeps platform work opt-in', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(nfcControllerProvider);
    expect(state.notice, '尚未检测 NFC 状态。');
    expect(state.isBusy, isFalse);
    final controller = container.read(nfcControllerProvider.notifier);
    expect(controller.buildDebugReport(), contains('最近错误: 无'));
  });

  test('GroMore consent state follows one-way updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(groMoreAdControllerProvider.notifier);
    controller.setPrivacyAccepted(true);
    controller.setPersonalizedAds(true);

    var state = container.read(groMoreAdControllerProvider);
    expect(state.privacyAccepted, isTrue);
    expect(state.personalizedAds, isTrue);

    controller.setPrivacyAccepted(false);

    state = container.read(groMoreAdControllerProvider);
    expect(state.privacyAccepted, isFalse);
    expect(state.personalizedAds, isFalse);
    expect(state.canRequest, isFalse);
  });

  test('GroMore requests require consent synchronized to the SDK', () {
    const pendingConsent = GroMoreAdState(
      missingRequiredKeys: <String>[],
      privacyAccepted: true,
      initialized: true,
    );
    const appliedConsent = GroMoreAdState(
      missingRequiredKeys: <String>[],
      privacyAccepted: true,
      initialized: true,
      consentApplied: true,
    );

    expect(pendingConsent.canRequest, isFalse);
    expect(appliedConsent.canRequest, isTrue);
  });
}
