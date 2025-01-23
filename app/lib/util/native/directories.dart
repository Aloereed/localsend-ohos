/*
 * @Author: 
 * @Date: 2024-12-21 15:37:26
 * @LastEditors: Please set LastEditors
 * @LastEditTime: 2025-01-13 14:39:47
 * @Description: file content
 */
import 'dart:io' show Directory, Platform, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:shared_storage/shared_storage.dart' as shared_storage;

Future<String> getDefaultDestinationDirectory() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // ignore: deprecated_member_use
      final dir = await shared_storage.getExternalStoragePublicDirectory(shared_storage.EnvironmentDirectory.downloads);
      return dir?.path ?? '/storage/emulated/0/Download';
    case TargetPlatform.iOS:
      return (await path.getApplicationDocumentsDirectory()).path;
    case TargetPlatform.ohos:
      final dir = await path.getDownloadsDirectory();
      final externDir = "/storage/Users/currentUser/Download/com.aloereed.aloechatai";
      // 尝试externDir是否有写入权限
      try {
        final file = File('$externDir/test.txt');
        await file.writeAsString('test');
        await file.delete();
        return externDir;
      } catch (e) {
        return dir?.path ?? (await path.getApplicationDocumentsDirectory()).path;
      }
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.fuchsia:
      var downloadDir = await path.getDownloadsDirectory();
      if (downloadDir == null) {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          downloadDir = Directory('${Platform.environment['HOMEPATH']}/Downloads');
          if (!downloadDir.existsSync()) {
            downloadDir = Directory(Platform.environment['HOMEPATH']!);
          }
        } else {
          downloadDir = Directory('${Platform.environment['HOME']}/Downloads');
          if (!downloadDir.existsSync()) {
            downloadDir = Directory(Platform.environment['HOME']!);
          }
        }
      }
      return downloadDir.path.replaceAll('\\', '/');
  }
}

Future<String> getCacheDirectory() async {
  return (await path.getTemporaryDirectory()).path;
}
