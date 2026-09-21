# owl_marquee

可复用的 Flutter 跑马灯：四个物理方向、自然内容尺寸、匀速循环、间距、暂停与减少动画适配。运行时仅依赖 Flutter SDK。

最低 Flutter 3.44.6 / Dart 3.12.2。`0.1.0` 已发布到 pub.dev，应用可添加：

```yaml
dependencies:
  owl_marquee: ^0.1.0
```

## 使用

```dart
import 'package:flutter/material.dart';
import 'package:owl_marquee/owl_marquee.dart';

SizedBox(
  height: 100,
  child: OwlMarquee(
    itemCount: 3,
    direction: AxisDirection.left,
    speed: 24,
    spacing: 16,
    itemBuilder: (context, index) => Container(
      width: 120 + index * 20,
      height: 72,
      color: Colors.blue.shade100,
      alignment: Alignment.center,
      child: Text('展示 ${index + 1}'),
    ),
  ),
)
```

运动主轴需要有限最大约束：横向需要有限宽度，纵向需要有限高度。交叉轴支持自然收缩或父级紧约束，不必为横向文字额外指定高度。`AxisDirection` 表示屏幕物理方向，RTL 不会隐式反转运动。

| 参数 | 含义 | 默认值 |
| --- | --- | --- |
| `itemCount` | 原始项目数，0–64 | 必填 |
| `itemBuilder` | 按原始索引构建独立展示实例 | 必填 |
| `direction` | `left` / `right` / `up` / `down` | `left` |
| `speed` | 非负有限逻辑像素/秒；0 冻结 | 24 |
| `spacing` | 非负有限间距，包含循环接缝 | 0 |
| `paused` | 冻结当前位置 | false |
| `semanticsLabel` | 完整、本地化的稳定语义标签 | null |
| `reducedMotionChild` | 减少动画时替代整个轨道的组件 | null |

## 展示与交互

轨道用于可重复展示，所有原始项和副本均排除指针、焦点及子项语义。按钮、输入与持久业务状态应由外部组件拥有。例如将跑马灯、`IgnorePointer` 渐变和前景 `child` 按顺序放入 `Stack`，即可组成空状态背景。

相同索引在相同约束、依赖下应产生等价自然尺寸；所有副本使用相同的自然布局约束。不要在副本间复用 `GlobalKey`。不能在无上界主轴内放置需要剩余空间的 `Expanded`，也不要依赖 intrinsic/dry-layout 测量跑马灯。

完整周期按原始组尺寸计算。原始项目与副本合计最多 512 个实例；超限明确报错，不会悄悄留下循环空档。调用方子树的复杂度不受此上限约束。空集合、零面积、零周期不会启动动画。

## 无障碍与生命周期

不传 `semanticsLabel` 表示装饰。信息性内容必须同时提供非空白标签和 `reducedMotionChild`：

```dart
OwlMarquee(
  itemCount: 1,
  semanticsLabel: '完整的公告内容',
  reducedMotionChild: const Text('完整的公告内容'),
  itemBuilder: (context, index) => const Text('完整的公告内容'),
)
```

系统禁用动画时，有替代组件则移除重复轨道并展示替代内容；无替代组件的装饰轨道保持静态。替代组件保留自己的语义、焦点和点击，调用方负责换行或滚动以保证全部内容可达。普通暂停或速度为 0 不触发替代组件。

`TickerMode` 关闭、应用离开 resumed 状态时冻结播放；恢复后不补算暂停时长。同轴反向、调速保留位置；换轴及几何重排允许重新定位。组件不会自行检测任意滚动裁剪下的可见性，可由调用方使用 `paused` 控制。

## Example

[example](example/README.md) 是仅依赖本包的独立 Flutter 应用，提供 7 类可交互场景。已包含 Web 启动入口：

```sh
cd packages/owl_marquee/example
flutter pub get
flutter run -d chrome
```

若浏览器不由 Flutter 启动，可使用 `flutter run -d web-server`。组件本身不依赖 Web API；当前 example 提交了 Web 工程，未附带各原生平台工程。

## 验证

在包目录执行：

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test/marquee_test.dart
cd example
flutter test --no-pub test/examples_test.dart
```

App 的业务素材、主题及空状态接入测试留在 App。包测试使用 Flutter 原生宿主，不导入 App。
