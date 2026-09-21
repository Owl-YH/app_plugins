import 'dart:async';
import 'dart:developer' as developer;

import 'package:demo/ads/gromore_ad_service.dart';
import 'package:demo/ads/gromore_demo_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owl_ads_gromore/owl_ads_gromore.dart';

final groMorePlatformServiceProvider = Provider<GroMorePlatformService>(
  (ref) => const GroMorePlatformService(),
);

final groMoreRepositoryProvider = Provider<GroMoreRepository>(
  (ref) => GroMoreRepository(ref.watch(groMorePlatformServiceProvider)),
);

final groMoreAdControllerProvider =
    NotifierProvider<GroMoreAdController, GroMoreAdState>(
      GroMoreAdController.new,
    );

final class GroMoreAdState {
  const GroMoreAdState({
    required this.missingRequiredKeys,
    this.privacyAccepted = false,
    this.personalizedAds = false,
    this.busy = false,
    this.initialized = false,
    this.consentApplied = false,
    this.hasProvider = false,
    this.rewardReady = false,
    this.insertReady = false,
    this.logs = const <String>[],
  });

  final List<String> missingRequiredKeys;
  final bool privacyAccepted;
  final bool personalizedAds;
  final bool busy;
  final bool initialized;
  final bool consentApplied;
  final bool hasProvider;
  final bool rewardReady;
  final bool insertReady;
  final List<String> logs;

  bool get configComplete => missingRequiredKeys.isEmpty;
  bool get canInitialize => !busy && privacyAccepted && configComplete;
  bool get canRequest =>
      initialized && consentApplied && privacyAccepted && !busy;

  GroMoreAdState copyWith({
    bool? privacyAccepted,
    bool? personalizedAds,
    bool? busy,
    bool? initialized,
    bool? consentApplied,
    bool? hasProvider,
    bool? rewardReady,
    bool? insertReady,
    List<String>? logs,
  }) {
    return GroMoreAdState(
      missingRequiredKeys: missingRequiredKeys,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      busy: busy ?? this.busy,
      initialized: initialized ?? this.initialized,
      consentApplied: consentApplied ?? this.consentApplied,
      hasProvider: hasProvider ?? this.hasProvider,
      rewardReady: rewardReady ?? this.rewardReady,
      insertReady: insertReady ?? this.insertReady,
      logs: logs ?? this.logs,
    );
  }
}

final class GroMoreAdController extends Notifier<GroMoreAdState> {
  late final GroMoreRepository _repository;
  StreamSubscription<AdEvent>? _eventSubscription;
  bool _disposed = false;

