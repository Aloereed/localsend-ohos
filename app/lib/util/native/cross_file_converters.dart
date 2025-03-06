/*
 * @Author: 
 * @Date: 2024-12-21 15:37:26
 * @LastEditors: Please set LastEditors
 * @LastEditTime: 2025-03-05 21:29:07
 * @Description: file content
 */
import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:device_apps/device_apps.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:file_picker_ohos/file_picker_ohos.dart' as file_picker_ohos;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/file_path_helper.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:share_handler/share_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';

/// Utility functions to convert third party models to common [CrossFile] model.
class CrossFileConverters {
  static Future<CrossFile> convertPlatformFile(
      file_picker.PlatformFile file) async {
    return CrossFile(
      name: file.name,
      fileType: file.name.guessFileType(),
      size: file.size,
      thumbnail: null,
      asset: null,
      path: kIsWeb ? null : file.path,
      bytes: kIsWeb ? file.bytes! : null,
      lastModified: null,
      lastAccessed: null,
    );
  }

  static Future<CrossFile> convertPlatformFileOhos(
      file_picker_ohos.PlatformFile file) async {
    return CrossFile(
      name: file.name,
      fileType: file.name.guessFileType(),
      size: file.size,
      thumbnail: null,
      asset: null,
      path: kIsWeb ? null : file.path,
      bytes: kIsWeb ? file.bytes! : null,
      lastModified: null,
      lastAccessed: null,
    );
  }

  static Future<CrossFile> convertUriOhos(
      String uri) async {
    final path = uri.startsWith("file://")?Uri.decodeFull(uri.replaceFirst(RegExp(r"file://(media|docs)"), "")):uri;
    final file = File(path);
    // 打印file是否存在
    print("file exists:"+file.existsSync().toString());
    print("start convert:"+path);
    return CrossFile(
      name: path.fileName,
      fileType: path.fileName.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: kIsWeb ? null : file.path,
      bytes: null,
      lastModified: null,
      lastAccessed: null,
    );
  }

  static Future<CrossFile> convertAssetEntity(AssetEntity asset) async {
    final file = (await asset.originFile)!;
    return CrossFile(
      name: await asset.titleAsync,
      fileType: asset.type == AssetType.video ? FileType.video : FileType.image,
      size: await file.length(),
      thumbnail: null,
      asset: asset,
      path: file.path,
      bytes: null,
      lastModified: file.lastModifiedSync().toUtc(),
      lastAccessed: file.lastAccessedSync().toUtc(),
    );
  }

  static Future<CrossFile> convertXFile(XFile file) async {
    // delete "file://media" or "file://docs" from the path
    final fileName = file.path.fileName;

    return CrossFile(
      name: Uri.decodeFull(file.name),
      fileType: file.name.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: kIsWeb
          ? null
          : Uri.decodeFull(
              file.path.replaceFirst(RegExp(r"file://(media|docs)"), "")),
      bytes: kIsWeb
          ? await file.readAsBytes()
          : null, // we can fetch it now because in Web it is already there
      lastModified: kIsWeb || checkPlatform([TargetPlatform.ohos]) ? null : await file.lastModified(),
      lastAccessed: null,
    );
  }

  static Future<CrossFile> convertFile(File file) async {
    return CrossFile(
      name: file.path.fileName,
      fileType: file.path.fileName.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: file.path,
      bytes: null,
      lastModified: file.lastModifiedSync().toUtc(),
      lastAccessed: file.lastAccessedSync().toUtc(),
    );
  }

  static Future<CrossFile> convertFileInfo(android_channel.FileInfo file) async {
    return CrossFile(
      name: file.name,
      fileType: file.name.guessFileType(),
      size: file.size,
      thumbnail: null,
      asset: null,
      path: file.uri,
      bytes: null,
      lastModified: DateTime.fromMillisecondsSinceEpoch(file.lastModified, isUtc: true),
      lastAccessed: null,
    );
  }

  static Future<CrossFile> convertSharedAttachment(SharedAttachment attachment) async {
    final file = File(attachment.path);
    final fileName = attachment.path.fileName;
    return CrossFile(
      name: fileName,
      fileType: fileName.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: file.path,
      bytes: null,
      lastModified: file.lastModifiedSync().toUtc(),
      lastAccessed: file.lastAccessedSync().toUtc(),
    );
  }

  static Future<CrossFile> convertApplication(Application app) async {
    final file = File(app.apkFilePath);
    return CrossFile(
      name: '${app.appName.trim()} - v${app.versionName}.apk',
      fileType: FileType.apk,
      thumbnail: app is ApplicationWithIcon ? app.icon : null,
      size: await file.length(),
      asset: null,
      path: app.apkFilePath,
      bytes: null,
      lastModified: null,
      lastAccessed: null,
    );
  }
}

extension CompareFile on CrossFile {
  bool isSameFile({required CrossFile otherFile}) {
    return (path ?? '') == (otherFile.path ?? '');
  }
}
