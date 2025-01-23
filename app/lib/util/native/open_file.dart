/*
 * @Author: 
 * @Date: 2025-01-23 15:53:38
 * @LastEditors: 
 * @LastEditTime: 2025-01-23 17:41:54
 * @Description: file content
 */
import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/util/native/android_saf.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/dialogs/cannot_open_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';
/// Opens the selected file which is stored on the device.
Future<void> openFile(
  BuildContext context,
  FileType fileType,
  String filePath, {
  void Function()? onDeleteTap,
}) async {
  // if ((fileType == FileType.apk || filePath.toLowerCase().endsWith('.apk')) && checkPlatform([TargetPlatform.android])) {
  //   await Permission.requestInstallPackages.request();
  // }

  // final fileOpenResult = await OpenFilex.open(filePath);
  // if (fileOpenResult.type != ResultType.done && context.mounted) {
  //   await CannotOpenFileDialog.open(context, filePath, onDeleteTap);
  // }
  if (checkPlatform([TargetPlatform.ohos])) {
    // 使用系统分享功能
    try {
      await Share.shareFiles([filePath], text: '分享文件');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
    return;
  }

  if (filePath.startsWith('content://')) {
    await openContentUri(uri: filePath);
    return;
  }

  final fileOpenResult = await OpenFilex.open(filePath);
  if (fileOpenResult.type != ResultType.done && context.mounted) {
    await CannotOpenFileDialog.open(context, filePath, onDeleteTap);
  }
}
