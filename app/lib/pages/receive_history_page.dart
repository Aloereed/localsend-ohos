import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/pages/receive_page_controller.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/theme.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:routerino/routerino.dart';

enum _EntryOption {
  open,
  showInFolder,
  info,
  delete,
  deleteFile;

  String get label {
    return switch (this) {
      _EntryOption.open => t.receiveHistoryPage.entryActions.open,
      _EntryOption.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
      _EntryOption.info => t.receiveHistoryPage.entryActions.info,
      _EntryOption.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
      _EntryOption.deleteFile=>t.receiveHistoryPage.entryActions.deleteFromHistory + "并删除缓存文件",
    };
  }
}

const _optionsAll = _EntryOption.values;
final _optionsWithoutOpen = [
  _EntryOption.info,
  _EntryOption.delete,
  _EntryOption.deleteFile
];
void deleteFile(String filePath) async {
  final file = File(filePath);

  try {
    if (await file.exists()) {
      await file.delete();
      Fluttertoast.showToast(
        msg: "文件已删除: $filePath",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      Fluttertoast.showToast(
        msg: "文件不存在: $filePath",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  } catch (e) {
    Fluttertoast.showToast(
      msg: "删除失败: $e",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}

class ReceiveHistoryPage extends StatelessWidget {
  const ReceiveHistoryPage({super.key});

  Future<void> _openFile(
    BuildContext context,
    ReceiveHistoryEntry entry,
    Dispatcher<ReceiveHistoryService, List<ReceiveHistoryEntry>> dispatcher,
  ) async {
    if (entry.path != null) {
      await openFile(
        context,
        entry.fileType,
        entry.path!,
        onDeleteTap: () =>
            dispatcher.dispatchAsync(RemoveHistoryEntryAction(entry.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(receiveHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.receiveHistoryPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 15),
                Visibility(
                    visible: !checkPlatform([TargetPlatform.iOS]),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainerIfDark,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainerIfDark,
                      ),
                      onPressed: checkPlatform([TargetPlatform.iOS])
                          ? null
                          : () async {
                              // ignore: use_build_context_synchronously
                              final destination =
                                  context.read(settingsProvider).destination ??
                                      await getDefaultDestinationDirectory();

                              if (destination ==
                                  "/storage/Users/currentUser/Download/com.aloereed.aloechatai") {
                                 Fluttertoast.showToast(
                                  msg: "请自行打开“/下载/AloeChat.AI”。",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  timeInSecForIosWeb: 1,
                                  backgroundColor: Colors.green,
                                  textColor: Colors.white,
                                  fontSize: 16.0,);
                                // 延时2秒
                                await Future.delayed(Duration(seconds: 2));
                                // 创建实例
                                final _platform = const MethodChannel(
                                    'samples.flutter.dev/downloadplugin');
                                // 调用方法 getBatteryLevel
                                final result =
                                    await _platform.invokeMethod<String>(
                                        'openFileManager');
                              }
                              await openFolder(destination);
                            },
                      icon: const Icon(Icons.folder),
                      label: Text(t.receiveHistoryPage.openFolder),
                    )),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainerIfDark,
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainerIfDark,
                  ),
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          final result = await showDialog(
                            context: context,
                            builder: (_) => const HistoryClearDialog(),
                          );

                          if (context.mounted && result == true) {
                            await context
                                .redux(receiveHistoryProvider)
                                .dispatchAsync(RemoveAllHistoryEntriesAction());
                          }
                        },
                  icon: const Icon(Icons.delete),
                  label: Text(t.receiveHistoryPage.deleteHistory),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                  child: Text(t.receiveHistoryPage.empty,
                      style: Theme.of(context).textTheme.headlineMedium)),
            )
          else
            ...entries.map((entry) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: InkWell(
                  splashColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onTap: entry.path != null || entry.isMessage
                      ? () async {
                          if (entry.isMessage) {
                            context.redux(receivePageControllerProvider).dispatch(InitReceivePageFromHistoryMessageAction(entry: entry));
                            // ignore: unawaited_futures
                            context.push(() => const ReceivePage());
                            return;
                          }

                          await _openFile(context, entry, context.redux(receiveHistoryProvider));
                        }
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilePathThumbnail(
                        path: entry.path,
                        fileType: entry.fileType,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(
                              entry.fileName,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                            Text(
                              '${entry.timestampString} - ${entry.fileSize.asReadableFileSize} - ${entry.senderAlias}',
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<_EntryOption>(
                        onSelected: (_EntryOption item) async {
                          switch (item) {
                            case _EntryOption.open:
                              await _openFile(context, entry,
                                  context.redux(receiveHistoryProvider));
                              break;
                            case _EntryOption.showInFolder:
                              if (entry.path != null) {
                                await openFolder(File(entry.path!).parent.path);
                              }
                              break;
                            case _EntryOption.info:
                              // ignore: use_build_context_synchronously
                              await showDialog(
                                context: context,
                                builder: (_) => FileInfoDialog(entry: entry),
                              );
                              break;
                            case _EntryOption.delete:
                              // ignore: use_build_context_synchronously
                              await context
                                  .redux(receiveHistoryProvider)
                                  .dispatchAsync(
                                      RemoveHistoryEntryAction(entry.id));
                              break;
                            case _EntryOption.deleteFile:
                              // ignore: use_build_context_synchronously
                              deleteFile(entry.path!);
                              await context
                                  .redux(receiveHistoryProvider)
                                  .dispatchAsync(
                                      RemoveHistoryEntryAction(entry.id));
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return (entry.path != null
                                  ? _optionsAll
                                  : _optionsWithoutOpen)
                              .map((e) {
                            return PopupMenuItem<_EntryOption>(
                              value: e,
                              child: Text(e.label),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
