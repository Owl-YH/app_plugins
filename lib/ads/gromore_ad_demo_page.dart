import 'package:demo/ads/gromore_ad_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroMoreAdDemoPage extends ConsumerStatefulWidget {
  const GroMoreAdDemoPage({super.key});

  @override
  ConsumerState<GroMoreAdDemoPage> createState() => _GroMoreAdDemoPageState();
}

class _GroMoreAdDemoPageState extends ConsumerState<GroMoreAdDemoPage>
    with WidgetsBindingObserver {
  late final GroMoreAdController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(groMoreAdControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.onPageOpened();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.onAppLifecycleChanged(state.name);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _copyLogs() async {
    final controller = ref.read(groMoreAdControllerProvider.notifier);
    await Clipboard.setData(ClipboardData(text: controller.buildLogText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('广告测试日志已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groMoreAdControllerProvider);
    final controller = ref.read(groMoreAdControllerProvider.notifier);
    final missing = state.missingRequiredKeys;
    return Scaffold(
      appBar: AppBar(title: const Text('GroMore 广告测试')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (missing.isNotEmpty) ...[
                      _MissingConfigCard(missing: missing),
                      const SizedBox(height: 12),
                    ],
                    _buildConsentCard(context, state, controller),
                    const SizedBox(height: 12),
                    _buildLifecycleCard(context, state, controller),
                    const SizedBox(height: 12),
                    _AdOperationCard(
                      title: '奖励广告',
                      subtitle: '加载、就绪检查、展示关闭与奖励结果；真实结算必须以 SSV 为准。',
                      ready: state.rewardReady,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('load-reward-ad'),
                          onPressed: state.canRequest
                              ? controller.loadReward
                              : null,
                          icon: const Icon(Icons.download),
                          label: const Text('加载奖励广告'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.canRequest
                              ? controller.checkRewardReady
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('检查就绪状态'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('show-reward-ad'),
                          onPressed: state.canRequest && state.rewardReady
                              ? controller.showReward
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('展示已就绪广告'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.canRequest
                              ? controller.showReward
                              : null,
                          icon: const Icon(Icons.bug_report_outlined),
                          label: const Text('直接调用展示（验证 notReady）'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdOperationCard(
                      title: '全屏插屏广告',
                      subtitle: '加载、就绪检查、展示关闭、点击与原始收益事件。',
                      ready: state.insertReady,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('load-insert-ad'),
                          onPressed: state.canRequest
                              ? controller.loadInsert
                              : null,
                          icon: const Icon(Icons.download),
                          label: const Text('加载插屏广告'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.canRequest
                              ? controller.checkInsertReady
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('检查就绪状态'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('show-insert-ad'),
                          onPressed: state.canRequest && state.insertReady
                              ? controller.showInsert
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('展示已就绪广告'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.canRequest
                              ? controller.showInsert
                              : null,
                          icon: const Icon(Icons.bug_report_outlined),
                          label: const Text('直接调用展示（验证 notReady）'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLogCard(context, state, controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard(
    BuildContext context,
    GroMoreAdState state,
    GroMoreAdController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1. 宿主授权', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '页面不会弹系统权限或 ATT。GroMoreAccess 保持全部拒绝；请先展示并取得宿主自己的隐私政策授权。',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state.privacyAccepted,
              title: const Text('已同意宿主隐私政策'),
              onChanged: state.busy
                  ? null
                  : (value) => controller.setPrivacyAccepted(value ?? false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.personalizedAds,
              title: const Text('允许个性化广告'),
              subtitle: const Text('关闭时仍可请求非个性化广告'),
              onChanged: state.busy || !state.privacyAccepted
                  ? null
                  : controller.setPersonalizedAds,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifecycleCard(
    BuildContext context,
    GroMoreAdState state,
    GroMoreAdController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '2. SDK 生命周期',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusChip(
                  label: state.initialized ? '已初始化' : '未初始化',
                  active: state.initialized,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('initialize-ads'),
              onPressed: state.canInitialize
                  ? controller.initializeOrUpdateConsent
                  : null,
              icon: const Icon(Icons.power_settings_new),
              label: Text(state.initialized ? '更新授权配置' : '初始化 GroMore'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  state.busy || !state.initialized || !state.consentApplied
                  ? null
                  : controller.withdrawConsent,
              icon: const Icon(Icons.block),
              label: const Text('撤回授权并使缓存失效'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.busy || !state.hasProvider
                  ? null
                  : controller.disposeProvider,
              icon: const Icon(Icons.power_off),
              label: const Text('终止应用级 Runtime（需重启 App）'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    GroMoreAdState state,
    GroMoreAdController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '事件与错误日志',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: state.logs.isEmpty ? null : _copyLogs,
                  tooltip: '复制日志',
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  onPressed: state.logs.isEmpty ? null : controller.clearLogs,
                  tooltip: '清空日志',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.logs.isEmpty)
              const Text('尚无事件。')
            else
              for (final log in state.logs) ...[
                SelectableText(log),
                const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _MissingConfigCard extends StatelessWidget {
  const _MissingConfigCard({required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缺少真实 GroMore 配置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Text(
              missing.join('\n'),
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Text(
              '使用 --dart-define-from-file=dart_defines.json 启动后才能调用 SDK。',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdOperationCard extends StatelessWidget {
  const _AdOperationCard({
    required this.title,
    required this.subtitle,
    required this.ready,
    required this.children,
  });

  final String title;
  final String subtitle;
  final bool ready;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: ready ? 'Ready' : 'Not ready',
                  active: ready,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 18,
        color: color,
      ),
      label: Text(label),
      side: BorderSide(color: color),
    );
  }
}
