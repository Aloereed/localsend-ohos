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

import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { Reply, WebViewFlutterApi, WebViewHostApi } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager';
import { WebViewPlatformView } from './WebViewHostApiImpl';

export class WebViewFlutterApiImpl {
  private binaryMessenger: BinaryMessenger;
  private instanceManager: InstanceManager;
  private api: WebViewFlutterApi;

  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    this.binaryMessenger = binaryMessenger;
    this.instanceManager = instanceManager;
    this.api = new WebViewFlutterApi(binaryMessenger);
  }

  create(instance: WebViewPlatformView, callback: Reply<void>): void {
    if (!this.instanceManager.containsInstance(instance)) {
      this.api.create(this.instanceManager.addHostCreatedInstance(instance), callback);
    }
  }

  setApi(api: WebViewFlutterApi): void {
    this.api = api;
  }

  onScrollChanged(
    instance: WebViewHostApi,
    left: number,
    top: number,
    oldLeft: number,
    oldTop: number,
    callback: Reply<void>): void {
    this.api.onScrollChanged(
        this.instanceManager.getIdentifier(instance),
        left,
        top,
        oldLeft,
        oldTop,
        callback);
  }
}