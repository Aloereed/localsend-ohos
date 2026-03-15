import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _QuickSaveMode {
  off,
  favorites,
  on,
}

class LegacyReceiveTab extends StatelessWidget {
  const LegacyReceiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    Translations.of(context);
    final vm = context.watch(receiveTabVmProvider);
    final isOnline = vm.serverState != null;
    final networkSummary = isOnline
        ? vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' | ')
        : t.general.offline;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          vm.serverState?.alias ?? vm.aliasSettings,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          isOnline ? networkSummary : t.general.offline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.general.quickSave,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_QuickSaveMode>(
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
                      if (vm.quickSaveFromFavoritesSettings) _QuickSaveMode.favorites,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (vm.showAdvanced)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: t.receiveTab.infoBox.alias,
                    value: vm.serverState?.alias ?? '-',
                  ),
                  _InfoRow(
                    label: t.receiveTab.infoBox.ip,
                    value: vm.localIps.isEmpty ? t.general.unknown : vm.localIps.join('\n'),
                  ),
                  _InfoRow(
                    label: t.receiveTab.infoBox.port,
                    value: vm.serverState?.port.toString() ?? '-',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (vm.showHistoryButton)
              TextButton.icon(
                onPressed: () async {
                  await context.push(() => const ReceiveHistoryPage());
                },
                icon: const Icon(Icons.history_rounded),
                label: Text(t.receiveHistoryPage.title),
              ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: vm.toggleAdvanced,
              icon: Icon(vm.showAdvanced ? Icons.visibility_off_rounded : Icons.info_rounded),
              label: Text(vm.showAdvanced ? t.general.hide : t.general.advanced),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
