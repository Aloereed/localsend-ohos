/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import bundleManager from '@ohos.bundle.bundleManager';
import { AsyncCallback } from '@ohos.base';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG: string = "ImagePickerUtils";
const CAMERA_PERMISSION: string = "ohos.permission.CAMERA";
let bundleFlag: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION;

export default class ImagePickerUtils {
  private static isPermissionPresentInManifest(permissionName: string, callback: AsyncCallback<boolean>): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleFlag, (error, bundleInfo) => {
        if (bundleInfo == null) {
          Log.w(TAG, "get req permission bundleInfo is empty");
          callback(null, false);
          return;
        }
        for (let permission of bundleInfo.reqPermissionDetails) {
          Log.i(TAG, "permission : " + permission.name)
          if (permission.name === permissionName) {
            Log.i(TAG, "get req permission");
            callback(null, true);
            return;
          }
        }
        Log.i(TAG, "not find target permission");
        callback(null, false);
      });
    } catch (err) {
      Log.e(TAG, "get application info error")
      callback(null, false);
    }
  }

  /**
   * Camera permission need request if it present in manifest
   *
   * <p>Camera permission may be used in another package, as example flutter_barcode_reader.
   * https://github.com/flutter/flutter/issues/29837
   *
   * @param callback return true, if need request camera permission, otherwise false
   */
  public static needRequestCameraPermission(callback: AsyncCallback<boolean>): void {
    return ImagePickerUtils.isPermissionPresentInManifest(CAMERA_PERMISSION, callback);
  }
}