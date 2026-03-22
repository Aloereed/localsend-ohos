import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _QuickSaveMode {
  off,
  favorites,
  on,
}

class ReceiveTab extends StatelessWidget {
  const ReceiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(receiveTabVmProvider);
    final visuals = context.visuals;
    final sectionSpacing = context.adaptiveSectionSpacing;
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final isOnline = vm.serverState != null;
    final networkSummary = isOnline
        ? vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' | ')
        : t.general.offline;

    return ResponsiveListView(
      maxWidth: 860,
      padding: EdgeInsets.fromLTRB(
        context.adaptiveHorizontalPadding,
        context.adaptiveTopPadding,
        context.adaptiveHorizontalPadding,
        context.adaptiveBottomPadding,
      ),
      extraBottomPadding: context.adaptiveTabDockPadding,
      children: [
        ModernPageHeader(
          title: vm.serverState?.alias ?? vm.aliasSettings,
          subtitle: isOnline
              ? networkSummary
              : '${t.receiveTab.title} | ${t.general.offline}',
          leading: _HeroLogo(isOnline: isOnline),
          trailing: _HeaderActions(vm: vm),
          chips: [
            StatusChip(
              label: isOnline ? t.receiveTab.title : t.general.offline,
              icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: isOnline ? Theme.of(context).colorScheme.primary : null,
              emphasized: isOnline,
            ),
            StatusChip(
              label: vm.quickSaveSettings
                  ? t.receiveTab.quickSave.on
                  : vm.quickSaveFromFavoritesSettings
                      ? t.receiveTab.quickSave.favorites
                      : t.receiveTab.quickSave.off,
              icon: Icons.download_done_rounded,
            ),
            if (vm.localIps.isNotEmpty)
              StatusChip(
                label: vm.localIps.length == 1
                    ? vm.localIps.first
                    : '${vm.localIps.length} IPs',
                icon: Icons.lan_rounded,
              ),
          ],
        ),
        SizedBox(height: sectionSpacing),
        GlassSectionCard(
          title: t.general.quickSave,
          subtitle: networkSummary,
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_QuickSaveMode>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(
                          horizontal: compactPhone ? 10 : phone ? 12 : 14,
                          vertical: compactPhone ? 10 : phone ? 11 : 12,
                        ),
                      ),
                    ),
                    multiSelectionEnabled: false,
                    emptySelectionAllowed: false,
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) async {
                      if (selection.contains(_QuickSaveMode.off)) {
                        await vm.onSetQuickSave(context, false);
                        if (context.mounted) {
                          await vm.onSetQuickSaveFromFavorites(context, false);
                        }
                      } else if (selection.contains(_QuickSaveMode.favorites)) {
                        await vm.onSetQuickSave(context, false);
                        if (context.mounted) {
                          await vm.onSetQuickSaveFromFavorites(context, true);
                        }
                      } else if (selection.contains(_QuickSaveMode.on)) {
                        await vm.onSetQuickSaveFromFavorites(context, false);
                        if (context.mounted) {
                          await vm.onSetQuickSave(context, true);
                        }
                      }
                    },
                    selected: {
                      if (!vm.quickSaveSettings && !vm.quickSaveFromFavoritesSettings)
                        _QuickSaveMode.off,
                      if (vm.quickSaveFromFavoritesSettings)
                        _QuickSaveMode.favorites,
                      if (vm.quickSaveSettings) _QuickSaveMode.on,
                    },
                    segments: [
                      ButtonSegment(
                        value: _QuickSaveMode.off,
                        label: Text(t.receiveTab.quickSave.off),
                      ),
                      ButtonSegment(
                        value: _QuickSaveMode.favorites,
                        label: Text(t.receiveTab.quickSave.favorites),
                      ),
                      ButtonSegment(
                        value: _QuickSaveMode.on,
                        label: Text(t.receiveTab.quickSave.on),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: phone ? 12 : 14),
              Text(
                t.general.quickSave,
                style: (phone
                        ? Theme.of(context).textTheme.bodySmall
                        : Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(
                      color: visuals.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(height: sectionSpacing),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: vm.showAdvanced
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: GlassSectionCard(
            title: t.receiveTab.infoBox.alias,
            subtitle: t.receiveTab.infoBox.ip,
            child: Column(
              children: [
                _InfoRow(
                  label: t.receiveTab.infoBox.alias,
                  value: vm.serverState?.alias ?? '-',
                ),
                _InfoRow(
                  label: t.receiveTab.infoBox.ip,
                  value:
                      vm.localIps.isEmpty ? t.general.unknown : vm.localIps.join('\n'),
                ),
                _InfoRow(
                  label: t.receiveTab.infoBox.port,
                  value: vm.serverState?.port.toString() ?? '-',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final ReceiveTabVm vm;

  const _HeaderActions({required this.vm});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    return Wrap(
      spacing: phone ? 8 : 10,
      runSpacing: phone ? 8 : 10,
      alignment: WrapAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: vm.showHistoryButton ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            tooltip: t.receiveHistoryPage.title,
            onPressed: vm.showHistoryButton
                ? () async {
                    await context.push(() => const ReceiveHistoryPage());
                  }
                : null,
            icon: const Icon(Icons.history_rounded),
          ),
        ),
        IconButton(
          key: const ValueKey('info-btn'),
          tooltip: t.receiveTab.infoBox.alias,
          onPressed: vm.toggleAdvanced,
          icon: Icon(
            vm.showAdvanced ? Icons.visibility_off_rounded : Icons.info_rounded,
          ),
        ),
      ],
    );
  }
}

class _HeroLogo extends StatelessWidget {
  final bool isOnline;

  const _HeroLogo({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final size = context.isCompactPhoneLayout
        ? 64.0
        : context.isPhoneLayout
            ? 72.0
            : 104.0;
    return GlassSurface(
      width: size,
      height: size,
      strong: isOnline,
      padding: EdgeInsets.all(
        context.isCompactPhoneLayout ? 6 : context.isPhoneLayout ? 7 : 10,
      ),
      child: const FittedBox(
        fit: BoxFit.contain,
        child: AloeChatAILogo(withText: false),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    return Padding(
      padding: EdgeInsets.only(bottom: phone ? 10 : 14),
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.visuals.mutedForeground,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.visuals.mutedForeground,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
    );
  }
}