  @override
  GroMoreAdState build() {
    _repository = ref.watch(groMoreRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      unawaited(_eventSubscription?.cancel());
      unawaited(_repository.disposeProvider());
    });
    return GroMoreAdState(
      missingRequiredKeys: GroMoreDemoConfig.missingRequiredKeys,
    );
  }

  void onPageOpened() {
    _append(
      state.initialized
          ? '广告测试页已打开；复用应用级 GroMore Provider。'
          : '广告测试页已打开；尚未调用原生 SDK。',
    );
  }

  void onAppLifecycleChanged(String lifecycle) {
    _append('App lifecycle: $lifecycle');
  }

  void setPrivacyAccepted(bool accepted) {
    if (state.busy) return;
    state = state.copyWith(
      privacyAccepted: accepted,
      personalizedAds: accepted ? state.personalizedAds : false,
      consentApplied: false,
    );
  }

  void setPersonalizedAds(bool enabled) {
    if (state.busy || !state.privacyAccepted) return;
    state = state.copyWith(personalizedAds: enabled, consentApplied: false);
  }

  Future<void> initializeOrUpdateConsent() => _run('初始化或更新授权', () async {
    GroMoreDemoConfig.requireComplete();
    if (!state.privacyAccepted) {
      throw StateError('请先确认宿主隐私政策，再初始化 GroMore。');
    }

    if (!_repository.hasProvider) {
      _repository.ensureProvider(GroMoreDemoConfig.createProviderConfig());
      _eventSubscription = _repository.events.listen(
        _onAdEvent,
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'GroMore event stream failed',
            name: 'demo.ads',
            error: error,
            stackTrace: stackTrace,
          );
          _append('事件流错误：${formatError(error)}');
        },
      );
      state = state.copyWith(hasProvider: true);
    }

    await _repository.initialize(
      AdConsent(accepted: true, personalizedAds: state.personalizedAds),
    );
    state = state.copyWith(
      initialized: _repository.initialized,
      consentApplied: _repository.initialized,
    );
  });

  Future<void> withdrawConsent() => _run('撤回广告授权', () async {
    state = state.copyWith(
      privacyAccepted: false,
      personalizedAds: false,
      consentApplied: false,
      rewardReady: false,
      insertReady: false,
    );
    await _repository.updateConsent(const AdConsent(accepted: false));
  });

  Future<void> disposeProvider() => _run('终止应用级广告 Runtime', () async {
    final subscription = _eventSubscription;
    _eventSubscription = null;
    await subscription?.cancel();
    await _repository.disposeProvider();
    state = state.copyWith(
      initialized: false,
      consentApplied: false,
      hasProvider: true,
      rewardReady: false,
      insertReady: false,
    );
    _append('GroMore Runtime 已终止；同一 Dart isolate 不允许重建，请重启应用继续测试。');
  });

  Future<void> loadReward() => _run('加载奖励广告', () async {
    await _repository.loadReward(
      GroMoreDemoConfig.rewardPlacement,
      options: GroMoreDemoConfig.rewardOptions,
    );
    final ready = await _repository.isRewardReady(
      GroMoreDemoConfig.rewardPlacement,
    );
    state = state.copyWith(rewardReady: ready);
  });

  Future<void> checkRewardReady() => _run('检查奖励广告就绪状态', () async {
    final ready = await _repository.isRewardReady(
      GroMoreDemoConfig.rewardPlacement,
    );
    state = state.copyWith(rewardReady: ready);
    _append('奖励广告 ready=$ready');
  });

  Future<void> showReward() => _run('展示奖励广告', () async {
    final result = await _repository.showReward(
      GroMoreDemoConfig.rewardPlacement,
    );
    state = state.copyWith(rewardReady: false);
    _append(
      '奖励广告关闭：rewarded=${result.rewarded}, '
      'verified=${result.verified}, name=${result.rewardName ?? '-'}, '
      'amount=${result.rewardAmount ?? '-'}。客户端结果仅用于 UI，SSV 后端负责结算。',
    );
  });

  Future<void> loadInsert() => _run('加载全屏插屏广告', () async {
    await _repository.loadInsert(GroMoreDemoConfig.insertPlacement);
    final ready = await _repository.isInsertReady(
      GroMoreDemoConfig.insertPlacement,
    );
    state = state.copyWith(insertReady: ready);
  });

  Future<void> checkInsertReady() => _run('检查插屏广告就绪状态', () async {
    final ready = await _repository.isInsertReady(
      GroMoreDemoConfig.insertPlacement,
    );
    state = state.copyWith(insertReady: ready);
    _append('插屏广告 ready=$ready');
  });

  Future<void> showInsert() => _run('展示全屏插屏广告', () async {
    await _repository.showInsert(GroMoreDemoConfig.insertPlacement);
    state = state.copyWith(insertReady: false);
    _append('插屏广告已关闭。');
  });

  void clearLogs() {
    state = state.copyWith(logs: const <String>[]);
  }

  String buildLogText() => state.logs.reversed.join('\n');

  Future<void> _run(String operation, Future<void> Function() action) async {
    if (state.busy || _disposed) return;
    state = state.copyWith(busy: true);
    _append('开始：$operation');
    try {
      await action();
      _append('完成：$operation');
    } catch (error, stackTrace) {
      developer.log(
        'GroMore demo $operation failed',
        name: 'demo.ads',
        error: error,
        stackTrace: stackTrace,
      );
      _append('失败：$operation\n${formatError(error)}');
    } finally {
      if (!_disposed) state = state.copyWith(busy: false);
    }
  }

  void _onAdEvent(AdEvent event) {
    if (_disposed) return;
    var rewardReady = state.rewardReady;
    var insertReady = state.insertReady;
    if (event.adType == AdType.reward) {
      if (event.kind == AdEventKind.loaded) rewardReady = true;
      if (event.kind == AdEventKind.closed ||
          event.kind == AdEventKind.failed) {
        rewardReady = false;
      }
    }
    if (event.adType == AdType.insert) {
      if (event.kind == AdEventKind.loaded) insertReady = true;
      if (event.kind == AdEventKind.closed ||
          event.kind == AdEventKind.failed) {
        insertReady = false;
      }
    }
    state = state.copyWith(rewardReady: rewardReady, insertReady: insertReady);
    _append(_formatEvent(event));
  }

  void _append(String message) {
    if (_disposed) return;
    final line = '[${DateTime.now().toIso8601String()}] $message';
    developer.log(line, name: 'demo.ads');
    final next = <String>[
      line,
      ...state.logs,
    ];
    if (next.length > 100) next.removeRange(100, next.length);
    state = state.copyWith(logs: List<String>.unmodifiable(next));
  }

  static String _formatEvent(AdEvent event) {
    final details = <String>[
      'EVENT ${event.kind.name}',
      '${event.adType.name}/${event.placement.name}',
      'generation=${event.requestGeneration}',
    ];
    if (event.reward case final reward?) {
      details.add(
        'rewarded=${reward.rewarded}, verified=${reward.verified}, '
        'name=${reward.rewardName ?? '-'}, amount=${reward.rewardAmount ?? '-'}',
      );
    }
    if (event.revenue case final revenue?) {
      details.add(
        'network=${revenue.networkName ?? '-'}, rawEcpm=${revenue.rawEcpm ?? '-'}, '
        'requestId=${revenue.requestId ?? '-'}',
      );
    }
    if (event.error case final error?) details.add(formatError(error));
    return details.join(' | ');
  }

  static String formatError(Object error) {
    if (error is! AdsException) return error.toString();
    return <String>[
      'code=${error.code.name}',
      'message=${error.message}',
      if (error.nativeDomain != null) 'nativeDomain=${error.nativeDomain}',
      if (error.nativeCode != null) 'nativeCode=${error.nativeCode}',
      if (error.nativeMessage != null) 'nativeMessage=${error.nativeMessage}',
      if (error.nativeDetails.isNotEmpty) 'details=${error.nativeDetails}',
    ].join(', ');
  }
}
