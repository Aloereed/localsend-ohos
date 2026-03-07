import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class AddFileDialog extends StatelessWidget {
  final List<FilePickerOption> options;

  const AddFileDialog({required this.options});

  static Future<void> open({required BuildContext context, required List<FilePickerOption> options}) async {
    await showDialog(
      context: context,
      builder: (_) => ModernDialogScaffold(
        title: t.dialogs.addFile.title,
        subtitle: t.dialogs.addFile.content,
        onClose: () => context.pop(),
        child: AddFileDialog(options: options),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(t.general.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...options.map((option) {
          return SizedBox(
            width: 240,
            child: ModernActionTile(
              icon: option.icon,
              title: option.label,
              subtitle: t.sendTab.selection.title,
              highlighted: option == options.first,
            onTap: () async {
              context.popUntilRoot();
              await context.global.dispatchAsync(PickFileAction(option: option, context: context));
            },
            ),
          );
        }),
      ],
    );
  }
}
