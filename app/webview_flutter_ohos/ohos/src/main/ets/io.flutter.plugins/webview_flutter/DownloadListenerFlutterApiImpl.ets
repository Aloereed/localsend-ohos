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
import { Reply, DownloadListenerFlutterApi, FileChooserMode } from "./GeneratedOhosWebView"

export class DownloadListenerFlutterApiImpl extends DownloadListenerFlutterApi {
  private instanceManager: InstanceManager;

  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    super(binaryMessenger);
    this.instanceManager = instanceManager;
  }

  /** Passes arguments from {@link DownloadListener#onDownloadStart} to Dart. */
  onDownloadStart(
    downloadListener: WebviewController | ESObject,
    url: string,
    userAgent: string,
    contentDisposition: string,
    mimetype: string, contentLength: number, callback: Reply<void>
  ) {
    super.onDownloadStartT(
      this.getIdentifierForListener(downloadListener),
      url,
      userAgent,
      contentDisposition,
      mimetype,
      contentLength,
      callback
    );
  }

  getIdentifierForListener(listener: DownloadListener): number {
    const identifier = this.instanceManager.getIdentifier(listener);
    if (identifier == null) {
      throw new Error("Could not find identifier for DownloadListener.");
    }
    return identifier;
  }
}

export interface DownloadListener {
  onDownloadStart(url: string, userAgent: string, contentDisposition: string, mimeType: string, contentLength: number): void;
}
