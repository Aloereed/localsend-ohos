/*
 * @Author: 
 * @Date: 2025-02-17 13:29:05
 * @LastEditors: Please set LastEditors
 * @LastEditTime: 2025-03-23 13:10:21
 * @Description: file content
 */
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart'
    as android_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:logging/logging.dart';
import 'package:open_dir/open_dir.dart';
import 'package:open_filex/open_filex.dart';

final _logger = Logger('OpenFolder');

String convertPathToOhosUri(String path) {
    String prefix;

    // 判断路径是否以 /Photos 开头
    if (path.startsWith('/Photos')) {
      prefix = 'file://media';
    } else if (path.contains(':')) {
      prefix = '';
    } else {
      prefix = 'file://docs';
    }

    // 拼接前缀和路径
    String fullPath = '$prefix$path';

    // 使用 Uri.parse 进行一般的 URI 转换
    Uri uri = Uri.parse(fullPath);

    return uri.toString();
  }

/// Opens the folder and optionally selects the file in the folder.
Future<void> openFolder({
  required String folderPath,
  String? fileName,
}) async {
  if (folderPath.startsWith('content://')) {
    await android_channel.openContentUri(uri: folderPath);
    return;
  }

  if (checkPlatform([TargetPlatform.ohos])) {
    final _platform = const MethodChannel('samples.flutter.dev/downloadplugin');
    // 调用方法 getBatteryLevel
    final result = await _platform.invokeMethod<String>('openFileManager',{'uri':convertPathToOhosUri(folderPath)});
    return;
  }

  if (fileName != null &&
      checkPlatform([
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS
      ])) {
    // open folder and select file

    if (defaultTargetPlatform == TargetPlatform.windows) {
      folderPath = folderPath.replaceAll('/', '\\');
    }

    final result = await OpenDir()
        .openNativeDir(path: folderPath, highlightedFileName: fileName);
    _logger.info(
        'Open folder result: $result, path: $folderPath, file: $fileName');
  } else {
    // only open folder

    if (!folderPath.endsWith('/')) {
      folderPath = '$folderPath/';
    }

    final result = await OpenFilex.open(folderPath);
    _logger.info('Open folder result: ${result.message}, path: $folderPath');
  }
}
