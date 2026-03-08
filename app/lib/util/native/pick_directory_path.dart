import 'package:file_picker_ohos/file_picker_ohos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart'
    as android_channel;
import 'package:refena_flutter/refena_flutter.dart';

Future<String?> pickDirectoryPath(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.android &&
      (RefenaScope.defaultRef.read(deviceRawInfoProvider).androidSdkInt ?? 0) >=
          android_channel.contentUriMinSdk) {
    return android_channel.pickDirectoryPathAndroid();
  }

  return FilePicker.platform.getDirectoryPath();
}
