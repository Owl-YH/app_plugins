import 'package:flutter/material.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'presets.dart';

/// 从 example 目录运行 flutter run -t ../doc/gallery.dart。
void main() => runApp(const MaterialApp(home: GuideGallery()));

/// 展示使用指南中的真实预设，尺寸来自实际绘制区域。
class GuideGallery extends StatefulWidget {
  const GuideGallery({super.key});

  @override
  State<GuideGallery> createState() => _GuideGalleryState();
}

class _GuideGalleryState extends State<GuideGallery> {
  ConfettiController _controller = ConfettiController();
  int _selected = 0;

  void _play(Size size) {
    final scene = guideScenes(size)[_selected];
    final previous = _controller;
    // 新建时钟与初始风场，保证同种子重播的条件相同。
    setState(() => _controller = ConfettiController(wind: scene.wind));
    previous.dispose();
    _controller.emit(scene.effect);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101827),
    appBar: AppBar(title: const Text('Spatial Confetti · 使用指南')),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scenes = guideScenes(size);
        return Stack(
          children: [
            Positioned.fill(
              child: ConfettiView(
                controller: _controller,
                camera: scenes[_selected].camera,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < scenes.length; i++)
                      ChoiceChip(
                        label: Text(scenes[i].title),
                        selected: i == _selected,
                        onSelected: (_) {
                          _selected = i;
                          _play(size);
                        },
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _play(size),
                        child: const Text('重播'),
                      ),
                      OutlinedButton(
                        onPressed: () => _controller.isPaused
                            ? _controller.resume()
                            : _controller.pause(),
                        child: const Text('暂停 / 继续'),
                      ),
                      OutlinedButton(
                        onPressed: () => _controller.gust(
                          WindGust.local(
                            velocity: const Vec3(2, -.5, 1),
                            center: Vec3.zero,
                            radius: 2,
                            duration: const Duration(milliseconds: 1500),
                          ),
                        ),
                        child: const Text('吹一阵风'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
