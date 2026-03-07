import 'dart:async';

import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_options_page.dart';
import 'package:localsend_app/pages/receive_page_controller.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/device_bage.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> with Refena {
  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(
      receivePageControllerProvider,
      listener: (prev, next) {
        if (prev.status != next.status) {
          TaskbarHelper.visualizeStatus(next.status);
        }
      },
    );

    if (vm.status == null && vm.message == null) {
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox());
    }

    final senderFavoriteEntry = ref.watch(
      favoritesProvider.select((state) => state.findDevice(vm.sender)),
    );
    final visuals = context.visuals;
    final sectionSpacing = context.adaptiveSectionSpacing;

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          vm.onDecline();
        }
      },
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
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
                      title: senderFavoriteEntry?.alias ?? vm.sender.alias,
                      subtitle: vm.message != null
                          ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage)
                          : t.receivePage.subTitle(n: vm.fileCount),
                      trailing: IconButton(
                        tooltip: t.general.close,
                        onPressed: () {
                          vm.onDecline();
                          context.pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                      chips: [
                        if (vm.showSenderInfo)
                          StatusChip(
                            label: vm.showFullIp ? vm.sender.ip : '#${vm.sender.ip.visualId}',
                            icon: Icons.lan_rounded,
                          ),
                        if (vm.sender.deviceModel != null && vm.showSenderInfo)
                          StatusChip(
                            label: vm.sender.deviceModel!,
                            icon: Icons.devices_rounded,
                          ),
                        StatusChip(
                          label: vm.message != null
                              ? t.receivePage.badge.message
                              : t.receivePage.badge.files(n: vm.fileCount),
                          icon: vm.message != null
                              ? Icons.chat_bubble_rounded
                              : Icons.folder_zip_rounded,
                          emphasized: true,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    SizedBox(height: sectionSpacing),
                    GlassSectionCard(
                      title: t.receivePage.sender.title,
                      subtitle: vm.showSenderInfo
                          ? t.receivePage.sender.subtitleRevealIp
                          : t.receivePage.sender.subtitleHistory,
                      strong: true,
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final compact = context.isPhoneLayout;
                              return Container(
                                width: compact ? 72 : 84,
                                height: compact ? 72 : 84,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(compact ? 24 : 28),
                                ),
                                child: Icon(vm.sender.deviceType.icon, size: compact ? 36 : 42),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          if (vm.showSenderInfo)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    context
                                        .redux(receivePageControllerProvider)
                                        .dispatch(SetShowFullIpAction(!vm.showFullIp));
                                  },
                                  child: DeviceBadge(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.16),
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    label: vm.showFullIp ? vm.sender.ip : '#${vm.sender.ip.visualId}',
                                  ),
                                ),
                                if (vm.sender.deviceModel != null)
                                  DeviceBadge(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surface
                                        .withOpacity(0.48),
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    label: vm.sender.deviceModel!,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    if (vm.message != null)
                      _MessageSection(vm: vm)
                    else
                      _FilesSection(vm: vm),
                    SizedBox(height: sectionSpacing),
                    _ReceiveActions(vm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageSection extends StatelessWidget {
  final ReceivePageVm vm;

  const _MessageSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GlassSectionCard(
      title: vm.isLink
          ? t.receivePage.messageCard.titleLink
          : t.receivePage.messageCard.titleMessage,
      subtitle: vm.isLink
          ? t.receivePage.messageCard.subtitleLink
          : t.receivePage.messageCard.subtitleMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSurface(
            applyBlur: false,
            borderRadius: BorderRadius.circular(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: context.isPhoneLayout ? 96 : 120),
              child: SingleChildScrollView(
                child: SelectableText(vm.message!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {
                  unawaited(Clipboard.setData(ClipboardData(text: vm.message!)));
                  if (checkPlatformIsDesktop()) {
                    context.showSnackBar(t.general.copiedToClipboard);
                  }
                  vm.onAccept();
                  context.pop();
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(t.general.copy),
              ),
              if (vm.isLink)
                FilledButton.tonalIcon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(vm.message!),
                      mode: LaunchMode.externalApplication,
                    );
                    vm.onAccept();
                    context.pop();
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(t.general.open),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilesSection extends StatelessWidget {
  final ReceivePageVm vm;

  const _FilesSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedReceivingFilesProvider);
    return GlassSectionCard(
      title: t.receivePage.filesCard.title,
      subtitle: selectedFiles.isEmpty
          ? t.receivePage.filesCard.empty
          : t.receivePage.filesCard.ready(n: selectedFiles.length),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          StatusChip(
            label: t.receivePage.filesCard.offered(n: vm.fileCount),
            icon: Icons.inventory_2_rounded,
          ),
          StatusChip(
            label: t.receivePage.filesCard.selected(n: selectedFiles.length),
            icon: Icons.checklist_rounded,
            emphasized: selectedFiles.isNotEmpty,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ReceiveActions extends StatelessWidget {
  final ReceivePageVm vm;

  const _ReceiveActions(this.vm);

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedReceivingFilesProvider);

    if (vm.message != null) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            vm.onAccept();
            context.pop();
          },
          icon: const Icon(Icons.close_rounded),
          label: Text(t.general.close),
        ),
      );
    }

    if (vm.status == SessionStatus.canceledBySender) {
      return GlassSectionCard(
        title: t.receivePage.canceled,
        subtitle: t.receivePage.actions.canceledSubtitle,
        child: Center(
          child: FilledButton.icon(
            onPressed: () {
              vm.onClose();
              context.pop();
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(t.general.close),
          ),
        ),
      );
    }

    return GlassSectionCard(
      title: t.receivePage.actions.title,
      subtitle: t.receivePage.actions.subtitle,
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () async {
              await context.push(() => const ReceiveOptionsPage());
            },
            icon: const Icon(Icons.tune_rounded),
            label: Text(t.receiveOptionsPage.title),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  vm.onDecline();
                  context.pop();
                },
                icon: const Icon(Icons.close_rounded),
                label: Text(t.general.decline),
              ),
              FilledButton.icon(
                onPressed: selectedFiles.isEmpty ? null : () => vm.onAccept(),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(t.general.accept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
