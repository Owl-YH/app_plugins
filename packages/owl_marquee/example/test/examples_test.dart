import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owl_marquee/owl_marquee.dart';
import 'package:owl_marquee_example/main.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('each public example lays out on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MarqueeExampleApp());
    for (final scene in ExampleScene.values) {
      await tap(tester, 'scene-${scene.name}');
      expect(
        find.byType(OwlMarquee),
        findsNWidgets(scene == ExampleScene.directions ? 4 : 1),
      );
      expect(tester.takeException(), isNull, reason: scene.name);
    }
  });

  testWidgets('example controls update real playback and foreground actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MarqueeExampleApp());
    await tap(tester, 'pause');
    expect(
      tester
          .widgetList<OwlMarquee>(find.byType(OwlMarquee))
          .every((track) => track.paused),
      isTrue,
    );
    final speed = find.byKey(const ValueKey('speed'));
    await tester.ensureVisible(speed);
    await tester.pump();
    final rect = tester.getRect(speed);
    await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
    await tester.pump();
    expect(
      tester.widget<OwlMarquee>(find.byType(OwlMarquee).first).speed,
      greaterThan(24),
    );

    await tap(tester, 'scene-layout');
    await tap(tester, 'large-items');
    await tap(tester, 'empty-items');
    expect(tester.widget<OwlMarquee>(find.byType(OwlMarquee)).itemCount, 0);
    await tap(tester, 'empty-items');
    expect(tester.widget<OwlMarquee>(find.byType(OwlMarquee)).itemCount, 4);

    await tap(tester, 'scene-empty');
    await tap(tester, 'foreground-action');
    expect(find.text('已触发 1 次'), findsOneWidget);
    await tap(tester, 'scene-accessibility');
    expect(find.byKey(const ValueKey('static-action')), findsNothing);
    await tap(tester, 'reduced-motion');
    await tap(tester, 'static-action');
    expect(find.text('已触发 2 次'), findsOneWidget);
    expect(find.byType(OwlMarquee), findsOneWidget);
    expect(find.text('循环展示的文字应提供完整、可阅读的静态替代内容。'), findsOneWidget);
    await tap(tester, 'reduced-motion');
    await tap(tester, 'pause');

    await tap(tester, 'scene-lifecycle');
    await tap(tester, 'ticker-mode');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tap(tester, 'ticker-mode');
    await tap(tester, 'open-page');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('返回后继续播放'), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OwlMarquee), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
