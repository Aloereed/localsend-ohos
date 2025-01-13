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
import { HttpAuthHandlerHostApi, HttpAuthHandler } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager'

/**
 * Host api implementation for {@link HttpAuthHandler}.
 *
 * <p>Handles creating {@link HttpAuthHandler}s that intercommunicate with a paired Dart object.
 */
export class HttpAuthHandlerHostApiImpl extends HttpAuthHandlerHostApi {
  // To ease adding additional methods, this value is added prematurely.
  binaryMessenger: BinaryMessenger;

  instanceManager: InstanceManager;

  /**
   * Constructs a {@link HttpAuthHandlerHostApiImpl}.
   *
   * @param binaryMessenger used to communicate with Dart over asynchronous messages
   * @param instanceManager maintains instances stored to communicate with attached Dart objects
   */
  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    super();
    this.binaryMessenger = binaryMessenger;
    this.instanceManager = instanceManager;
  }

  useHttpAuthUsernamePassword(instanceId: number): boolean {
    return this.getHttpAuthHandlerInstance(instanceId).useHttpAuthUsernamePassword();
  }

  cancel(instanceId: number) {
    this.getHttpAuthHandlerInstance(instanceId).cancel();
  }

  proceed(instanceId: number, username: string, password: string) {
    this.getHttpAuthHandlerInstance(instanceId).proceed(username, password);
  }

  getHttpAuthHandlerInstance(instanceId: number): HttpAuthHandler {
    return this.instanceManager.getInstance(instanceId);
  }
}
