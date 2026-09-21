import 'package:demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes NFC and advertising demo entries', (tester) async {
    await tester.pumpWidget(const PluginDemoApp());

    expect(find.text('插件测试中心'), findsOneWidget);
    expect(find.text('NFC 测试'), findsOneWidget);
    expect(find.text('GroMore 广告测试'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-nfc-demo')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-ads-demo')), findsOneWidget);
  });

  testWidgets('opens the NFC demo without invoking a platform channel', (
    tester,
  ) async {
    await tester.pumpWidget(const PluginDemoApp());
    await tester.tap(find.byKey(const ValueKey('open-nfc-demo')));
    await tester.pumpAndSettle();

    expect(find.text('NDEF 标签工具'), findsOneWidget);
    expect(find.text('尚未检测'), findsOneWidget);
    expect(find.text('读取标签'), findsOneWidget);
    expect(find.text('写入并验证'), findsOneWidget);
    expect(find.text('尚无真实标签读写结果'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-debug-button')), findsOneWidget);

    final readButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('read-button')),
    );
    final writeButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('write-button')),
    );
    expect(readButton.onPressed, isNull);
    expect(writeButton.onPressed, isNull);
  });

  testWidgets('NFC demo remains scrollable on a narrow phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PluginDemoApp());
    await tester.tap(find.byKey(const ValueKey('open-nfc-demo')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('result-section')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advertising demo blocks native work without real credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const PluginDemoApp());
    final entry = find.byKey(const ValueKey('open-ads-demo'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('缺少真实 GroMore 配置'), findsOneWidget);
    expect(find.text('1. 宿主授权'), findsOneWidget);
    expect(find.text('2. SDK 生命周期'), findsOneWidget);

    final initialize = tester.widget<FilledButton>(
      find.byKey(const ValueKey('initialize-ads')),
    );
    expect(initialize.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
