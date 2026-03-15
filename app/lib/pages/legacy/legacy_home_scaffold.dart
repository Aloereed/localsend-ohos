import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page.dart';

class LegacyHomeScaffold extends StatelessWidget {
  final PageController controller;
  final HomeTab currentTab;
  final HomeTab lastNonMessageTab;
  final ValueChanged<HomeTab> onTabChange;
  final List<Widget> tabs;
  final bool showDragIndicator;

  const LegacyHomeScaffold({
    required this.controller,
    required this.currentTab,
    required this.lastNonMessageTab,
    required this.onTabChange,
    required this.tabs,
    required this.showDragIndicator,
    super.key,
  });

  int _navIndex(HomeTab tab) {
    switch (tab) {
      case HomeTab.receive:
        return 0;
      case HomeTab.send:
        return 1;
      case HomeTab.settings:
        return 2;
      case HomeTab.message:
        return 0;
    }
  }

  HomeTab _tabFromIndex(int index) {
    switch (index) {
      case 0:
        return HomeTab.receive;
      case 1:
        return HomeTab.send;
      case 2:
        return HomeTab.settings;
      default:
        return HomeTab.receive;
    }
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context);
    final navTab = currentTab == HomeTab.message ? lastNonMessageTab : currentTab;
    final currentIndex = _navIndex(navTab);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              children: tabs,
            ),
            if (showDragIndicator)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).colorScheme.background.withOpacity(0.95),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.file_download, size: 96),
                      const SizedBox(height: 20),
                      Text(
                        t.sendTab.placeItems,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => onTabChange(_tabFromIndex(index)),
        items: [
          BottomNavigationBarItem(
            icon: Icon(HomeTab.receive.icon),
            label: t.receiveTab.title,
          ),
          BottomNavigationBarItem(
            icon: Icon(HomeTab.send.icon),
            label: t.sendTab.title,
          ),
          BottomNavigationBarItem(
            icon: Icon(HomeTab.settings.icon),
            label: t.settingsTab.title,
          ),
        ],
      ),
    );
  }
}
