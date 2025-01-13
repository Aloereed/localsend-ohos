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

import { DownloadListenerFlutterApiImpl } from './DownloadListenerFlutterApiImpl';
import { DownloadListenerHostApi } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager';

export class DownloadListenerHostApiImpl extends DownloadListenerHostApi {
  private instanceManager: InstanceManager;

  private downloadListenerCreator: DownloadListenerCreator;

  private flutterApi: DownloadListenerFlutterApiImpl;

  constructor(
    instanceManager: InstanceManager, downloadListenerCreator: DownloadListenerCreator,
    flutterApi: DownloadListenerFlutterApiImpl
  ) {
    super()
    this.instanceManager = instanceManager;
    this.downloadListenerCreator = downloadListenerCreator;
    this.flutterApi = flutterApi;
  }

  create(instanceId: number) {
    const downloadListener = DownloadListenerHostApiImpl.createDownloadListener(this.flutterApi);
    this.instanceManager.addDartCreatedInstance(downloadListener, instanceId);
  }

  static createDownloadListener(flutterApi: DownloadListenerFlutterApiImpl): DownloadListenerImpl {
    return new DownloadListenerImpl(flutterApi);
  }
}

export class DownloadListenerCreator {
  createDownloadListener(flutterApi: DownloadListenerFlutterApiImpl): DownloadListenerImpl {
    return new DownloadListenerImpl(flutterApi);
  }
}

class DownloadListenerImpl implements DownloadListener {
  private flutterApi: DownloadListenerFlutterApiImpl;

  constructor(flutterApi: DownloadListenerFlutterApiImpl) {
    this.flutterApi = flutterApi;
  }

  onDownloadStart(url: string, userAgent: string, contentDisposition: string, mimetype: string, contentLength: number) {
    this.flutterApi.onDownloadStart(
      this, url, userAgent, contentDisposition, mimetype, contentLength, { reply: () => {
    } }
    );
  }
}

export interface DownloadListener {
  onDownloadStart(url: string, userAgent: string, contentDisposition: string, mimeType: string, contentLength: number): void;
}
