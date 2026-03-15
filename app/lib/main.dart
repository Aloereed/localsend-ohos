import 'dart:io';

import 'package:common/isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/config/init_error.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/privacy_policy.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/watcher/life_cycle_watcher.dart';
import 'package:localsend_app/widget/watcher/shortcut_watcher.dart';
import 'package:localsend_app/widget/watcher/tray_watcher.dart';
import 'package:localsend_app/widget/watcher/window_watcher.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main(List<String> args) async {
  final RefenaContainer container;
  try {
    container = await preInit(args);
  } catch (e, stackTrace) {
    showInitErrorApp(error: e, stackTrace: stackTrace);
    return;
  }

  runApp(
    RefenaScope.withContainer(
      container: container,
      child: TranslationProvider(
        child: const PrivacyPolicyApp(),
      ),
    ),
  );
}

class PrivacyPolicyApp extends StatelessWidget {
  const PrivacyPolicyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final (themeMode, colorMode, lightweightEffects) = ref.watch(
      settingsProvider.select(
        (settings) => (settings.theme, settings.colorMode, settings.lightweightEffects),
      ),
    );
    final dynamicColors = ref.watch(dynamicColorsProvider);

    return MaterialApp(
      title: t.appName,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      navigatorKey: Routerino.navigatorKey,
      theme: getThemeWithSettings(
        colorMode: colorMode,
        brightness: Brightness.light,
        dynamicColors: dynamicColors,
        lightweightEffects: lightweightEffects,
      ),
      darkTheme: getThemeWithSettings(
        colorMode: colorMode,
        brightness: Brightness.dark,
        dynamicColors: dynamicColors,
        lightweightEffects: lightweightEffects,
      ),
      themeMode: colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
      home: const PrivacyPolicyScreen(),
    );
  }
}

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isPolicyAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacyPolicyStatus();
  }

  Future<void> _checkPrivacyPolicyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isAccepted = prefs.getBool('privacy_policy_accepted');

    if (isAccepted == true) {
      if (mounted) {
        setState(() {
          _isPolicyAccepted = true;
        });
      }
      await _requestDownloadPermission();
      return;
    }

    Future<void>.delayed(Duration.zero, _showPrivacyPolicyDialog);
  }

  Future<void> _requestDownloadPermission() async {
    const platform = MethodChannel('samples.flutter.dev/downloadplugin');
    await platform.invokeMethod<String>('getDownloadPermission');
  }

  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PrivacyPolicyDialog(
          onAccept: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_policy_accepted', true);
            if (mounted) {
              setState(() {
                _isPolicyAccepted = true;
              });
            }
            Navigator.of(dialogContext).pop();
            await _requestDownloadPermission();
          },
          onDecline: () {
            Navigator.of(dialogContext).pop();
            Future<void>.delayed(
              const Duration(milliseconds: 200),
              () => exit(0),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPolicyAccepted) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final ref = context.ref;
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (state) {
            switch (state) {
              case AppLifecycleState.resumed:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                break;
              case AppLifecycleState.detached:
                ref.redux(parentIsolateProvider).dispatch(IsolateDisposeAction());
                break;
              default:
                break;
            }
          },
          child: ShortcutWatcher(
            child: RouterinoHome(
              builder: () => const HomePage(
                initialTab: HomeTab.receive,
                appStart: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
