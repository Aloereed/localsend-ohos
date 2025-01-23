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

import { InstanceManager } from './InstanceManager'
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { Reply, FileChooserParamsFlutterApi, FileChooserMode } from "./GeneratedOhosWebView"

export class FileChooserParamsFlutterApiImpl extends FileChooserParamsFlutterApi {
  private instanceManager: InstanceManager;

  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    super(binaryMessenger);
    this.instanceManager = instanceManager;
  }

  private toFileChooserEnumData(mode: number): FileChooserMode {
    switch (mode) {
      case FileSelectorMode.FileOpenMode:
        return FileChooserMode.OPEN;

      case FileSelectorMode.FileOpenMultipleMode:
        return FileChooserMode.OPEN_MULTIPLE;

      case FileSelectorMode.FileSaveMode:
        return FileChooserMode.SAVE;

      default:
        throw new Error(`Unsupported FileChooserMode: ${mode}`);
    }
  }

  /**
   * Stores the FileChooserParams instance and notifies Dart to create a new FileChooserParams
   * instance that is attached to this one.
   */

  create(instance: FileSelectorParam, callback: Reply<void>) {
    if (!this.instanceManager.containsInstance(instance)) {
      super.tCreate(
        this.instanceManager.addHostCreatedInstance(instance),
        instance.isCapture(),
        instance.getAcceptType(),
        this.toFileChooserEnumData(instance.getMode()),
        //instance.getFilenameHint(),
        callback
      );
    }
  }
}
