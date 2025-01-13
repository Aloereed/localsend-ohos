import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
