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

import common from '@ohos.app.ability.common';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import { InstanceManager } from './InstanceManager';

const TAG :string = "FlutterWebViewFactory";
export class FlutterWebViewFactory extends PlatformViewFactory {
  private instanceManager:InstanceManager;

  constructor(instanceManager:InstanceManager) {
    super(StandardMessageCodec.INSTANCE);
    this.instanceManager = instanceManager;
  }

  create(context: common.Context, viewId: number, args: ESObject): PlatformView {
    Log.i(TAG, "params " + args)
    const identifier : number = args;
    if (identifier == null) {
      throw new Error("An identifier is required to retrieve WebView instance.");
    }
    const view : PlatformView = this.instanceManager.getInstance(identifier);
    if (view == null) {
      throw new Error("Unable to find WebView instance: " + args);
    }
    return view;
  }
}