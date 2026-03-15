import 'dart:async';
import 'dart:typed_data';

import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_speed_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ProgressPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const ProgressPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
    super.key,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with Refena {
  int _totalBytes = double.maxFinite.toInt();
  int _lastRemainingTimeUpdate = 0;
  String? _remainingTime;
  List<FileDto> _files = [];
  Set<String> _selectedFiles = {};
  SessionStatus? _lastStatus;

  int _finishCounter = 3;
  Timer? _finishTimer;
  Timer? _wakelockPlusTimer;

  bool _advanced = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        unawaited(WakelockPlus.enable());
      } catch (_) {}

      _wakelockPlusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        try {
          unawaited(WakelockPlus.enable());
        } catch (_) {}
      });

      if (ref.read(settingsProvider).autoFinish) {
        _finishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final finished = ref.read(serverProvider)?.session?.files.values.map((entry) => entry.status).isFinishedOrSkipped ??
              ref.read(sendProvider)[widget.sessionId]?.files.values.map((entry) => entry.status).isFinishedOrSkipped ??
              true;
          if (finished) {
            if (_finishCounter == 1) {
              timer.cancel();
              _exitWithStopBgTask(closeSession: true);
            } else {
              setState(() {
                _finishCounter--;
              });
            }
          }
        });
      }

      setState(() {
        final receiveSession = ref.read(serverProvider)?.session;
        if (receiveSession != null) {
          _files = receiveSession.files.values.map((entry) => entry.file).toList();
          _selectedFiles = receiveSession.files.values.where((entry) => entry.status != FileStatus.skipped).map((entry) => entry.file.id).toSet();
        } else {
          final sendSession = ref.read(sendProvider)[widget.sessionId];
          if (sendSession != null) {
            _files = sendSession.files.values.map((entry) => entry.file).toList();
            _selectedFiles = sendSession.files.values.where((entry) => entry.status != FileStatus.skipped).map((entry) => entry.file.id).toSet();
          }
        }

        _totalBytes = _files.where((file) => _selectedFiles.contains(file.id)).fold(0, (prev, curr) => prev + curr.size);
      });
    });

    unawaited(_startContinuousTask());
  }

  Future<void> _startContinuousTask() async {
    const platform = MethodChannel('samples.flutter.dev/downloadplugin');
    await platform.invokeMethod<String>('startContinuousTask');
  }

  Future<void> _stopContinuousTask() async {
    const platform = MethodChannel('samples.flutter.dev/downloadplugin');
    await platform.invokeMethod<String>('stopContinuousTask');
  }

  Future<void> _exit({required bool closeSession}) async {
    final receiveSession = ref.read(serverProvider.select((state) => state?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession && (status == SessionStatus.sending || status == SessionStatus.finishedWithErrors);
    final result = status == null || keepSession || await _askCancelConfirmation(status);

    if (result && mounted) {
      if (receiveSession != null) {
        Routerino.context.pushRootImmediately(
          () => const HomePage(initialTab: HomeTab.receive, appStart: false),
        );
      } else if (sendSession != null && widget.closeSessionOnClose) {
        Routerino.context.pushRootImmediately(
          () => const HomePage(initialTab: HomeTab.send, appStart: false),
        );
      } else {
        context.popUntilRoot();
      }
    }
  }

  Future<void> _exitWithStopBgTask({required bool closeSession}) async {
    final receiveSession = ref.read(serverProvider.select((state) => state?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession && (status == SessionStatus.sending || status == SessionStatus.finishedWithErrors);
    final result = status == null || keepSession || await _askCancelConfirmation(status);
    await _stopContinuousTask();

    if (result && mounted) {
      if (receiveSession != null) {
        Routerino.context.pushRootImmediately(
          () => const HomePage(initialTab: HomeTab.receive, appStart: false),
        );
      } else if (sendSession != null && widget.closeSessionOnClose) {
        Routerino.context.pushRootImmediately(
          () => const HomePage(initialTab: HomeTab.send, appStart: false),
        );
      } else {
        context.popUntilRoot();
      }
    }
  }

  Future<bool> _askCancelConfirmation(SessionStatus status) async {
    final bool result = switch (status == SessionStatus.sending) {
      true => (await context.pushBottomSheet(() => const CancelSessionDialog())) == true,
      false => true,
    };

    if (result) {
      final receiveSession = ref.read(serverProvider)?.session;
      final sendState = ref.read(sendProvider)[widget.sessionId];

      if (receiveSession != null) {
        if (receiveSession.status == SessionStatus.sending) {
          ref.notifier(serverProvider).cancelSession();
        } else {
          ref.notifier(serverProvider).closeSession();
        }
      } else if (sendState != null) {
        if (sendState.status == SessionStatus.sending) {
          ref.notifier(sendProvider).cancelSession(widget.sessionId);
        } else {
          ref.notifier(sendProvider).closeSession(widget.sessionId);
        }
      }
    }

    return result;
  }

  @override
  void dispose() {
    super.dispose();
    _finishTimer?.cancel();
    _wakelockPlusTimer?.cancel();
    TaskbarHelper.clearProgressBar();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final progressNotifier = ref.watch(progressProvider);
    final currBytes = _files.fold<int>(0, (prev, curr) => prev + ((progressNotifier.getProgress(sessionId: widget.sessionId, fileId: curr.id) * curr.size).round()));

    final receiveSession = ref.watch(serverProvider.select((state) => state?.session));
    final sendSession = ref.watch(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;

    if (status == SessionStatus.sending) {
      TaskbarHelper.setProgressBar(currBytes, _totalBytes);
    } else if (status != _lastStatus) {
      _lastStatus = status;
      TaskbarHelper.visualizeStatus(status);
    }

    if (status == null) {
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox());
    }

    final title = receiveSession != null ? t.progressPage.titleReceiving : t.progressPage.titleSending;
    final startTime = receiveSession?.startTime ?? sendSession?.startTime;
    final endTime = receiveSession?.endTime ?? sendSession?.endTime;

    final int? speedInBytes;
    if (startTime != null && currBytes >= 500 * 1024) {
      speedInBytes = getFileSpeed(start: startTime, end: endTime ?? DateTime.now().millisecondsSinceEpoch, bytes: currBytes);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRemainingTimeUpdate >= 1000) {
        _remainingTime = getRemainingTime(bytesPerSeconds: speedInBytes, remainingBytes: _totalBytes - currBytes);
        _lastRemainingTimeUpdate = now;
      }
    } else {
      speedInBytes = null;
    }

    final fileStatusMap = receiveSession?.files.map((key, file) => MapEntry(key, file.status)) ?? sendSession!.files.map((key, file) => MapEntry(key, file.status));
    final finishedCount = fileStatusMap.values.where((entry) => entry == FileStatus.finished).length;
    final failedCount = fileStatusMap.values.where((entry) => entry == FileStatus.failed).length;
    final skippedCount = fileStatusMap.values.where((entry) => entry == FileStatus.skipped).length;
    final selectedCount = _selectedFiles.isEmpty ? _files.length : _selectedFiles.length;
    final totalBytes = _totalBytes == double.maxFinite.toInt() ? null : _totalBytes;
    final progressValue = totalBytes == null ? null : totalBytes == 0 ? 0.0 : (currBytes / totalBytes).clamp(0.0, 1.0);
    final sectionSpacing = context.adaptiveSectionSpacing;

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        _exit(closeSession: widget.closeSessionOnClose);
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(title),
              )
            : null,
        body: AppBackdrop(
          child: SafeArea(
            top: !widget.showAppBar,
            child: ResponsiveListView(
              maxWidth: 920,
              padding: EdgeInsets.fromLTRB(
                context.adaptiveHorizontalPadding,
                context.adaptiveTopPadding,
                context.adaptiveHorizontalPadding,
                context.adaptiveBottomPadding,
              ),
              children: [
                ModernPageHeader(
                  title: title,
                  subtitle: receiveSession != null
                      ? t.progressPage.header.receivingFrom(device: receiveSession.senderAlias)
                      : sendSession != null
                          ? t.progressPage.header.sendingTo(device: sendSession.target.alias)
                          : t.progressPage.header.preparing,
                  trailing: widget.showAppBar
                      ? null
                      : IconButton(
                          tooltip: status == SessionStatus.sending ? t.general.cancel : t.general.done,
                          onPressed: () => _exitWithStopBgTask(closeSession: true),
                          icon: Icon(status == SessionStatus.sending ? Icons.close_rounded : Icons.check_circle_rounded),
                        ),
                  chips: [
                    StatusChip(
                      label: status.chipLabel,
                      icon: status.icon,
                      color: status.getColor(context),
                      emphasized: true,
                    ),
                    if (speedInBytes != null)
                      StatusChip(
                        label: '${speedInBytes.asReadableFileSize}/s',
                        icon: Icons.speed_rounded,
                      ),
                    if (_remainingTime != null && status == SessionStatus.sending)
                      StatusChip(
                        label: _remainingTime!,
                        icon: Icons.schedule_rounded,
                      ),
                  ],
                ),
                if (receiveSession != null && checkPlatformWithFileSystem()) ...[
                  SizedBox(height: sectionSpacing),
                  GlassSectionCard(
                    title: t.progressPage.destination.title,
                    subtitle: receiveSession.saveToGallery
                        ? t.progressPage.destination.savingToGallery
                        : t.progressPage.destination.savingToFolder,
                    trailing: !checkPlatform([TargetPlatform.iOS])
                        ? FilledButton.tonalIcon(
                            onPressed: () async {
                              await openFolder(folderPath: receiveSession.destinationDirectory);
                            },
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(t.receiveHistoryPage.openFolder),
                          )
                        : null,
                    child: SelectableText(
                      receiveSession.destinationDirectory,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ),
                ],
                if (sendSession?.errorMessage != null) ...[
                  SizedBox(height: sectionSpacing),
                  GlassSectionCard(
                    title: t.progressPage.errorCard.title,
                    subtitle: t.progressPage.errorCard.subtitle,
                    strong: true,
                    trailing: StatusChip(
                      label: t.general.error,
                      icon: Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.warning,
                      emphasized: true,
                    ),
                    child: SelectableText(
                      sendSession!.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.warning,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: sectionSpacing),
                GlassSectionCard(
                  title: t.progressPage.overview.title,
                  subtitle: status.description(isReceiving: receiveSession != null),
                  strong: true,
                  trailing: StatusChip(
                    label: '$finishedCount / $selectedCount',
                    icon: Icons.done_all_rounded,
                    emphasized: true,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.getLabel(remainingTime: _remainingTime ?? '-'),
                        style: (context.isPhoneLayout ? Theme.of(context).textTheme.headlineSmall : Theme.of(context).textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: context.isPhoneLayout ? -0.2 : -0.5,
                        ),
                      ),
                      SizedBox(height: context.isPhoneLayout ? 14 : 18),
                      if (progressValue == null)
                        const CustomProgressBar(progress: null, borderRadius: 7)
                      else
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progressValue),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return CustomProgressBar(progress: value, borderRadius: 7);
                          },
                        ),
                      SizedBox(height: context.isPhoneLayout ? 14 : 18),
                      _ProgressStatLine(
                        icon: Icons.check_circle_rounded,
                        label: t.progressPage.overview.completed,
                        value: '$finishedCount / $selectedCount',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      _ProgressStatLine(
                        icon: Icons.data_usage_rounded,
                        label: t.progressPage.overview.transferred,
                        value: '${currBytes.asReadableFileSize} / ${totalBytes == null ? '-' : totalBytes.asReadableFileSize}',
                      ),
                      if (speedInBytes != null) ...[
                        const SizedBox(height: 10),
                        _ProgressStatLine(
                          icon: Icons.speed_rounded,
                          label: t.progressPage.overview.speed,
                          value: '${speedInBytes.asReadableFileSize}/s',
                        ),
                      ],
                      if (failedCount > 0) ...[
                        const SizedBox(height: 10),
                        _ProgressStatLine(
                          icon: Icons.error_outline_rounded,
                          label: t.progressPage.overview.errors,
                          value: '$failedCount',
                          color: Theme.of(context).colorScheme.warning,
                        ),
                      ],
                      AnimatedCrossFade(
                        crossFadeState: _advanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 220),
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.progressPage.total.count(curr: finishedCount, n: selectedCount)),
                              Text(t.progressPage.total.size(curr: currBytes.asReadableFileSize, n: totalBytes == null ? '-' : totalBytes.asReadableFileSize)),
                              if (speedInBytes != null) Text(t.progressPage.total.speed(speed: speedInBytes.asReadableFileSize)),
                              if (skippedCount > 0) Text('${t.general.skipped}: $skippedCount'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: context.isPhoneLayout ? 16 : 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _advanced = !_advanced;
                              });
                            },
                            icon: Icon(_advanced ? Icons.visibility_off_rounded : Icons.tune_rounded),
                            label: Text(_advanced ? t.general.hide : t.general.advanced),
                          ),
                          if (receiveSession != null && checkPlatformWithFileSystem() && !checkPlatform([TargetPlatform.iOS]))
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                await openFolder(folderPath: receiveSession.destinationDirectory);
                              },
                              icon: const Icon(Icons.folder_open_rounded),
                              label: Text(t.receiveHistoryPage.openFolder),
                            ),
                          FilledButton.icon(
                            onPressed: () => _exitWithStopBgTask(closeSession: true),
                            icon: Icon(status == SessionStatus.sending ? Icons.close_rounded : Icons.check_circle_rounded),
                            label: Text(
                              status == SessionStatus.sending
                                  ? t.general.cancel
                                  : _finishTimer != null
                                      ? '${t.general.done} ($_finishCounter)'
                                      : t.general.done,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionSpacing),
                GlassSectionCard(
                  title: t.general.files,
                  subtitle: _files.isEmpty
                      ? t.progressPage.filesCard.empty
                      : t.progressPage.filesCard.selected(n: selectedCount),
                  child: _files.isEmpty
                      ? Text(
                          t.progressPage.filesCard.empty,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.visuals.mutedForeground),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _files.length,
                          separatorBuilder: (context, index) => SizedBox(height: context.isPhoneLayout ? 10 : 12),
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final fileName = receiveSession?.files[file.id]?.desiredName ?? file.fileName;
                            final fileStatus = fileStatusMap[file.id]!;
                            final savedToGallery = receiveSession?.files[file.id]?.savedToGallery ?? false;

                            final String? filePath;
                            if (receiveSession != null && fileStatus == FileStatus.finished && !savedToGallery) {
                              filePath = receiveSession.files[file.id]!.path;
                            } else if (sendSession != null) {
                              filePath = sendSession.files[file.id]!.path;
                            } else {
                              filePath = null;
                            }

                            final String? errorMessage;
                            if (receiveSession != null) {
                              errorMessage = receiveSession.files[file.id]!.errorMessage;
                            } else if (sendSession != null) {
                              errorMessage = sendSession.files[file.id]!.errorMessage;
                            } else {
                              errorMessage = null;
                            }

                            final Uint8List? thumbnail;
                            final AssetEntity? asset;
                            if (sendSession != null) {
                              thumbnail = sendSession.files[file.id]!.thumbnail;
                              asset = sendSession.files[file.id]!.asset;
                            } else {
                              thumbnail = null;
                              asset = null;
                            }

                            return _TransferFileCard(
                              file: file,
                              fileName: fileName,
                              fileStatus: fileStatus,
                              savedToGallery: savedToGallery,
                              filePath: filePath,
                              thumbnail: thumbnail,
                              asset: asset,
                              progress: progressNotifier.getProgress(sessionId: widget.sessionId, fileId: file.id),
                              errorMessage: errorMessage,
                              onTap: filePath != null && receiveSession != null
                                  ? () async {
                                      await openFile(context, file.fileType, filePath!);
                                    }
                                  : null,
                              onRetry: sendSession != null && fileStatus == FileStatus.failed
                                  ? () async {
                                      await ref.notifier(sendProvider).sendFile(
                                            sessionId: widget.sessionId,
                                            isolateIndex: 0,
                                            file: sendSession.files[file.id]!,
                                            isRetry: true,
                                          );
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressStatLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _ProgressStatLine({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isPhoneLayout ? 14 : 16,
        vertical: context.isPhoneLayout ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: color == null ? visuals.glassSurfaceStrong : color!.withOpacity(0.12),
        borderRadius: visuals.mediumRadius,
        border: Border.all(
          color: color == null ? visuals.glassBorder : color!.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: resolvedColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: resolvedColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: visuals.mutedForeground,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: resolvedColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferFileCard extends StatelessWidget {
  final FileDto file;
  final String fileName;
  final FileStatus fileStatus;
  final bool savedToGallery;
  final String? filePath;
  final Uint8List? thumbnail;
  final AssetEntity? asset;
  final double? progress;
  final String? errorMessage;
  final VoidCallback? onTap;
  final Future<void> Function()? onRetry;

  const _TransferFileCard({
    required this.file,
    required this.fileName,
    required this.fileStatus,
    required this.savedToGallery,
    required this.filePath,
    required this.thumbnail,
    required this.asset,
    required this.progress,
    required this.errorMessage,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final compact = context.isPhoneLayout;
    final statusColor = fileStatus.getColor(context);
    final statusLabel = savedToGallery
        ? t.progressPage.savedToGallery
        : fileStatus == FileStatus.sending
            ? progress == null
                ? t.progressPage.fileCard.preparing
                : '${((progress ?? 0) * 100).round()}%'
            : fileStatus.label;

    final actionWidgets = <Widget>[
      StatusChip(
        label: statusLabel,
        icon: fileStatus.icon,
        color: statusColor,
        emphasized: true,
      ),
      if (errorMessage != null)
        IconButton(
          tooltip: t.general.error,
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => ErrorDialog(error: errorMessage!),
            );
          },
          icon: Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.warning,
          ),
        ),
      if (onRetry != null)
        IconButton(
          tooltip: t.progressPage.fileCard.retry,
          onPressed: () async {
            await onRetry!();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
    ];

    return GlassSurface(
      applyBlur: false,
      strong: fileStatus == FileStatus.failed,
      color: fileStatus == FileStatus.failed
          ? Theme.of(context).colorScheme.warning.withOpacity(0.08)
          : visuals.glassSurfaceStrong,
      borderRadius: visuals.mediumRadius,
      padding: EdgeInsets.all(compact ? 14 : 16),
      onTap: onTap,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartFileThumbnail(
                      bytes: thumbnail,
                      asset: asset,
                      path: filePath,
                      fileType: file.fileType,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.size.asReadableFileSize,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: visuals.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (fileStatus == FileStatus.sending) ...[
                  CustomProgressBar(
                    progress: progress,
                    borderRadius: 7,
                    color: statusColor,
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actionWidgets,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartFileThumbnail(
                  bytes: thumbnail,
                  asset: asset,
                  path: filePath,
                  fileType: file.fileType,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            file.size.asReadableFileSize,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: visuals.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (fileStatus == FileStatus.sending) ...[
                        CustomProgressBar(
                          progress: progress,
                          borderRadius: 7,
                          color: statusColor,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: actionWidgets,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

extension on FileStatus {
  String get label {
    switch (this) {
      case FileStatus.queue:
        return t.general.queue;
      case FileStatus.skipped:
        return t.general.skipped;
      case FileStatus.sending:
        return '';
      case FileStatus.failed:
        return t.general.error;
      case FileStatus.finished:
        return t.general.done;
    }
  }

  IconData get icon {
    switch (this) {
      case FileStatus.queue:
        return Icons.schedule_rounded;
      case FileStatus.skipped:
        return Icons.remove_circle_outline_rounded;
      case FileStatus.sending:
        return Icons.sync_rounded;
      case FileStatus.failed:
        return Icons.error_outline_rounded;
      case FileStatus.finished:
        return Icons.check_circle_rounded;
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case FileStatus.queue:
      case FileStatus.sending:
      case FileStatus.finished:
        return Theme.of(context).colorScheme.primary;
      case FileStatus.skipped:
        return context.visuals.mutedForeground;
      case FileStatus.failed:
        return Theme.of(context).colorScheme.warning;
    }
  }
}

extension on SessionStatus {
  String getLabel({required String remainingTime}) {
    switch (this) {
      case SessionStatus.sending:
        return t.progressPage.total.title.sending(time: remainingTime);
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
      case SessionStatus.waiting:
        return t.progressPage.status.labelWaiting;
      case SessionStatus.recipientBusy:
        return t.progressPage.status.labelBusy;
      case SessionStatus.declined:
        return t.progressPage.status.labelDeclined;
      case SessionStatus.tooManyAttempts:
        return t.progressPage.status.labelTooManyAttempts;
    }
  }

  String get chipLabel {
    switch (this) {
      case SessionStatus.waiting:
        return t.progressPage.status.chipWaiting;
      case SessionStatus.recipientBusy:
        return t.progressPage.status.chipBusy;
      case SessionStatus.declined:
        return t.progressPage.status.chipDeclined;
      case SessionStatus.tooManyAttempts:
        return t.progressPage.status.chipTooManyAttempts;
      case SessionStatus.sending:
        return t.progressPage.status.chipActive;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.general.error;
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return t.progressPage.status.chipCanceled;
    }
  }

  IconData get icon {
    switch (this) {
      case SessionStatus.waiting:
        return Icons.hourglass_top_rounded;
      case SessionStatus.recipientBusy:
        return Icons.pause_circle_outline_rounded;
      case SessionStatus.declined:
        return Icons.cancel_outlined;
      case SessionStatus.tooManyAttempts:
        return Icons.error_outline_rounded;
      case SessionStatus.sending:
        return Icons.sync_rounded;
      case SessionStatus.finished:
        return Icons.check_circle_rounded;
      case SessionStatus.finishedWithErrors:
        return Icons.error_outline_rounded;
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return Icons.close_rounded;
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case SessionStatus.finished:
      case SessionStatus.sending:
      case SessionStatus.waiting:
        return Theme.of(context).colorScheme.primary;
      case SessionStatus.recipientBusy:
      case SessionStatus.declined:
      case SessionStatus.tooManyAttempts:
      case SessionStatus.finishedWithErrors:
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return Theme.of(context).colorScheme.warning;
    }
  }

  String description({required bool isReceiving}) {
    switch (this) {
      case SessionStatus.waiting:
        return t.progressPage.status.descriptionWaiting;
      case SessionStatus.recipientBusy:
        return t.progressPage.status.descriptionBusy;
      case SessionStatus.declined:
        return t.progressPage.status.descriptionDeclined;
      case SessionStatus.tooManyAttempts:
        return t.progressPage.status.descriptionTooManyAttempts;
      case SessionStatus.sending:
        return isReceiving ? t.progressPage.status.descriptionReceiving : t.progressPage.status.descriptionSending;
      case SessionStatus.finished:
        return t.progressPage.status.descriptionFinished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.status.descriptionFinishedWithErrors;
      case SessionStatus.canceledBySender:
        return t.progressPage.status.descriptionCanceledBySender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.status.descriptionCanceledByReceiver;
    }
  }
}
