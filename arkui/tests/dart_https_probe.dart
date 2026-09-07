import 'dart:io';
import 'dart:convert';

Future<void> main(List<String> args) async {
  final client = HttpClient()..badCertificateCallback = (_, __, ___) => true;
  client.connectionTimeout = const Duration(seconds: 5);
  try {
    for (var index = 0; index < 5; index++) {
      final request = await client.getUrl(Uri.parse('${args.first}/api/localsend/v2/info'));
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 8));
      print('Dart HTTPS request $index: ${response.statusCode}, ${body.length} bytes');
    }
  } finally { client.close(force: true); }
}
