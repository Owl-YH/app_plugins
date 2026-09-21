import 'package:flutter/material.dart';
import 'package:owl_marquee/owl_marquee.dart';

void main() => runApp(const MarqueeExampleApp());

class MarqueeExampleApp extends StatelessWidget {
  const MarqueeExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Owl Marquee',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff425bd7)),
      scaffoldBackgroundColor: const Color(0xfff4f5fa),
      useMaterial3: true,
    ),
    home: const MarqueeExamples(),
  );
}

enum ExampleScene {
  directions('四个方向', '对照上下左右的物理运动方向。速度、间距与暂停控制所有轨道。'),
  text('自然尺寸文字', '无需指定文字高度；RTL 只改变文字排版，不改变所选运动方向。'),
  cards('不同尺寸卡片', '不同尺寸的普通 Widget 共用一个连续周期，阴影由视口裁剪。'),
  layout('动态布局', '切换内容尺寸、空集合和视口宽度，观察同帧重新布局。'),
  empty('空状态组合', '调用方叠加固定渐变和可交互前景，组件只负责背景运动。'),
  accessibility('减少动画', '打开“减少动画”后，完整静态内容替代轨道，并保留按钮交互。'),
  lifecycle('页面与暂停', '关闭 TickerMode 或进入新页面后停止播放，返回时从保存位置继续。');

  const ExampleScene(this.label, this.description);
  final String label;
  final String description;
}

class MarqueeExamples extends StatefulWidget {
  const MarqueeExamples({super.key});

  @override
  State<MarqueeExamples> createState() => _MarqueeExamplesState();
}

class _MarqueeExamplesState extends State<MarqueeExamples> {
  ExampleScene _scene = ExampleScene.directions;
  AxisDirection _direction = AxisDirection.left;
  double _speed = 24;
  double _spacing = 16;
  double _width = 1;
  bool _paused = false;
  bool _reducedMotion = false;
  bool _rtl = false;
  bool _large = false;
  bool _empty = false;
  bool _ticking = true;
  int _actions = 0;

  static const _words = ['Flutter', '自然尺寸', 'Continuous motion', '左右上下'];
  static const _announcement = '循环展示的文字应提供完整、可阅读的静态替代内容。';

