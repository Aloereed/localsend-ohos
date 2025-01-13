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

import { JavaScriptChannelHostApi } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager';
import { JavaScriptChannel } from './JavaScriptChannel';
import { JavaScriptChannelFlutterApiImpl } from './JavaScriptChannelFlutterApiImpl';

export class JavaScriptChannelHostApiImpl extends JavaScriptChannelHostApi {
  private instanceManager: InstanceManager;

  private javaScriptChannelCreator: JavaScriptChannelCreator;

  private flutterApi: JavaScriptChannelFlutterApiImpl;

  /** Handles creating {@link JavaScriptChannel}s for a {@link JavaScriptChannelHostApiImpl}. */

  /**
   * Creates a host API that handles creating {@link JavaScriptChannel}s.
   *
   * @param instanceManager maintains instances stored to communicate with Dart objects
   * @param javaScriptChannelCreator handles creating {@link JavaScriptChannel}s
   * @param flutterApi handles sending messages to Dart
   * @param platformThreadHandler handles making callbacks on the desired thread
   */
  constructor(
    instanceManager: InstanceManager, javaScriptChannelCreator: JavaScriptChannelCreator,
    flutterApi: JavaScriptChannelFlutterApiImpl
  ) {
    super()
    this.instanceManager = instanceManager;
    this.javaScriptChannelCreator = javaScriptChannelCreator;
    this.flutterApi = flutterApi;
  }

  create(instanceId: number, channelName: string) {
    const javaScriptChannel: JavaScriptChannel =
    this.javaScriptChannelCreator.createJavaScriptChannel(
      this.flutterApi, channelName
    )
    this.instanceManager.addDartCreatedInstance(javaScriptChannel, instanceId);
  }
}

export class JavaScriptChannelCreator {
  createJavaScriptChannel(
    flutterApi: JavaScriptChannelFlutterApiImpl, channelName: string
  ): JavaScriptChannel {
    return new JavaScriptChannel(flutterApi, channelName);
  }
}