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

import {InstanceManager} from './InstanceManager'
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import {Reply, JavaScriptChannelFlutterApi} from "./GeneratedOhosWebView"
import { JavaScriptChannel } from './JavaScriptChannel';

export class JavaScriptChannelFlutterApiImpl extends JavaScriptChannelFlutterApi {
  private  instanceManager : InstanceManager;
  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    super(binaryMessenger);
    this.instanceManager = instanceManager;
  }


  postMessage(
    javaScriptChannel:JavaScriptChannel,
    messageArg:string,
    callback:Reply<void>) {
    super.postMessageT(this.getIdentifierForJavaScriptChannel(javaScriptChannel), messageArg, callback);
  }

  private getIdentifierForJavaScriptChannel( javaScriptChannel:JavaScriptChannel) :number{
    const identifier:number = this.instanceManager.getIdentifier(javaScriptChannel);
    if (identifier == null) {
      throw new Error("Could not find identifier for JavaScriptChannel.");
    }
    return identifier;
  }
}
