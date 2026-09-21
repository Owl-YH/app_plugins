import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:demo/nfc/nfc_models.dart';
import 'package:demo/nfc/nfc_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_kit/ndef_kit.dart';

final nfcPlatformServiceProvider = Provider<NfcPlatformService>(
  (ref) => NfcPlatformService(NdefClient.instance),
);

final nfcRepositoryProvider = Provider<NfcRepository>(
  (ref) => NfcRepository(ref.watch(nfcPlatformServiceProvider)),
);

final nfcControllerProvider = NotifierProvider<NfcController, NfcDemoState>(
  NfcController.new,
);

final class NfcController extends Notifier<NfcDemoState> {
  late final NfcRepository _repository;
  bool _disposed = false;

  @override
  NfcDemoState build() {
    _repository = ref.watch(nfcRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      unawaited(_repository.cancel());
    });
    return const NfcDemoState();
  }

  Future<void> checkAvailability() async {
    if (state.isBusy) return;
    _setState(
      state.copyWith(
        operation: NfcOperation.checking,
        noticeTone: NfcNoticeTone.info,
        notice: '正在检测设备 NFC 能力…',
        lastError: null,
        lastErrorStackTrace: null,
        lastErrorAt: null,
      ),
    );
    try {
      final availability = await _repository.checkAvailability();
      _setState(
        state.copyWith(
          availability: availability,
          noticeTone: availability == NdefAvailability.enabled
              ? NfcNoticeTone.success
              : NfcNoticeTone.error,
          notice: switch (availability) {
            NdefAvailability.enabled => 'NFC 已就绪，可以开始读写标签。',
            NdefAvailability.disabled => '设备支持 NFC，但当前已关闭。',
            NdefAvailability.unsupported => '当前设备不支持 NFC 标签扫描。',
          },
        ),
      );
    } catch (error, stackTrace) {
      _setState(
        _withError(
          state.copyWith(availability: null),
          error,
          stackTrace,
          error is NdefException
              ? localizedNdefError(error)
              : '检测 NFC 状态失败：$error',
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> readTag() async {
    if (!state.canScan) return;
    _setState(
      state.copyWith(
        operation: NfcOperation.reading,
        noticeTone: NfcNoticeTone.info,
        notice: '等待标签：请将标签贴近手机 NFC 感应区域。',
        lastError: null,
        lastErrorStackTrace: null,
        lastErrorAt: null,
      ),
    );
    try {
      final snapshot = await _repository.read();
      _setState(
        state.copyWith(
          lastSnapshot: snapshot,
          availability: NdefAvailability.enabled,
          noticeTone: NfcNoticeTone.success,
          notice:
              '读取成功，共发现 ${snapshot.message?.records.length ?? 0} 条 NDEF 记录。',
        ),
      );
    } on NdefCancelledException catch (error) {
      _setState(
        state.copyWith(
          noticeTone: NfcNoticeTone.info,
          notice: localizedNdefError(error),
        ),
      );
    } catch (error, stackTrace) {
      _setState(
        _withError(
          state,
          error,
          stackTrace,
          error is NdefException ? localizedNdefError(error) : '读取失败：$error',
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> writeTag(NfcPayloadKind kind, String payload) async {
    if (!state.canScan) return;
    _setState(
      state.copyWith(
        operation: NfcOperation.writing,
        noticeTone: NfcNoticeTone.info,
        notice: '等待标签：请保持标签贴近手机，直到完成写入和回读验证。',
        lastError: null,
        lastErrorStackTrace: null,
        lastErrorAt: null,
      ),
    );
    try {
      final snapshot = await _repository.write(kind, payload);
      _setState(
        state.copyWith(
          lastSnapshot: snapshot,
          availability: NdefAvailability.enabled,
          noticeTone: NfcNoticeTone.success,
          notice: '写入成功，回读内容与待写内容完全一致。',
        ),
      );
    } on NdefCancelledException catch (error) {
      _setState(
        state.copyWith(
          noticeTone: NfcNoticeTone.info,
          notice: localizedNdefError(error),
        ),
      );
    } catch (error, stackTrace) {
      _setState(
        _withError(
          state,
          error,
          stackTrace,
          error is NdefException ? localizedNdefError(error) : '写入失败：$error',
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> cancelScan() => _repository.cancel();

  int messageByteLength(NfcPayloadKind kind, String payload) =>
      _repository.createMessage(kind, payload).byteLength;

  void recordExternalError(Object error, StackTrace stackTrace) {
    _setState(_withError(state, error, stackTrace, state.notice));
  }

  String buildDebugReport() {
    final report = StringBuffer()
      ..writeln('NDEF 标签工具调试信息')
      ..writeln('生成时间: ${DateTime.now().toIso8601String()}')
      ..writeln('运行平台: ${Platform.operatingSystem}')
      ..writeln('系统版本: ${Platform.operatingSystemVersion}')
      ..writeln('NFC 状态: ${_availabilityDebugLabel(state.availability)}')
      ..writeln('当前操作: ${state.operation.name}')
      ..writeln('界面提示: ${state.notice}');

    if (state.lastError != null) {
      report
        ..writeln('错误时间: ${state.lastErrorAt?.toIso8601String() ?? '未知'}')
        ..writeln(
          NdefDiagnostics.formatException(
            state.lastError!,
            state.lastErrorStackTrace,
          ),
        );
    } else {
      report.writeln('最近错误: 无');
    }
    report
      ..writeln('最近标签结果:')
      ..writeln(NdefDiagnostics.formatTagResult(state.lastSnapshot));
    return report.toString();
  }

  static String localizedNdefError(NdefException error) {
    return switch (error.code) {
      NdefErrorCode.cancelled => '扫描已取消。',
      NdefErrorCode.sessionAlreadyActive => '已有 NFC 扫描正在进行。',
      NdefErrorCode.nfcDisabled => 'NFC 已关闭，请先在系统设置中开启。',
      NdefErrorCode.unsupported => '当前设备不支持 NFC 标签扫描。',
      NdefErrorCode.emptyMessage => '至少需要写入一条 NDEF 记录。',
      NdefErrorCode.notNdef => '检测到的标签不支持 NDEF。',
      NdefErrorCode.readOnly => '该 NDEF 标签为只读状态。',
      NdefErrorCode.capacityExceeded =>
        '消息需要 ${error.details['requiredBytes'] ?? '未知'} 字节，'
            '但标签容量只有 ${error.details['availableBytes'] ?? '未知'} 字节。',
      NdefErrorCode.verificationFailed => '写入完成，但回读内容不一致，验证失败。',
      NdefErrorCode.tagLost => '标签连接已断开，请保持标签贴近手机后重试。',
      NdefErrorCode.sessionTimeout => 'NFC 扫描已超时，请重试。',
      NdefErrorCode.systemBusy => '系统 NFC 资源暂时不可用，请稍后重试。',
      NdefErrorCode.sessionFailure => 'NFC 会话异常结束：${error.message}',
      NdefErrorCode.platformFailure => 'NFC 操作失败：${error.message}',
    };
  }

  NfcDemoState _withError(
    NfcDemoState current,
    Object error,
    StackTrace stackTrace,
    String notice,
  ) {
    developer.log(
      'NFC demo error',
      name: 'demo.nfc',
      error: error,
      stackTrace: stackTrace,
    );
    return current.copyWith(
      lastError: error,
      lastErrorStackTrace: stackTrace,
      lastErrorAt: DateTime.now(),
      noticeTone: NfcNoticeTone.error,
      notice: notice,
    );
  }

  void _finishOperation() {
    if (!_disposed) {
      state = state.copyWith(operation: NfcOperation.idle);
    }
  }

  void _setState(NfcDemoState next) {
    if (!_disposed) state = next;
  }

  static String _availabilityDebugLabel(NdefAvailability? availability) {
    return switch (availability) {
      NdefAvailability.enabled => 'enabled',
      NdefAvailability.disabled => 'disabled',
      NdefAvailability.unsupported => 'unsupported',
      null => 'unknown',
    };
  }
}
