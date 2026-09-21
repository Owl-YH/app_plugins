# AGENTS.md

AI 代理进入本 Flutter 插件工作区后先读取本文。除通用代码质量规则外，涉及 iOS
原生全屏界面的插件必须遵守下面的窗口与生命周期约束。

本仓库是六个插件包的唯一源码归属。`owl_ads`、`ndef_kit`、`owl_haptics`、`owl_marquee`、`spatial_confetti` 的 `0.1.0` 已从本仓库提交发布到 pub.dev；升级须先通过各包检查、审查归档，再发布新版本和标签。`owl_ads_gromore` 仍是未发布包，缺少 Android/iOS 真机广告流程与权威 SSV 验收，保留 `publish_to: none`。根 Demo 仅对已发布的依赖使用 pub.dev，GroMore 仍使用仓库内源码。

## iOS 原生全屏界面与 Flutter 触摸隔离

### 已验证事故记录

2026-08-15 在 iPhone 16 Pro、iOS 27.0 beta、Flutter 3.44.6 上验证过以下问题：

- Flutter 页面从主窗口展示 GroMore 激励广告。
- 点击广告右上角关闭按钮后，会先出现原生确认弹窗；点击“残忍拒绝”完成最终退出。
- 返回 Flutter 广告测试页后，点击和滑动全部失效；Cupertino 侧滑返回会卡在两个页面各显示一半的中间态。
- UIKit 主线程没有死锁，Flutter 页面仍可绘制，窗口和 `hitTest` 表面状态正常，但 Flutter
  的触摸/手势流已无法正常完成。
- Ads-CN `7.7.0.6` 和 `7.6.0.4` 均可复现，因此不是单一 SDK 版本回归。
- Pigeon 改成 MethodChannel 后仍可复现，因此不是 Channel 类型导致。
- 把广告完整展示在一次性独立 `UIWindow`，并等待 UIKit 关闭完成后再恢复 Flutter
  主窗口、发送关闭事件和完成 Channel 调用，真机复测恢复正常。

这次结果说明：遇到原生全屏页面关闭后 Flutter 完全不可操作时，优先检查
`UIWindow`、present/dismiss 转场和触摸序列交接，不要先把问题归因于 SDK 版本或
Platform Channel。

### 硬性实现规则

适用范围包括广告、相机、媒体选择器、扫码、认证、浏览器等由 Flutter 插件展示的
iOS 原生全屏界面。

1. 从当前 `FlutterViewController` 所在窗口或唯一的 `foregroundActive UIWindowScene`
   解析展示上下文；采用 UIScene 的宿主不得依赖 `UIApplicationDelegate.window`。
2. 对可能影响 Flutter 触摸序列的全屏原生界面，创建与原窗口属于同一
   `UIWindowScene` 的临时 `UIWindow`：
   - frame 与原窗口一致；
   - `windowLevel = previousWindow.windowLevel + 1`；
   - 使用透明且允许交互的专用根 `UIViewController`；
   - `makeKeyAndVisible()` 后，从该根控制器展示原生全屏界面。
3. session 必须在整个展示期间强持有临时窗口、专用根控制器和原 keyWindow 引用；
   不得用局部变量创建后立即释放。
4. SDK 的 `didClose` 只代表业务关闭信号，除非 SDK 文档明确保证，否则不得把它当成
   UIKit dismiss completion。
5. 禁止在 `didClose` 回调栈内同步执行以下完整链路：发送 Flutter `closed`、释放广告
   delegate/session、完成 MethodChannel/Pigeon result。这样会让 Dart 在原生触摸或关闭
   转场尚未收尾时重入。
6. 清理需要同时满足“SDK 已进入终态”和“UIKit 展示已真正结束”。优先级如下：
   - 自己控制 dismiss 时，使用 `dismiss(animated:completion:)` 的 completion；
   - 第三方 SDK 控制 dismiss 时，结合专用根控制器重新 `viewDidAppear`、
     `transitionCoordinator` 或 `presentedViewController == nil` 判断；
   - 必须设置有界非阻塞兜底，避免透明临时窗口永久吞掉触摸。本次实现采用约 1 秒上限。
7. 正常清理顺序固定为：
   - 隐藏临时窗口；
   - 恢复原窗口为 keyWindow；
   - 释放临时 root/window；
   - 再向 Flutter 发送 `closed`/`failed`；
   - 最后释放 delegate/session，并完成 Channel result。
8. show 返回失败、展示失败、超时、隐私撤回、provider dispose 和 engine detach 必须复用
   同一个幂等清理出口，不能只处理正常关闭路径。
9. 不要用 `isUserInteractionEnabled` 开关、伪造触摸、刷新 Flutter 页面或强制 pop 路由掩盖
   窗口生命周期问题。

### 验证要求

此类改动不能只靠单元测试或模拟器验收。至少在受影响的 iOS 真机上重复验证：

1. 打开原生全屏界面。
2. 走完包含二次确认弹窗的真实关闭路径。
3. 返回 Flutter 后立即测试普通点击、列表滑动和页面内按钮。
4. 测试 Cupertino 侧滑返回能否完整取消和完整提交。
5. 再验证取消、展示失败、超时、前后台切换和重复展示不会遗留透明窗口。

## 参考实现

- 本仓库实现：
  `packages/owl_ads_gromore/ios/owl_ads_gromore/Sources/owl_ads_gromore/OwlAdsGromorePlugin.swift`
- Flutter 官方 `image_picker_ios` 的同类独立窗口修复：
  <https://github.com/flutter/packages/pull/10533>
- 对应 iOS 全屏关闭触摸问题：
  <https://github.com/flutter/flutter/issues/173453>