  OwlMarquee _track({
    required IndexedWidgetBuilder itemBuilder,
    int itemCount = 4,
    AxisDirection? direction,
    String? label,
    Widget? reducedMotionChild,
  }) => OwlMarquee(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    direction: direction ?? _direction,
    speed: _speed,
    spacing: _spacing,
    paused: _paused,
    semanticsLabel: label,
    reducedMotionChild: reducedMotionChild,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owl Marquee · 使用示例')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scene in ExampleScene.values)
                      ChoiceChip(
                        key: ValueKey('scene-${scene.name}'),
                        label: Text(scene.label),
                        selected: _scene == scene,
                        onSelected: (_) => setState(() => _scene = scene),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _scene.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<AxisDirection>(
                              key: const ValueKey('direction'),
                              value: _direction,
                              items: [
                                for (final direction in AxisDirection.values)
                                  DropdownMenuItem(
                                    value: direction,
                                    child: Text(_directionLabel(direction)),
                                  ),
                              ],
                              onChanged: _scene == ExampleScene.directions
                                  ? null
                                  : (value) =>
                                        setState(() => _direction = value!),
                            ),
                            FilterChip(
                              key: const ValueKey('pause'),
                              label: const Text('暂停'),
                              selected: _paused,
                              onSelected: (value) =>
                                  setState(() => _paused = value),
                            ),
                            FilterChip(
                              key: const ValueKey('reduced-motion'),
                              label: const Text('减少动画'),
                              selected: _reducedMotion,
                              onSelected: (value) =>
                                  setState(() => _reducedMotion = value),
                            ),
                            FilterChip(
                              key: const ValueKey('rtl'),
                              label: const Text('RTL'),
                              selected: _rtl,
                              onSelected: (value) =>
                                  setState(() => _rtl = value),
                            ),
                          ],
                        ),
                        _slider(
                          '速度 ${_speed.round()} px/s',
                          _speed,
                          100,
                          (value) => setState(() => _speed = value),
                          key: const ValueKey('speed'),
                        ),
                        _slider(
                          '间距 ${_spacing.round()} px',
                          _spacing,
                          40,
                          (value) => setState(() => _spacing = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                MediaQuery(
                  // The example may request less motion, but never overrides a
                  // real system request to disable animations.
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations:
                        _reducedMotion ||
                        MediaQuery.disableAnimationsOf(context),
                  ),
                  child: Directionality(
                    textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: _buildScene(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildScene() => switch (_scene) {
    ExampleScene.directions => _directions(),
    ExampleScene.text => _text(),
    ExampleScene.cards => SizedBox(
      height: 300,
      child: _track(itemBuilder: (_, index) => _tile(index)),
    ),
    ExampleScene.layout => _layout(),
    ExampleScene.empty => _emptyState(),
    ExampleScene.accessibility => _accessible(),
    ExampleScene.lifecycle => _lifecycle(),
  };

  Widget _directions() => Column(
    children: [
      for (final direction in AxisDirection.values) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_directionLabel(direction)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: _track(
            direction: direction,
            itemBuilder: (_, index) => _tile(index, compact: true),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ],
  );

  Widget _text() {
    final horizontal = axisDirectionToAxis(_direction) == Axis.horizontal;
    final track = _track(
      label: _words.join('、'),
      reducedMotionChild: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final word in _words)
            Text(word, style: const TextStyle(fontSize: 24)),
        ],
      ),
      itemBuilder: (_, index) =>
          Text(_words[index], style: const TextStyle(fontSize: 24)),
    );
    // Horizontal content naturally determines its height. Vertical movement
    // needs an explicit finite height instead.
    return horizontal ? track : SizedBox(height: 220, child: track);
  }

  Widget _layout() => Column(
    children: [
      Wrap(
        spacing: 12,
        children: [
          FilterChip(
            key: const ValueKey('large-items'),
            label: const Text('增大内容'),
            selected: _large,
            onSelected: (value) => setState(() => _large = value),
          ),
          FilterChip(
            key: const ValueKey('empty-items'),
            label: const Text('空集合'),
            selected: _empty,
            onSelected: (value) => setState(() => _empty = value),
          ),
        ],
      ),
      _slider(
        '视口宽度 ${(_width * 100).round()}%',
        _width,
        1,
        (value) => setState(() => _width = value),
        min: 0.4,
      ),
      FractionallySizedBox(
        widthFactor: _width,
        child: SizedBox(
          height: 240,
          child: _track(
            itemCount: _empty ? 0 : 4,
            itemBuilder: (_, index) => LayoutBuilder(
              builder: (_, constraints) => SizedBox(
                width: _large ? 210 : 140,
                height: _large ? 110 : 72,
                child: ColoredBox(
                  color: constraints.hasBoundedWidth
                      ? const Color(0xffdfd9ff)
                      : const Color(0xffc8eee0),
                  child: Center(
                    child: Text('${index + 1} · ${_large ? '大' : '小'}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _emptyState() => SizedBox(
    height: 360,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.white,
          child: _track(itemBuilder: (_, index) => _tile(index)),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00ffffff), Colors.white],
              ),
            ),
          ),
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('让你的内容从这里开始'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('foreground-action'),
                    onPressed: () => setState(() => _actions++),
                    icon: const Icon(Icons.add),
                    label: const Text('触发前景操作'),
                  ),
                  Text('已触发 $_actions 次'),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _accessible() => SizedBox(
    height: 220,
    child: _track(
      itemCount: 1,
      label: _announcement,
      itemBuilder: (_, _) => const SizedBox(
        width: 500,
        height: 64,
        child: Center(child: Text(_announcement)),
      ),
      reducedMotionChild: SingleChildScrollView(
        child: Column(
          children: [
            const Text(_announcement, style: TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('static-action'),
              onPressed: () => setState(() => _actions++),
              child: const Text('静态内容可以交互'),
            ),
            Text('已触发 $_actions 次'),
          ],
        ),
      ),
    ),
  );

  Widget _lifecycle() => Column(
    children: [
      Wrap(
        spacing: 16,
        children: [
          FilterChip(
            key: const ValueKey('ticker-mode'),
            label: const Text('TickerMode 启用'),
            selected: _ticking,
            onSelected: (value) => setState(() => _ticking = value),
          ),
          OutlinedButton(
            key: const ValueKey('open-page'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('返回后继续播放')),
                  body: const Center(child: Text('原页面的跑马灯由路由 TickerMode 暂停。')),
                ),
              ),
            ),
            child: const Text('进入新页面'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      TickerMode(
        enabled: _ticking,
        child: SizedBox(
          height: 180,
          child: _track(itemBuilder: (_, index) => _tile(index)),
        ),
      ),
    ],
  );

  Widget _tile(int index, {bool compact = false}) => Container(
    width: compact ? 140 : 150 + index * 30,
    height: compact ? 64 : 110 + index * 12,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const [
        Color(0xffc8eee0),
        Color(0xffffdfb2),
        Color(0xffdcd7ff),
        Color(0xffbfe4fa),
      ][index % 4],
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), blurRadius: 12, spreadRadius: 2),
      ],
    ),
    child: Center(
      child: Text(
        _words[index % 4],
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged, {
    double min = 0,
    Key? key,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(key: key, value: value, min: min, max: max, onChanged: onChanged),
    ],
  );
}

String _directionLabel(AxisDirection direction) => switch (direction) {
  AxisDirection.up => '向上',
  AxisDirection.down => '向下',
  AxisDirection.left => '向左',
  AxisDirection.right => '向右',
};
