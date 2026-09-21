import 'package:demo/ads/gromore_ad_demo_page.dart';
import 'package:demo/nfc/nfc_demo_page.dart';
import 'package:flutter/material.dart';

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('插件测试中心')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '选择测试场景',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '每个页面都直接调用仓库内的真实 Flutter 插件，不使用模拟平台结果。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _DemoEntryCard(
                      icon: Icons.nfc,
                      title: 'NFC 测试',
                      description: '检测 NFC，读取 NDEF 标签，写入文本或 URI 并回读验证。',
                      buttonKey: const ValueKey('open-nfc-demo'),
                      buttonLabel: '进入 NFC 测试页面',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NfcDemoPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DemoEntryCard(
                      icon: Icons.ads_click,
                      title: 'GroMore 广告测试',
                      description: '验证同意门禁、初始化、奖励广告、插屏广告、事件、错误与释放流程。',
                      buttonKey: const ValueKey('open-ads-demo'),
                      buttonLabel: '进入广告测试页面',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GroMoreAdDemoPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoEntryCard extends StatelessWidget {
  const _DemoEntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonKey,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final Key buttonKey;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
