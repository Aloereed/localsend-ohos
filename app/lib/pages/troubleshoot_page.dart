import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/cmd_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/not_available_on_platform_dialog.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
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
                title: t.troubleshootPage.title,
                subtitle: t.troubleshootPage.subTitle,
                trailing: IconButton(
                  tooltip: t.general.close,
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                chips: [
                  StatusChip(
                    label: '${t.settingsTab.network.port}: ${settings.port}',
                    icon: Icons.lan_rounded,
                    emphasized: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),
              _TroubleshootItem(
                symptomText: t.troubleshootPage.firewall.symptom,
                solutionText: t.troubleshootPage.firewall.solution(port: settings.port),
                primaryButton: _FixButton(
                  label: t.troubleshootPage.fixButton,
                  onTapMap: {
                    TargetPlatform.windows: _CommandFixAction(
                      adminPrivileges: true,
                      commands: [
                        'netsh advfirewall firewall add rule name="AloeChatAI" dir=in action=allow protocol=TCP localport=${settings.port}',
                        'netsh advfirewall firewall add rule name="AloeChatAI" dir=in action=allow protocol=UDP localport=${settings.port}',
                      ],
                    ),
                  },
                ),
                secondaryButton: _FixButton(
                  label: t.troubleshootPage.firewall.openFirewall,
                  onTapMap: {
                    TargetPlatform.windows: _CommandFixAction(
                      adminPrivileges: false,
                      commands: ['wf'],
                    ),
                  },
                  tonal: true,
                ),
              ),
              SizedBox(height: sectionSpacing),
              _TroubleshootItem(
                symptomText: t.troubleshootPage.noDiscovery.symptom,
                solutionText: t.troubleshootPage.noDiscovery.solution,
              ),
              SizedBox(height: sectionSpacing),
              _TroubleshootItem(
                symptomText: t.troubleshootPage.noConnection.symptom,
                solutionText: t.troubleshootPage.noConnection.solution,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TroubleshootItem extends StatefulWidget {
  final String symptomText;
  final String solutionText;
  final _FixButton? primaryButton;
  final _FixButton? secondaryButton;

  const _TroubleshootItem({
    required this.symptomText,
    required this.solutionText,
    this.primaryButton,
    this.secondaryButton,
  });

  @override
  State<_TroubleshootItem> createState() => _TroubleshootItemState();
}

class _TroubleshootItemState extends State<_TroubleshootItem> {
  bool _showCommands = false;

  @override
  Widget build(BuildContext context) {
    final commands = widget.primaryButton?.onTap?.commands;

    return GlassSectionCard(
      title: widget.symptomText,
      subtitle: t.troubleshootPage.solution,
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.solutionText),
          if (widget.primaryButton != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                widget.primaryButton!,
                if (widget.secondaryButton != null) widget.secondaryButton!,
                if (commands != null)
                  IconButton(
                    tooltip: t.troubleshootPage.commands,
                    onPressed: () {
                      setState(() => _showCommands = !_showCommands);
                    },
                    icon: Icon(
                      _showCommands ? Icons.code_off_rounded : Icons.code_rounded,
                    ),
                  ),
              ],
            ),
            if (commands != null)
              AnimatedCrossFade(
                crossFadeState: _showCommands
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: GlassSurface(
                    applyBlur: false,
                    borderRadius: BorderRadius.circular(18),
                    padding: const EdgeInsets.all(14),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0; index < commands.length; index++) ...[
                            Text(
                              commands[index],
                              style: const TextStyle(fontFamily: 'RobotoMono'),
                            ),
                            if (index != commands.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final String label;
  final Map<TargetPlatform, _FixAction> onTapMap;
  final _FixAction? onTap;
  final bool tonal;

  _FixButton({
    required this.label,
    required this.onTapMap,
    this.tonal = false,
  }) : onTap = onTapMap[defaultTargetPlatform];

  @override
  Widget build(BuildContext context) {
    final callback = () async {
      if (onTap != null) {
        onTap!.runFix();
      } else {
        await showDialog(
          context: context,
          builder: (_) => NotAvailableOnPlatformDialog(
            platforms: onTapMap.keys.toList(),
          ),
        );
      }
    };

    if (tonal) {
      return FilledButton.tonal(
        onPressed: callback,
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: callback,
      child: Text(label),
    );
  }
}

abstract class _FixAction {
  void runFix();

  List<String>? get commands;
}

class _CommandFixAction extends _FixAction {
  final bool adminPrivileges;

  @override
  final List<String> commands;

  _CommandFixAction({
    required this.adminPrivileges,
    required this.commands,
  });

  @override
  void runFix() async {
    if (adminPrivileges) {
      if (checkPlatform([TargetPlatform.windows])) {
        await runWindowsCommandAsAdmin(commands);
      } else {
        throw t.troubleshootPage.adminOnlyWindows;
      }
    } else {
      for (final c in commands) {
        await Process.run(c, [], runInShell: true);
      }
    }
  }
}
