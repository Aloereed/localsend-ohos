import 'dart:convert';

import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/message_input_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SelectedFilesPage extends StatelessWidget {
  const SelectedFilesPage();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final selectedFiles = ref.watch(selectedSendingFilesProvider);
    final totalSize = selectedFiles.fold<int>(0, (prev, curr) => prev + curr.size);
    final sectionSpacing = context.adaptiveSectionSpacing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ResponsiveListView(
            maxWidth: 860,
            padding: EdgeInsets.fromLTRB(
              context.adaptiveHorizontalPadding,
              context.adaptiveTopPadding,
              context.adaptiveHorizontalPadding,
              context.adaptiveBottomPadding,
            ),
            children: [
              ModernPageHeader(
                title: t.sendTab.selection.title,
                subtitle: selectedFiles.isEmpty
                    ? t.sendTab.selection.files(files: 0)
                    : t.sendTab.selection.size(size: totalSize.asReadableFileSize),
                trailing: IconButton(
                  tooltip: t.general.close,
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                chips: [
                  StatusChip(
                    label: t.sendTab.selection.files(files: selectedFiles.length),
                    icon: Icons.collections_bookmark_rounded,
                    emphasized: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  StatusChip(
                    label: totalSize.asReadableFileSize,
                    icon: Icons.data_usage_rounded,
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),
              GlassSectionCard(
                title: t.sendTab.selection.title,
                subtitle: selectedFiles.isEmpty
                    ? t.sendTab.help
                    : t.sendTab.selection.size(size: totalSize.asReadableFileSize),
                strong: true,
                trailing: selectedFiles.isEmpty
                    ? null
                    : FilledButton.icon(
                        onPressed: () {
                          ref
                              .redux(selectedSendingFilesProvider)
                              .dispatch(ClearSelectionAction());
                          context.popUntilRoot();
                        },
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text(t.selectedFilesPage.deleteAll),
                      ),
                child: selectedFiles.isEmpty
                    ? const SizedBox(
                        height: 140,
                        child: Center(
                          child: Icon(Icons.inbox_rounded, size: 56),
                        ),
                      )
                    : Column(
                        children: [
                          for (var index = 0; index < selectedFiles.length; index++) ...[
                            _SelectedFileCard(
                              file: selectedFiles[index],
                              index: index,
                            ),
                            if (index != selectedFiles.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  final CrossFile file;
  final int index;

  const _SelectedFileCard({
    required this.file,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final compact = context.isNarrowWidth;

    final String? message;
    if (file.fileType == FileType.text && file.bytes != null) {
      message = utf8.decode(file.bytes!);
    } else {
      message = null;
    }

    final title = message != null
        ? t.selectedFilesPage.messagePreview(
            message: message.replaceAll('\n', ' '),
          )
        : file.name;

    final actionButtons = Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        if (file.fileType == FileType.text && file.bytes != null)
          IconButton(
            tooltip: t.general.edit,
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => MessageInputDialog(initialText: message),
              );
              if (result != null) {
                ref.redux(selectedSendingFilesProvider).dispatch(
                      UpdateMessageAction(message: result, index: index),
                    );
              }
            },
            icon: const Icon(Icons.edit_rounded),
          ),
        IconButton(
          tooltip: t.general.delete,
          onPressed: () {
            final currCount = ref.read(selectedSendingFilesProvider).length;
            ref.redux(selectedSendingFilesProvider).dispatch(
                  RemoveSelectedFileAction(index),
                );
            if (currCount == 1) {
              context.popUntilRoot();
            }
          },
          icon: const Icon(Icons.delete_rounded),
        ),
      ],
    );

    return GlassSurface(
      applyBlur: false,
      onTap: file.path != null
          ? () async => openFile(context, file.fileType, file.path!)
          : null,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartFileThumbnail.fromCrossFile(file),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            file.size.asReadableFileSize,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.visuals.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actionButtons),
              ],
            )
          : Row(
              children: [
                SmartFileThumbnail.fromCrossFile(file),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        file.size.asReadableFileSize,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.visuals.mutedForeground,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                actionButtons,
              ],
            ),
    );
  }
}
