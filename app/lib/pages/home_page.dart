import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.wifi_rounded),
  send(Icons.rocket_launch_rounded),
  settings(Icons.tune_rounded);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
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
  final EventChannel _eventChannel =
      const EventChannel('com.example.app/events');

  @override
  void initState() {
    super.initState();

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
    ref
        .redux(homePageControllerProvider)
        .dispatch(ChangeTabAction(HomeTab.send));
  }

  void _onErrorOpenUri(Object error) {
    debugPrint('Error receiving event: $error');
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context);
    final vm = context.watch(homePageControllerProvider);
    final bottomInset = getNavBarPadding(context);
    final dockBottom = (context.isPhoneLayout ? 12.0 : 18.0) + bottomInset;
    final pageBottomPadding = (context.isPhoneLayout ? 92.0 : 108.0) + bottomInset;

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
        vm.changeTab(HomeTab.send);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: AppBackdrop(
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: pageBottomPadding),
                    child: PageView(
                      controller: vm.controller,
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        ReceiveTab(),
                        SendTab(),
                        SettingsTab(),
                      ],
                    ),
                  ),
                ),
                if (_dragAndDropIndicator)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(context.isPhoneLayout ? 14 : 18),
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
                    child: FloatingTabDock<HomeTab>(
                      currentValue: vm.currentTab,
                      onChanged: vm.changeTab,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
