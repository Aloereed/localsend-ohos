import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/init.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/theme.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:localsend_app/widget/watcher/life_cycle_watcher.dart';
import 'package:localsend_app/widget/watcher/shortcut_watcher.dart';
import 'package:localsend_app/widget/watcher/tray_watcher.dart';
import 'package:localsend_app/widget/watcher/window_watcher.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

Future<void> main(List<String> args) async {
  final container = await preInit(args);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RefenaScope.withContainer(
    container: container,
    child: TranslationProvider(
      child: const PrivacyPolicyApp(),
    ),
  ));
}

class PrivacyPolicyApp extends StatelessWidget {
  const PrivacyPolicyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrivacyPolicyScreen(),
    );
  }
}

class PrivacyPolicyScreen extends StatefulWidget {
  @override
  _PrivacyPolicyScreenState createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isPolicyAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacyPolicyStatus();
  }

  Future<void> _checkPrivacyPolicyStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isAccepted = prefs.getBool('privacy_policy_accepted');

    if (isAccepted == null || !isAccepted) {
      // 如果未接受隐私政策，显示隐私政策对话框
      Future.delayed(Duration.zero, () {
        _showPrivacyPolicyDialog();
      });
    } else {
      setState(() {
        _isPolicyAccepted = true;
      });
      // 创建实例
      final _platform =
          const MethodChannel('samples.flutter.dev/downloadplugin');
      // 调用方法 getBatteryLevel
      final result =
          await _platform.invokeMethod<String>('getDownloadPermission');
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁止点击外部关闭对话框
      builder: (BuildContext context) {
        return PrivacyPolicyDialog(
          onAccept: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_policy_accepted', true);
            setState(() {
              _isPolicyAccepted = true;
            });
            Navigator.of(context).pop(); // 关闭对话框
            final _platform =
                const MethodChannel('samples.flutter.dev/downloadplugin');
            // 调用方法 getBatteryLevel
            final result =
                await _platform.invokeMethod<String>('getDownloadPermission');
          },
          onDecline: () {
            // 用户拒绝，退出应用
            Navigator.of(context).pop(); // 关闭对话框
            Future.delayed(Duration(milliseconds: 200), () {
              exit(0); // 退出应用
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPolicyAccepted) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(), // 显示加载指示器
        ),
      );
    }

    final ref = context.ref;
    final (themeMode, colorMode) = ref.watch(settingsProvider
        .select((settings) => (settings.theme, settings.colorMode)));
    final dynamicColors = ref.watch(dynamicColorsProvider);
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (AppLifecycleState state) {
            if (state == AppLifecycleState.resumed) {
              ref.redux(localIpProvider).dispatch(InitLocalIpAction());
            }
          },
          child: ShortcutWatcher(
            child: MaterialApp(
              title: t.appName,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: getTheme(colorMode, Brightness.light, dynamicColors),
              darkTheme: getTheme(colorMode, Brightness.dark, dynamicColors),
              themeMode:
                  colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
              navigatorKey: Routerino.navigatorKey,
              home: RouterinoHome(
                builder: () => const HomePage(
                  initialTab: HomeTab.receive,
                  appStart: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  PrivacyPolicyDialog({required this.onAccept, required this.onDecline});

  Future<String> _loadHtmlFromAssets() async {
    return await rootBundle.loadString('assets/privacy_policy.html');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('隐私政策'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<String>(
          future: _loadHtmlFromAssets(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('无法加载隐私政策'));
            } else {
              return WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..loadHtmlString(snapshot.data!),
              );
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDecline,
          child: Text('拒绝'),
        ),
        ElevatedButton(
          onPressed: onAccept,
          child: Text('同意'),
        ),
      ],
    );
  }
}
