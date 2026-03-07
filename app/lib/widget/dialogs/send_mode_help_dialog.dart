import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:routerino/routerino.dart';

class SendModeHelpDialog extends StatelessWidget {
  const SendModeHelpDialog();

  @override
  Widget build(BuildContext context) {
    return ModernDialogScaffold(
      title: t.dialogs.sendModeHelp.title,
      subtitle: t.sendTab.sendMode,
      onClose: () => context.pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SendModeItem(
            mode: t.sendTab.sendModes.single,
            explanation: t.dialogs.sendModeHelp.single,
          ),
          const SizedBox(height: 12),
          _SendModeItem(
            mode: t.sendTab.sendModes.multiple,
            explanation: t.dialogs.sendModeHelp.multiple,
          ),
          const SizedBox(height: 12),
          _SendModeItem(
            mode: t.sendTab.sendModes.link,
            explanation: t.dialogs.sendModeHelp.link,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.close),
        ),
      ],
    );
  }
}

class _SendModeItem extends StatelessWidget {
  final String mode;
  final String explanation;
  const _SendModeItem({
    required this.mode,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      applyBlur: false,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(explanation),
        ],
      ),
    );
  }
}
