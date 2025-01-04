/*
 * @Author: 
 * @Date: 2024-12-21 15:37:26
 * @LastEditors: Please set LastEditors
 * @LastEditTime: 2024-12-21 19:17:25
 * @Description: file content
 */
import 'package:common/common.dart';
import 'package:flutter/material.dart';
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
  }
  // if (checkPlatform([TargetPlatform.ohos])) {
  //   // Use file_selector to save ANY file
  //   try {
  //     // Select a location to save the file
  //     final fileName = filePath.split('/').last; // Extract the file name
  //     final saveLocation = await getSaveLocation(suggestedName: fileName);
  //     if(saveLocation == null){
  //       return;
  //     }
  //     final savePath = saveLocation.path;
  //     if (savePath != null) {
  //       // Read the file content from the original file path
  //       final fileData = await XFile(filePath).readAsBytes();

  //       // Create and save the file at the selected location
  //       final outputFile = XFile.fromData(
  //         fileData,
  //         name: fileName,
  //         path: savePath,
  //       );
  //       await outputFile.saveTo(savePath);

  //       // Optionally show a success message
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('File saved to $savePath')),
  //         );
  //       }
  //     } else {
  //       // User cancelled the save operation
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('File save cancelled')),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     // Handle errors during the file save process
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to save file: $e')),
  //       );
  //     }
  //   }
  // }
}