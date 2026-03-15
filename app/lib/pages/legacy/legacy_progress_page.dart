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
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class LegacyProgressPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const LegacyProgressPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
    super.key,
  });

  @override
  State<LegacyProgressPage> createState() => _LegacyProgressPageState();
}

class _LegacyProgressPageState extends State<LegacyProgressPage> with Refena {
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

      _wakelockPlusTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) {
        try {
          unawaited(WakelockPlus.enable());
        } catch (_) {}
      });

      if (ref.read(settingsProvider).autoFinish) {
        _finishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final finished = ref
                  .read(serverProvider)
                  ?.session
                  ?.files
                  .values
                  .map((entry) => entry.status)
                  .isFinishedOrSkipped ??
              ref
                  .read(sendProvider)[widget.sessionId]
                  ?.files
                  .values
                  .map((entry) => entry.status)
                  .isFinishedOrSkipped ??
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
          _selectedFiles = receiveSession.files.values
              .where((entry) => entry.status != FileStatus.skipped)
              .map((entry) => entry.file.id)
              .toSet();
        } else {
          final sendSession = ref.read(sendProvider)[widget.sessionId];
          if (sendSession != null) {
            _files = sendSession.files.values.map((entry) => entry.file).toList();
            _selectedFiles = sendSession.files.values
                .where((entry) => entry.status != FileStatus.skipped)
                .map((entry) => entry.file.id)
                .toSet();
          }
        }

        _totalBytes = _files
            .where((file) => _selectedFiles.contains(file.id))
            .fold(0, (prev, curr) => prev + curr.size);
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
    final receiveSession =
        ref.read(serverProvider.select((state) => state?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession &&
        (status == SessionStatus.sending ||
            status == SessionStatus.finishedWithErrors);
    final result =
        status == null || keepSession || await _askCancelConfirmation(status);

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
    final receiveSession =
        ref.read(serverProvider.select((state) => state?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession &&
        (status == SessionStatus.sending ||
            status == SessionStatus.finishedWithErrors);
    final result =
        status == null || keepSession || await _askCancelConfirmation(status);
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
      true => (await context.pushBottomSheet(
            () => const CancelSessionDialog(),
          )) ==
          true,
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
    Translations.of(context);
    final progressNotifier = ref.watch(progressProvider);
    final currBytes = _files.fold<int>(
        0,
        (prev, curr) =>
            prev +
            ((progressNotifier.getProgress(
                        sessionId: widget.sessionId, fileId: curr.id) *
                    curr.size)
                .round()));

    final receiveSession =
        ref.watch(serverProvider.select((state) => state?.session));
    final sendSession = ref.watch(sendProvider)[widget.sessionId];
    final status = receiveSession?.status ?? sendSession?.status;

    if (status == SessionStatus.sending) {
      TaskbarHelper.setProgressBar(currBytes, _totalBytes);
    } else if (status != _lastStatus) {
      _lastStatus = status;
      TaskbarHelper.visualizeStatus(status);
    }

    if (status == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: const SizedBox(),
      );
    }

    final title =
        receiveSession != null ? t.progressPage.titleReceiving : t.progressPage.titleSending;
    final startTime = receiveSession?.startTime ?? sendSession?.startTime;
    final endTime = receiveSession?.endTime ?? sendSession?.endTime;

    final int? speedInBytes;
    if (startTime != null && currBytes >= 500 * 1024) {
      speedInBytes = getFileSpeed(
        start: startTime,
        end: endTime ?? DateTime.now().millisecondsSinceEpoch,
        bytes: currBytes,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRemainingTimeUpdate >= 1000) {
        _remainingTime = getRemainingTime(
          bytesPerSeconds: speedInBytes,
          remainingBytes: _totalBytes - currBytes,
        );
        _lastRemainingTimeUpdate = now;
      }
    } else {
      speedInBytes = null;
    }

    final fileStatusMap = receiveSession?.files.map((key, file) => MapEntry(key, file.status)) ??
        sendSession!.files.map((key, file) => MapEntry(key, file.status));
    final finishedCount =
        fileStatusMap.values.where((entry) => entry == FileStatus.finished).length;
    final failedCount =
        fileStatusMap.values.where((entry) => entry == FileStatus.failed).length;
    final skippedCount =
        fileStatusMap.values.where((entry) => entry == FileStatus.skipped).length;
    final selectedCount =
        _selectedFiles.isEmpty ? _files.length : _selectedFiles.length;
    final totalBytes =
        _totalBytes == double.maxFinite.toInt() ? null : _totalBytes;
    final progressValue = totalBytes == null
        ? null
        : totalBytes == 0
            ? 0.0
            : (currBytes / totalBytes).clamp(0.0, 1.0);

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        _exit(closeSession: widget.closeSessionOnClose);
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(title),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (receiveSession != null && checkPlatformWithFileSystem())
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.progressPage.destination.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        receiveSession.saveToGallery
                            ? t.progressPage.destination.savingToGallery
                            : t.progressPage.destination.savingToFolder,
                      ),
                      const SizedBox(height: 8),
                      Text(receiveSession.destinationDirectory),
                      if (!checkPlatform([TargetPlatform.iOS]))
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              await openFolder(
                                  folderPath: receiveSession.destinationDirectory);
                            },
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(t.receiveHistoryPage.openFolder),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (sendSession?.errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.error.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.progressPage.errorCard.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(sendSession!.errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.progressPage.overview.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(status.getLabel(remainingTime: _remainingTime ?? '-')),
                    const SizedBox(height: 8),
                    if (progressValue == null)
                      const CustomProgressBar(progress: null, borderRadius: 6)
                    else
                      CustomProgressBar(
                        progress: progressValue,
                        borderRadius: 6,
                      ),
                    const SizedBox(height: 10),
                    Text(t.progressPage.overview.completed),
                    Text('$finishedCount / $selectedCount'),
                    const SizedBox(height: 6),
                    Text(t.progressPage.overview.transferred),
                    Text(
                        '${currBytes.asReadableFileSize} / ${totalBytes == null ? '-' : totalBytes.asReadableFileSize}'),
                    if (speedInBytes != null) ...[
                      const SizedBox(height: 6),
                      Text(t.progressPage.overview.speed),
                      Text('${speedInBytes.asReadableFileSize}/s'),
                    ],
                    if (failedCount > 0) ...[
                      const SizedBox(height: 6),
                      Text(t.progressPage.overview.errors),
                      Text('$failedCount'),
                    ],
                    if (_advanced) ...[
                      const SizedBox(height: 10),
                      Text(t.progressPage.total.count(
                          curr: finishedCount, n: selectedCount)),
                      Text(t.progressPage.total.size(
                          curr: currBytes.asReadableFileSize,
                          n: totalBytes == null
                              ? '-'
                              : totalBytes.asReadableFileSize)),
                      if (speedInBytes != null)
                        Text(t.progressPage.total.speed(
                            speed: speedInBytes.asReadableFileSize)),
                      if (skippedCount > 0)
                        Text('${t.general.skipped}: $skippedCount'),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _advanced = !_advanced;
                            });
                          },
                          icon: Icon(_advanced
                              ? Icons.visibility_off_rounded
                              : Icons.tune_rounded),
                          label: Text(
                              _advanced ? t.general.hide : t.general.advanced),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              _exitWithStopBgTask(closeSession: true),
                          icon: Icon(status == SessionStatus.sending
                              ? Icons.close_rounded
                              : Icons.check_circle_rounded),
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
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.general.files,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_files.isEmpty)
                      Text(t.progressPage.filesCard.empty)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _files.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          final fileName = receiveSession
                                  ?.files[file.id]
                                  ?.desiredName ??
                              file.fileName;
                          final fileStatus = fileStatusMap[file.id]!;
                          final savedToGallery =
                              receiveSession?.files[file.id]?.savedToGallery ??
                                  false;

                          final String? filePath;
                          if (receiveSession != null &&
                              fileStatus == FileStatus.finished &&
                              !savedToGallery) {
                            filePath = receiveSession.files[file.id]!.path;
                          } else if (sendSession != null) {
                            filePath = sendSession.files[file.id]!.path;
                          } else {
                            filePath = null;
                          }

                          final String? errorMessage;
                          if (receiveSession != null) {
                            errorMessage =
                                receiveSession.files[file.id]!.errorMessage;
                          } else if (sendSession != null) {
                            errorMessage =
                                sendSession.files[file.id]!.errorMessage;
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

                          return LegacyTransferFileCard(
                            file: file,
                            fileName: fileName,
                            fileStatus: fileStatus,
                            savedToGallery: savedToGallery,
                            filePath: filePath,
                            thumbnail: thumbnail,
                            asset: asset,
                            progress: progressNotifier.getProgress(
                              sessionId: widget.sessionId,
                              fileId: file.id,
                            ),
                            errorMessage: errorMessage,
                            onTap: filePath != null && receiveSession != null
                                ? () async {
                                    await openFile(
                                        context, file.fileType, filePath!);
                                  }
                                : null,
                            onRetry: sendSession != null &&
                                    fileStatus == FileStatus.failed
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegacyTransferFileCard extends StatelessWidget {
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

  const LegacyTransferFileCard({
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = savedToGallery
        ? t.progressPage.savedToGallery
        : fileStatus == FileStatus.sending
            ? progress == null
                ? t.progressPage.fileCard.preparing
                : '${((progress ?? 0) * 100).round()}%'
            : fileStatus.label;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: SmartFileThumbnail(
          bytes: thumbnail,
          asset: asset,
          path: filePath,
          fileType: file.fileType,
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(file.size.asReadableFileSize),
            const SizedBox(height: 6),
            if (fileStatus == FileStatus.sending)
              CustomProgressBar(
                progress: progress,
                borderRadius: 6,
              ),
            const SizedBox(height: 6),
            Text(statusLabel),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
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
}
