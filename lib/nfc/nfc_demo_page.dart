import 'dart:async';

import 'package:demo/nfc/nfc_controller.dart';
import 'package:demo/nfc/nfc_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_kit/ndef_kit.dart';

class NfcDemoPage extends ConsumerStatefulWidget {
  const NfcDemoPage({super.key});

  @override
  ConsumerState<NfcDemoPage> createState() => _NfcDemoPageState();
}

class _NfcDemoPageState extends ConsumerState<NfcDemoPage> {
  final _formKey = GlobalKey<FormState>();
  final _payloadController = TextEditingController();
  late final NfcController _controller;
  NfcPayloadKind _payloadKind = NfcPayloadKind.text;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(nfcControllerProvider.notifier);
  }

  @override
  void dispose() {
    _payloadController.dispose();
    unawaited(_controller.cancelScan());
    super.dispose();
  }

  Future<void> _confirmAndWrite(NfcDemoState state) async {
    if (!state.canScan || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final controller = ref.read(nfcControllerProvider.notifier);
    final byteLength = controller.messageByteLength(
      _payloadKind,
      _payloadController.text,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('确认覆盖标签内容'),
        content: Text(
          '本次写入会覆盖标签当前的全部 NDEF 记录。'
          '待写消息大小为 $byteLength 字节，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续写入'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await controller.writeTag(_payloadKind, _payloadController.text);
    }
  }

  Future<void> _copyDebugInfo() async {
    final controller = ref.read(nfcControllerProvider.notifier);
    try {
      await Clipboard.setData(
        ClipboardData(text: controller.buildDebugReport()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('调试信息已复制到剪贴板')));
    } catch (error, stackTrace) {
      controller.recordExternalError(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('复制失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcControllerProvider);
    final controller = ref.read(nfcControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NDEF 标签工具'),
        centerTitle: false,
        actions: [
          IconButton(
            key: const ValueKey('check-nfc-button'),
            onPressed: state.isBusy ? null : controller.checkAvailability,
            tooltip: '重新检测 NFC',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AvailabilityCard(
                        availability: state.availability,
                        isChecking: state.operation == NfcOperation.checking,
                      ),
                      const SizedBox(height: 12),
                      _NoticeBanner(
                        message: state.notice,
                        tone: state.noticeTone,
                      ),
                      if (state.operation == NfcOperation.reading ||
                          state.operation == NfcOperation.writing) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: controller.cancelScan,
                          icon: const Icon(Icons.close),
                          label: const Text('取消本次扫描'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        '读取标签',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.contactless_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      '读取标签中的 NDEF 文本、URI 与原始记录，'
                                      '同时显示容量和只读状态。',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                key: const ValueKey('read-button'),
                                onPressed: state.canScan
                                    ? controller.readTag
                                    : null,
                                icon: const Icon(Icons.nfc),
                                label: const Text('开始读取'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '写入并验证',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '写入会覆盖标签当前的全部 NDEF 记录。应用会在写入后立即回读并比较。',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                                const SizedBox(height: 16),
                                SegmentedButton<NfcPayloadKind>(
                                  segments: const [
                                    ButtonSegment(
                                      value: NfcPayloadKind.text,
                                      icon: Icon(Icons.text_fields),
                                      label: Text('文本'),
                                    ),
                                    ButtonSegment(
                                      value: NfcPayloadKind.uri,
                                      icon: Icon(Icons.link),
                                      label: Text('URI'),
                                    ),
                                  ],
                                  selected: {_payloadKind},
                                  showSelectedIcon: false,
                                  onSelectionChanged: state.isBusy
                                      ? null
                                      : (selection) {
                                          setState(() {
                                            _payloadKind = selection.single;
                                          });
                                          _formKey.currentState?.validate();
                                        },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const ValueKey('payload-field'),
                                  controller: _payloadController,
                                  enabled: !state.isBusy,
                                  minLines: _payloadKind == NfcPayloadKind.text
                                      ? 3
                                      : 1,
                                  maxLines: _payloadKind == NfcPayloadKind.text
                                      ? 6
                                      : 2,
                                  keyboardType:
                                      _payloadKind == NfcPayloadKind.uri
                                      ? TextInputType.url
                                      : TextInputType.multiline,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(2048),
                                  ],
                                  decoration: InputDecoration(
                                    labelText:
                                        _payloadKind == NfcPayloadKind.text
                                        ? '文本内容'
                                        : 'URI',
                                    hintText:
                                        _payloadKind == NfcPayloadKind.text
                                        ? '输入要写入标签的真实文本'
                                        : '例如：https://your-domain.example/path',
                                    helperText:
                                        _payloadKind == NfcPayloadKind.uri
                                        ? '必须包含协议，例如 https://、tel: 或 mailto:'
                                        : '使用 UTF-8 编码，语言代码为 zh',
                                  ),
                                  validator: (value) {
                                    final input = value ?? '';
                                    if (input.trim().isEmpty) {
                                      return '内容不能为空';
                                    }
                                    if (_payloadKind == NfcPayloadKind.uri) {
                                      final uri = Uri.tryParse(input.trim());
                                      if (uri == null || uri.scheme.isEmpty) {
                                        return '请输入包含协议的有效 URI';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                FilledButton.tonalIcon(
                                  key: const ValueKey('write-button'),
                                  onPressed: state.canScan
                                      ? () => _confirmAndWrite(state)
                                      : null,
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('写入并回读验证'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ResultSection(snapshot: state.lastSnapshot),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('copy-debug-button'),
        onPressed: _copyDebugInfo,
        tooltip: '复制 NFC 调试信息',
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('复制调试信息'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.availability,
    required this.isChecking,
  });

  final NdefAvailability? availability;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label, detail, color) = isChecking
        ? (Icons.sync, '检测中', '正在查询设备 NFC 状态', colorScheme.primary)
        : switch (availability) {
            NdefAvailability.enabled => (
              Icons.check_circle,
              'NFC 可用',
              '设备已支持并开启 NFC',
              colorScheme.primary,
            ),
            NdefAvailability.disabled => (
              Icons.settings,
              'NFC 已关闭',
              '请在系统设置中开启 NFC',
              colorScheme.error,
            ),
            NdefAvailability.unsupported => (
              Icons.phonelink_erase,
              '不支持 NFC',
              '请使用支持 NFC 的 Android 设备或 iPhone 真机',
              colorScheme.error,
            ),
            null => (
              Icons.help_outline,
              '尚未检测',
              '点击右上角刷新按钮检测 NFC',
              colorScheme.outline,
            ),
          };

    return Card(
      key: const ValueKey('availability-card'),
      color: color.withValues(alpha: 0.08),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isChecking)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            else
              Icon(icon, color: color, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, required this.tone});

  final String message;
  final NfcNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (tone) {
      NfcNoticeTone.info => (Icons.info_outline, colorScheme.secondary),
      NfcNoticeTone.success => (Icons.task_alt, colorScheme.primary),
      NfcNoticeTone.error => (Icons.error_outline, colorScheme.error),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.snapshot});

  final NdefTagResult? snapshot;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    return Column(
      key: const ValueKey('result-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('最近结果', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (current == null)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.nfc_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 10),
                  const Text('尚无真实标签读写结果'),
                ],
              ),
            ),
          )
        else
          _TagResultCard(snapshot: current),
      ],
    );
  }
}

class _TagResultCard extends StatelessWidget {
  const _TagResultCard({required this.snapshot});

  final NdefTagResult snapshot;

  @override
  Widget build(BuildContext context) {
    final message = snapshot.message;
    final records = message?.records ?? const <NdefRecordData>[];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  snapshot.source == NdefResultSource.writeVerified
                      ? Icons.verified
                      : Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.source == NdefResultSource.writeVerified
                        ? '写入并回读验证通过'
                        : '标签读取结果',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: snapshot.isWritable ? Icons.edit : Icons.lock_outline,
                  label: snapshot.isWritable ? '可写' : '只读',
                ),
                _InfoChip(
                  icon: Icons.sd_storage_outlined,
                  label: '容量 ${snapshot.maxSize} B',
                ),
                _InfoChip(
                  icon: Icons.data_object,
                  label: '消息 ${message?.byteLength ?? 0} B',
                ),
                _InfoChip(icon: Icons.list_alt, label: '${records.length} 条记录'),
              ],
            ),
            if (snapshot.additionalData.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                snapshot.additionalData.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 28),
            if (message == null)
              const Text('标签没有返回 NDEF 消息。')
            else if (records.isEmpty)
              const Text('NDEF 消息不包含记录。')
            else
              ...records.indexed.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.$1 == records.length - 1 ? 0 : 12,
                  ),
                  child: _RecordCard(index: entry.$1, record: entry.$2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.index, required this.record});

  final int index;
  final NdefRecordData record;

  @override
  Widget build(BuildContext context) {
    final content =
        record.content ??
        (record.payload.isEmpty
            ? ''
            : '0x${NdefDiagnostics.bytesToHex(record.payload)}');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '记录 ${index + 1} · ${_recordKindLabel(record)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('${record.byteLength} B'),
              ],
            ),
            const SizedBox(height: 10),
            SelectionArea(
              child: Text(
                content.isEmpty ? '（空内容）' : content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _recordDetail(record),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: const Text('原始字段'),
              children: [
                _RawField(
                  label: 'TNF',
                  value: _typeNameFormatLabel(record.typeNameFormat),
                ),
                _RawField(
                  label: 'Type',
                  value: record.type.isEmpty
                      ? '（空）'
                      : NdefDiagnostics.bytesToHex(record.type),
                ),
                _RawField(
                  label: 'ID',
                  value: record.identifier.isEmpty
                      ? '（空）'
                      : NdefDiagnostics.bytesToHex(record.identifier),
                ),
                _RawField(
                  label: 'Payload',
                  value: record.payload.isEmpty
                      ? '（空）'
                      : NdefDiagnostics.bytesToHex(record.payload),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _recordKindLabel(NdefRecordData record) {
    final failed = record.decodingError != null;
    return switch (record.kind) {
      NdefRecordKind.text => failed ? '文本（解码失败）' : '文本',
      NdefRecordKind.uri => failed ? 'URI（解码失败）' : 'URI',
      NdefRecordKind.other => '其他记录',
    };
  }

  static String _recordDetail(NdefRecordData record) {
    final error = record.decodingError;
    if (error != null) {
      return error;
    }
    return switch (record.kind) {
      NdefRecordKind.text =>
        '语言：${record.languageCode?.isEmpty ?? true ? '未指定' : record.languageCode}'
            ' · 编码：${record.textEncoding == NdefTextEncoding.utf16 ? 'UTF-16' : 'UTF-8'}',
      NdefRecordKind.uri =>
        'NFC URI 前缀代码：0x${(record.uriPrefixCode ?? 0).toRadixString(16).padLeft(2, '0').toUpperCase()}',
      NdefRecordKind.other => '未识别的 NDEF 记录，已保留原始字段。',
    };
  }

  static String _typeNameFormatLabel(NdefTypeNameFormat format) {
    return switch (format) {
      NdefTypeNameFormat.empty => 'EMPTY',
      NdefTypeNameFormat.wellKnown => 'WELL_KNOWN',
      NdefTypeNameFormat.media => 'MEDIA',
      NdefTypeNameFormat.absoluteUri => 'ABSOLUTE_URI',
      NdefTypeNameFormat.external => 'EXTERNAL',
      NdefTypeNameFormat.unknown => 'UNKNOWN',
      NdefTypeNameFormat.unchanged => 'UNCHANGED',
    };
  }
}

class _RawField extends StatelessWidget {
  const _RawField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: SelectionArea(
              child: Text(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
