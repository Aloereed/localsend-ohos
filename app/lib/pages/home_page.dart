import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/legacy/legacy_home_scaffold.dart';
import 'package:localsend_app/pages/legacy/legacy_receive_tab.dart';
import 'package:localsend_app/pages/legacy/legacy_send_tab.dart';
import 'package:localsend_app/pages/legacy/legacy_settings_tab.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/message_tab.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/message_history_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.wifi_rounded),
  message(Icons.chat_bubble_rounded),
  send(Icons.rocket_launch_rounded),
  settings(Icons.tune_rounded);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.message:
        return t.messageTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;
  bool _isTabDockVisible = true;
  final EventChannel _eventChannel =
      const EventChannel('com.example.app/events');
  late HomeTab _lastNonMessageTab;

  @override
  void initState() {
    super.initState();
    _lastNonMessageTab = widget.initialTab == HomeTab.message
        ? HomeTab.receive
        : widget.initialTab;

    ensureRef((ref) async {
      ref
          .redux(homePageControllerProvider)
          .dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });

    _eventChannel
        .receiveBroadcastStream()
        .listen(_onEventOpenUri, onError: _onErrorOpenUri);
  }

  void _onEventOpenUri(dynamic event) async {
    if (event is! String || event.isEmpty) {
      return;
    }

    await ref.redux(selectedSendingFilesProvider).dispatchAsync(
          AddFilesAction(
            files: [event],
            converter: CrossFileConverters.convertUriOhos,
          ),
        );
    _setTabDockVisible(true);
    ref
        .redux(homePageControllerProvider)
        .dispatch(ChangeTabAction(HomeTab.send));
  }

  void _onErrorOpenUri(Object error) {
    debugPrint('Error receiving event: $error');
  }

  void _setTabDockVisible(bool visible) {
    if (_isTabDockVisible == visible) {
      return;
    }

    setState(() {
      _isTabDockVisible = visible;
    });
  }

  void _changeTab(HomePageVm vm, HomeTab tab) {
    _setTabDockVisible(true);
    if (tab != HomeTab.message && _lastNonMessageTab != tab) {
      setState(() {
        _lastNonMessageTab = tab;
      });
    }
    vm.changeTab(tab);
  }

  bool _onScrollablePageScroll(
    UserScrollNotification notification,
    bool shouldAutoHideTabDock,
  ) {
    if (!shouldAutoHideTabDock) {
      return false;
    }

    if (notification.direction == ScrollDirection.reverse) {
      _setTabDockVisible(false);
    } else if (notification.direction == ScrollDirection.forward) {
      _setTabDockVisible(true);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context);
    final vm = context.watch(homePageControllerProvider);
    if (vm.currentTab != HomeTab.message) {
      _lastNonMessageTab = vm.currentTab;
    }
    final legacy = context.watch(
      settingsProvider.select((settings) => settings.legacyUiMode),
    );
    final activeMessageSelection = context.watch(activeMessageSelectionProvider);
    final bottomInset = getNavBarPadding(context);
    final shouldAutoHideTabDock =
        vm.currentTab == HomeTab.settings ||
        (vm.currentTab == HomeTab.message && activeMessageSelection != null);
    final showTabDock = !shouldAutoHideTabDock || _isTabDockVisible;
    final dockBottom = (context.isPhoneLayout ? 12.0 : 18.0) + bottomInset;
    final pageBottomPadding =
        (showTabDock
                ? (context.isPhoneLayout ? 92.0 : 108.0)
                : (context.isPhoneLayout ? 16.0 : 24.0)) +
            bottomInset;

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        if (event.files.length == 1 &&
            Directory(event.files.first.path).existsSync()) {
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(AddDirectoryAction(event.files.first.path));
        } else {
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(
                AddFilesAction(
                  files: event.files,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        _changeTab(vm, HomeTab.send);
      },
      child: legacy
          ? LegacyHomeScaffold(
              controller: vm.controller,
              currentTab: vm.currentTab,
              lastNonMessageTab: _lastNonMessageTab,
              onTabChange: (tab) => _changeTab(vm, tab),
              showDragIndicator: _dragAndDropIndicator,
              tabs: const [
                LegacyReceiveTab(),
                MessageTab(),
                LegacySendTab(),
                LegacySettingsTab(),
              ],
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: AppBackdrop(
                child: SafeArea(
                  bottom: false,
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (notification) => _onScrollablePageScroll(
                        notification, shouldAutoHideTabDock),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(bottom: pageBottomPadding),
                            child: PageView(
                              controller: vm.controller,
                              physics: const NeverScrollableScrollPhysics(),
                              children: const [
                                ReceiveTab(),
                                MessageTab(),
                                SendTab(),
                                SettingsTab(),
                              ],
                            ),
                          ),
                        ),
                        if (_dragAndDropIndicator)
                          Positioned.fill(
                            child: Padding(
                              padding:
                                  EdgeInsets.all(context.isPhoneLayout ? 14 : 18),
                              child: GlassSurface(
                                strong: true,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.file_download_rounded,
                                      size: context.isPhoneLayout ? 72 : 96,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      t.sendTab.placeItems,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t.sendTab.selection.title,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: dockBottom,
                          child: Center(
                            child: IgnorePointer(
                              ignoring: !showTabDock,
                              child: AnimatedSlide(
                                offset: showTabDock
                                    ? Offset.zero
                                    : const Offset(0, 1.2),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: showTabDock ? 1 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  child: FloatingTabDock<HomeTab>(
                                    currentValue: vm.currentTab,
                                    onChanged: (tab) => _changeTab(vm, tab),
                                    items: HomeTab.values
                                        .map(
                                          (tab) => FloatingTabDockItem<HomeTab>(
                                            value: tab,
                                            icon: tab.icon,
                                            label: tab.label,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
