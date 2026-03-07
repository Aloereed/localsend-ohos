import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/provider/message_history_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';

enum _EntryOption { open, showInFolder, info, delete, deleteFile }

Future<void> _deleteFileToast(String filePath) async {
  final file = File(filePath);
  try {
    if (await file.exists()) {
      await file.delete();
      Fluttertoast.showToast(msg: 'Deleted file: $filePath');
    } else {
      Fluttertoast.showToast(msg: 'File not found: $filePath');
    }
  } catch (e) {
    Fluttertoast.showToast(msg: 'Delete failed: $e');
  }
}

class ReceiveHistoryPage extends StatelessWidget {
  const ReceiveHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sourceEntries = context.watch(messageHistoryProvider);
    final entries = buildCompatibilityHistory(sourceEntries);
    final gap = context.adaptiveSectionSpacing;

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
                subtitle: entries.isEmpty ? t.receiveHistoryPage.empty : '${entries.length} entries',
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              SizedBox(height: gap),
              GlassSectionCard(
                title: t.receiveHistoryPage.deleteHistory,
                subtitle: entries.isEmpty ? t.receiveHistoryPage.empty : 'Remove received history items from message log.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: entries.isEmpty
                        ? null
                        : () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (_) => const HistoryClearDialog(),
                            );
                            if (context.mounted && result == true) {
                              await context.redux(messageHistoryProvider).dispatchAsync(
                                    ClearReceiveCompatibilityHistoryAction(),
                                  );
                            }
                          },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: Text(t.receiveHistoryPage.deleteHistory),
                  ),
                ),
              ),
              SizedBox(height: gap),
              if (entries.isEmpty)
                GlassSectionCard(
                  title: t.receiveHistoryPage.empty,
                  subtitle: 'Received files and messages will appear here.',
                  child: const SizedBox(
                    height: 140,
                    child: Center(child: Icon(Icons.inbox_rounded, size: 56)),
                  ),
                )
              else
                ...entries.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryEntryCard(item: item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final MessageHistoryCompatibilityEntry item;

  const _HistoryEntryCard({required this.item});

  Future<void> _openFile(BuildContext context) async {
    final entry = item.entry;
    if (entry.path != null) {
      await openFile(
        context,
        entry.fileType,
        entry.path!,
        onDeleteTap: () => context.redux(messageHistoryProvider).dispatchAsync(
              RemoveCompatibilityMessageHistoryEntryAction(
                sourceEntryId: item.sourceEntryId,
                sourceItemId: item.sourceItemId,
              ),
            ),
      );
    }
  }

  Future<void> _openConversation(BuildContext context) async {
    context.ref.notifier(activeMessageSelectionProvider).setState(
          (_) => MessageConversationSelection(
            conversationId: item.conversationId,
            peer: item.peer,
          ),
        );
    context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.message));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final meta = '${entry.timestampString} | ${entry.fileSize.asReadableFileSize} | ${entry.senderAlias}';

    return GlassSurface(
      onTap: () => _openConversation(context),
      padding: const EdgeInsets.all(18),
      child: Row(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.visuals.mutedForeground),
                ),
              ],
            ),
          ),
          PopupMenuButton<_EntryOption>(
            onSelected: (choice) async {
              switch (choice) {
                case _EntryOption.open:
                  await _openFile(context);
                  break;
                case _EntryOption.showInFolder:
                  if (entry.path != null) {
                    await openFolder(folderPath: File(entry.path!).parent.path, fileName: path.basename(entry.path!));
                  }
                  break;
                case _EntryOption.info:
                  await showDialog(context: context, builder: (_) => FileInfoDialog(entry: entry));
                  break;
                case _EntryOption.delete:
                  await context.redux(messageHistoryProvider).dispatchAsync(
                        RemoveCompatibilityMessageHistoryEntryAction(
                          sourceEntryId: item.sourceEntryId,
                          sourceItemId: item.sourceItemId,
                        ),
                      );
                  break;
                case _EntryOption.deleteFile:
                  if (entry.path != null) await _deleteFileToast(entry.path!);
                  await context.redux(messageHistoryProvider).dispatchAsync(
                        RemoveCompatibilityMessageHistoryEntryAction(
                          sourceEntryId: item.sourceEntryId,
                          sourceItemId: item.sourceItemId,
                        ),
                      );
                  break;
              }
            },
            itemBuilder: (_) => [
              if (entry.path != null) PopupMenuItem(value: _EntryOption.open, child: Text(t.receiveHistoryPage.entryActions.open)),
              if (entry.path != null) PopupMenuItem(value: _EntryOption.showInFolder, child: Text(t.receiveHistoryPage.entryActions.showInFolder)),
              PopupMenuItem(value: _EntryOption.info, child: Text(t.receiveHistoryPage.entryActions.info)),
              PopupMenuItem(value: _EntryOption.delete, child: Text(t.receiveHistoryPage.entryActions.deleteFromHistory)),
              if (entry.path != null) const PopupMenuItem(value: _EntryOption.deleteFile, child: Text('Delete history + file')),
            ],
          ),
        ],
      ),
    );
  }
}
