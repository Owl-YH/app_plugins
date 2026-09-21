/// 纸片与柔性彩带的三维自由飞行、风场模拟和 Flutter 绘制。
///
/// 世界长度使用米、公开时间使用 Duration；X 向右、Y 向下、Z 朝向相机。
/// [ConfettiCamera] 将世界坐标投影为宿主内的逻辑像素坐标。
/// 通过 [Confetti.launch] 创建临时覆盖层，或使用
/// [ConfettiController] 与 [ConfettiView] 管理持续存在的绘制区域。
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

part 'src/vector.dart';
part 'src/time.dart';
part 'src/config.dart';
part 'src/paper_shape.dart';
part 'src/paper_geometry.dart';
part 'src/paper_dynamics.dart';
part 'src/paper_bending.dart';
part 'src/wind.dart';
part 'src/particles.dart';
part 'src/streak.dart';
part 'src/streak_geometry.dart';
part 'src/ribbon_dynamics.dart';
part 'src/ribbon_geometry.dart';
part 'src/simulation.dart';
part 'src/painter.dart';
part 'src/mesh.dart';
part 'src/host.dart';
part 'src/overlay.dart';
