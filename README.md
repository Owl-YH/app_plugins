# Flutter 插件测试中心

本仓库是六个 Flutter 插件包的源码仓库。`owl_ads`、`ndef_kit`、`owl_haptics`、`owl_marquee` 和 `spatial_confetti` 已发布 `0.1.0` 到 pub.dev，源码标签和校验记录见 [首次发布记录](docs/release-evidence.md)。`owl_ads_gromore` 因真机广告流程及服务端 SSV 尚未验收而暂缓发布，保留本地依赖和 `publish_to: none`。已发布版本如需修正，请发布新版本并升级消费者；不能撤销 pub.dev 版本。

当前应用是仓库内 Flutter 插件的真实宿主 Demo，主页提供两个入口：

- NFC 测试：真实 NDEF 标签读取、写入和回读验证。
- GroMore 广告测试：真实 SDK 初始化、奖励广告、全屏插屏、事件、错误、授权撤回和释放流程。

NFC 核心能力由本仓库的 `packages/ndef_kit` 维护，根应用通过 pub.dev 上的
`ndef_kit 0.1.0` 接入，同时也是该包的真实设备示例 App。业务代码不直接
依赖 `nfc_manager` 类型。

广告能力由 `packages/owl_ads` 和 `packages/owl_ads_gromore` 提供。根应用
仅依赖公开 Dart API，不直接调用 Android/iOS GroMore SDK，也不会在缺少
真实配置时伪造加载或展示成功。

## NFC 功能

- 检测设备是否支持并已开启 NFC。
- 读取 NDEF 文本、URI 和其他原始记录。
- 显示标签是否可写、最大容量、消息大小和记录数量。
- 写入 UTF-8 文本或 URI 记录。
- 写入后立即从同一标签回读，并逐字段比较 NDEF 消息。
- 支持主动取消正在等待的扫描。
- 通过右下角悬浮按钮复制 NFC 状态、异常堆栈和原始记录等调试信息。

应用不会格式化非 NDEF 标签，也不会提供永久写锁功能。

## 支持范围

推荐使用已格式化且可写的 NFC Forum 标签，例如 NTAG213、NTAG215 或 NTAG216。

以下类型不属于本 Demo 的目标：

- 门禁卡、银行卡、公交卡和身份证件。
- 需要密钥认证或专有指令的 MIFARE Classic/DESFire 数据区。
- 手机模拟 NFC 卡片或 HCE。
- FeliCa/ISO 18092 标签。

## 运行

```shell
flutter pub get
flutter run
```

NFC 无法在普通模拟器中完成端到端验证，必须使用具备 NFC 功能的真实设备。

广告页面在没有凭据时可以打开并检查布局，但初始化按钮会保持禁用。执行真实
广告请求前：

```shell
cp dart_defines.example.json dart_defines.json
# 将全部占位值替换成 GroMore 控制台、宿主用户系统和 SSV 后端使用的真实值。
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` 已被忽略。奖励页面展示的客户端 `rewarded/verified` 仅用于
交互反馈，真实发奖仍必须由服务端 SSV 回调决定。

广告测试覆盖：

- 明示隐私同意与个性化广告开关。
- 初始化、授权更新、授权撤回和 Provider 释放重建。
- 奖励广告与全屏插屏的加载、就绪检查、展示、关闭和 `notReady` 错误路径。
- load/show/click/close/reward/revenue/error 领域事件与原生诊断复制。
- 前后台生命周期日志。

当前版本仅集成 GroMore 基础 SDK，没有添加任何可选 ADN。Android/iOS 详细
宿主配置见 `packages/owl_ads_gromore/docs/`。

## 复用 NFC 包

其它 Flutter App 可以通过 pub.dev 依赖 `ndef_kit`：

```yaml
dependencies:
  ndef_kit: ^0.1.0
```

公开入口为 `package:ndef_kit/ndef_kit.dart`，提供：

- `NdefClient.instance`：检测、读取、写入验证和取消会话。
- `NdefMessageData` / `NdefRecordData`：与底层插件解耦的不可变模型。
- `NdefException` / `NdefErrorCode`：可本地化的稳定错误契约。
- `NdefDiagnostics`：可复制的结构化诊断输出。

完整接入说明及 Android/iOS 宿主配置见
`packages/ndef_kit/README.md`。

### Android

项目已在 `AndroidManifest.xml` 中声明 NFC 权限，但把 NFC 硬件标记为可选，
以便无 NFC 设备也能安装并测试广告页面。NFC 页面会自行报告不支持状态。
GroMore 要求 Android API 24，并通过字节跳动官方 Maven 仓库解析固定版本。

### iOS

项目最低支持 iOS 13，并已配置：

- `NFCReaderUsageDescription`
- Near Field Communication Tag Reading capability
- `com.apple.developer.nfc.readersession.formats = TAG`

首次真机运行前，请使用 Xcode 打开 `ios/Runner.xcworkspace`，确认 Runner target 的 Signing Team 和 Bundle Identifier 对应的 provisioning profile 包含 NFC Tag Reading capability。

GroMore iOS SDK 通过 CocoaPods 接入；项目可以继续让支持 SPM 的 NFC 插件使用
Swift Package Manager。宿主负责 ATT、隐私文案、SKAdNetwork 和实际启用 ADN
的声明，本 Demo 不会主动申请这些权限。

## iOS 原生全屏界面开发约束

iOS 原生全屏广告、相机、媒体选择器、认证页等界面关闭时，可能污染 Flutter 主窗口
的触摸与转场状态，表现为返回后无法点击、滑动，或 Cupertino 侧滑返回卡在中间态。
本仓库已在真机确认独立 `UIWindow` 展示与延后清理能够解决此类问题。以后开发其他
插件前，必须先阅读 [AGENTS.md](AGENTS.md) 中的“iOS 原生全屏界面与 Flutter 触摸隔离”规则。

## 真机验收步骤

1. 启动应用，确认顶部显示“NFC 可用”。
2. 点击“开始读取”，贴近一张已知 NDEF 标签，核对显示内容。
3. 输入一段可识别的真实测试文本或 URI。
4. 点击“写入并回读验证”，确认覆盖提示后贴近一张可写测试标签。
5. 保持标签不动，直到应用显示“写入成功，回读内容与待写内容完全一致”。
6. 再次点击“开始读取”，确认内容与写入值一致。
7. 分别验证只读标签、容量不足、移开标签和取消扫描等错误路径。

> 写入会覆盖标签现有的全部 NDEF 记录。请只使用允许覆盖的测试标签。

## 自动化验证

```shell
flutter analyze
flutter test

# 需要真实 App ID/代码位、网络和 Android/iOS 设备或模拟器。
flutter test integration_test/gromore_lifecycle_test.dart \
  -d <device-id> \
  --dart-define-from-file=dart_defines.json

cd packages/ndef_kit
flutter analyze
flutter test
```

自动化测试覆盖 NDEF 文本/URI/原始记录、不可变模型、错误契约、诊断输出以及
小屏布局，不伪造 NFC 平台返回值。真实读写结果只能通过 Android/iOS 真机和
物理标签验证。

GroMore 设备集成测试不使用 Mock，会真实验证初始化、Provider 释放重建和奖励
广告加载到 Ready。广告展示/关闭、点击和 SSV 奖励结算仍需按测试页面与真机
验收流程完成。
