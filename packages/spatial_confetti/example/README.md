# Spatial confetti example

Interactive inspection using the actual spatial_confetti package.

Run flutter pub get, then flutter run -d chrome from this directory.
Web is enabled in this example's own pubspec; no global configuration change is required.

For iOS Simulator, the ios directory contains the Flutter-generated runner.
Run flutter pub get after adding the platform or on a clean checkout to generate
the local Flutter Swift package, then use flutter devices to find the simulator
identifier and run flutter run --debug --no-pub -d <device-id>.

“观察单条彩带” shows a freely flying ribbon. Physical node markers are off by default;
enable “显示物理节点” explicitly when inspecting the simulation mesh.
“单条长度” and “物理段数” control its material resolution; smooth drawing uses separate bounded refinement. “发射一批” and “持续发射” compose the
selected recipes. XYZ wind, local wind and gusts affect live particles.
Recipe changes apply to the next emission. “停止生成” drains existing particles;
“清空” cancels all particles.

Run flutter test --no-pub test/example_test.dart for the public-API interaction check.
Device performance is not established by this example or its widget test.

The example uses WindSource/WindGust.global or .local and ConfettiEmitter.burst or .stream.
“混合发射加入开场光迹”控制下一批混合发射是否附加 6 条独立 StreakParticle；“光迹”模式可单独观察速度色带。色带寿命 260 ms，使用真实 XYZ 点运动和固定规模速度拉伸网格。

纸片支持全部形状随机混合或单独选择矩形、圆形、三角形、星形、心形、自定义凹轮廓。压力气动和切向摩擦可独立调节，作用于后续发射；都设为 0 时关闭纸片空气作用。压力气动对应 dragCoefficient，同时影响减速、翻转和转弯。

点击“静止释放单张纸片”，观察最长边 30 cm、面密度 .08、零初速及零初始角速度的纸片。它使用当前形状、风场和空气系数；“全部形状”在该入口使用矩形。清零风与涡流可观察静止空气中的自然下落，已有纸片也会响应阵风。参见 [纸片气动和实际轨迹](../doc/paper-aerodynamics.md)。

“淡入”“淡出”滑块使用毫秒，默认 0 / 350 ms，作用于随后出生的粒子，包括批量、持续和单粒子观察。对应 `ParticleLifetime.fadeIn/fadeOut`，均为 Duration。过渡包含在实际寿命内，超长窗口按比例缩短；所有粒子在各自寿命结束时释放。
