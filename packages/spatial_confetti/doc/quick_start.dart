import 'package:flutter/material.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'presets.dart';

/// 从 example 目录运行 flutter run -t ../doc/quick_start.dart。
void main() => runApp(const MaterialApp(home: QuickStart()));

/// 按钮触发一次自动清理的覆盖层动画。
class QuickStart extends StatelessWidget {
  const QuickStart({super.key});

  void _celebrate(BuildContext context) {
    const camera = ConfettiCamera(viewHeight: 6.5);
    // 使用最近 Overlay 的实际绘制区域，不假设它等于整块屏幕。
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject()! as RenderBox;
    final origin = camera.unproject(
      Offset(box.size.width * .5, box.size.height * .87),
      box.size,
    );
    Confetti.launch(
      context,
      effect: GuidePresets.celebration(origin),
      camera: camera,
      gravity: const Vec3(0, 9.81, 0),
      wind: WindField(),
      limits: const ConfettiLimits(),
      respectReducedMotion: true,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confetti 快速开始')),
    body: Center(
      child: FilledButton(
        onPressed: () => _celebrate(context),
        child: const Text('完成，庆祝一下'),
      ),
    ),
  );
}
