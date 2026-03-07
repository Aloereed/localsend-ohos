import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/pages/receive_page_controller.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
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
      _EntryOption.deleteFile => 'Delete history + file',
    };
  }
}

const _optionsAll = _EntryOption.values;
final _optionsWithoutOpen = [
  _EntryOption.info,
  _EntryOption.delete,
  _EntryOption.deleteFile,
];

Future<void> _deleteFileToast(String filePath) async {
  final file = File(filePath);

  try {
    if (await file.exists()) {
      await file.delete();
      Fluttertoast.showToast(
        msg: 'Deleted file: $filePath',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16,
      );
    } else {
      Fluttertoast.showToast(
        msg: 'File not found: $filePath',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16,
      );
    }
  } catch (e) {
    Fluttertoast.showToast(
      msg: 'Delete failed: $e',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 16,
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
        onDeleteTap: () => dispatcher.dispatchAsync(RemoveHistoryEntryAction(entry.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(receiveHistoryProvider);
    final visuals = context.visuals;
    final sectionSpacing = context.adaptiveSectionSpacing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
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
                title: t.receiveHistoryPage.title,
                subtitle: entries.isEmpty
                    ? t.receiveHistoryPage.empty
                    : '${entries.length} item(s)',
                chips: [
                  StatusChip(
                    label: entries.isEmpty ? t.receiveHistoryPage.empty : '${entries.length} entries',
                    icon: Icons.history_rounded,
                    emphasized: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
                trailing: IconButton(
                  tooltip: t.general.close,
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              SizedBox(height: sectionSpacing),
              GlassSectionCard(
                title: t.receiveHistoryPage.title,
                subtitle: t.receiveHistoryPage.openFolder,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final actionTiles = <Widget>[
                      if (!checkPlatform([TargetPlatform.iOS]))
                        ModernActionTile(
                          icon: Icons.folder_open_rounded,
                          title: t.receiveHistoryPage.openFolder,
                          subtitle: 'Open the receive destination',
                          onTap: () async {
                            final destination = context.read(settingsProvider).destination ??
                                await getDefaultDestinationDirectory();
                            await openFolder(folderPath: destination);
                          },
                        ),
                      ModernActionTile(
                        icon: Icons.delete_sweep_rounded,
                        title: t.receiveHistoryPage.deleteHistory,
                        subtitle: entries.isEmpty ? t.receiveHistoryPage.empty : 'Remove all history entries',
                        highlighted: entries.isNotEmpty,
                        onTap: entries.isEmpty
                            ? null
                            : () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => const HistoryClearDialog(),
                                );

                                if (context.mounted && result == true) {
                                  await context
                                      .redux(receiveHistoryProvider)
                                      .dispatchAsync(RemoveAllHistoryEntriesAction());
                                }
                              },
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (var index = 0; index < actionTiles.length; index++) ...[
                            SizedBox(width: double.infinity, child: actionTiles[index]),
                            if (index != actionTiles.length - 1) const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: actionTiles
                          .map((tile) => SizedBox(width: 240, child: tile))
                          .toList(),
                    );
                  },
                ),
              ),
              SizedBox(height: sectionSpacing),
              if (entries.isEmpty)
                GlassSectionCard(
                  title: t.receiveHistoryPage.empty,
                  subtitle: 'Received files and messages will appear here.',
                  child: const SizedBox(
                    height: 140,
                    child: Center(
                      child: Icon(Icons.inbox_rounded, size: 56),
                    ),
                  ),
                )
              else
                ...entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryEntryCard(
                      entry: entry,
                      onOpen: () async {
                        if (entry.isMessage) {
                          context
                              .redux(receivePageControllerProvider)
                              .dispatch(InitReceivePageFromHistoryMessageAction(entry: entry));
                          await context.push(() => const ReceivePage());
                          return;
                        }

                        await _openFile(context, entry, context.redux(receiveHistoryProvider));
                      },
                      onSelected: (item) async {
                        switch (item) {
                          case _EntryOption.open:
                            await _openFile(context, entry, context.redux(receiveHistoryProvider));
                            break;
                          case _EntryOption.showInFolder:
                            if (entry.path != null) {
                              await openFolder(
                                folderPath: File(entry.path!).parent.path,
                                fileName: path.basename(entry.path!),
                              );
                            }
                            break;
                          case _EntryOption.info:
                            await showDialog(
                              context: context,
                              builder: (_) => FileInfoDialog(entry: entry),
                            );
                            break;
                          case _EntryOption.delete:
                            await context
                                .redux(receiveHistoryProvider)
                                .dispatchAsync(RemoveHistoryEntryAction(entry.id));
                            break;
                          case _EntryOption.deleteFile:
                            if (entry.path != null) {
                              await _deleteFileToast(entry.path!);
                            }
                            await context
                                .redux(receiveHistoryProvider)
                                .dispatchAsync(RemoveHistoryEntryAction(entry.id));
                            break;
                        }
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final ReceiveHistoryEntry entry;
  final Future<void> Function() onOpen;
  final Future<void> Function(_EntryOption item) onSelected;

  const _HistoryEntryCard({
    required this.entry,
    required this.onOpen,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final meta = '${entry.timestampString} | ${entry.fileSize.asReadableFileSize} | ${entry.senderAlias}';

    final menuButton = PopupMenuButton<_EntryOption>(
      onSelected: (item) async => onSelected(item),
      itemBuilder: (context) {
        return (entry.path != null ? _optionsAll : _optionsWithoutOpen)
            .map(
              (option) => PopupMenuItem<_EntryOption>(
                value: option,
                child: Text(option.label),
              ),
            )
            .toList();
      },
    );

    return GlassSurface(
      onTap: entry.path != null || entry.isMessage ? () => onOpen() : null,
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilePathThumbnail(path: entry.path, fileType: entry.fileType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.fileName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: context.visuals.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: menuButton),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilePathThumbnail(path: entry.path, fileType: entry.fileType),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.fileName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: context.visuals.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                menuButton,
              ],
            ),
    );
  }
}
