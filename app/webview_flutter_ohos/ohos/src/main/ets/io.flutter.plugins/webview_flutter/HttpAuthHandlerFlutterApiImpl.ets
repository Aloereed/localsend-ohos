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
import { HttpAuthHandlerFlutterApi, Reply } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager'

/**
 * Flutter API implementation for {@link HttpAuthHandler}.
 *
 * <p>This class may handle adding native instances that are attached to a Dart instance or passing
 * arguments of callbacks methods to a Dart instance.
 */
export class HttpAuthHandlerFlutterApiImpl {
  // To ease adding additional methods, this value is added prematurely.
  binaryMessenger: BinaryMessenger;

  instanceManager: InstanceManager;

  api: HttpAuthHandlerFlutterApi;

  /**
   * Constructs a {@link HttpAuthHandlerFlutterApiImpl}.
   *
   * @param binaryMessenger used to communicate with Dart over asynchronous messages
   * @param instanceManager maintains instances stored to communicate with attached Dart objects
   */
  constructor(binaryMessenger: BinaryMessenger, instanceManager: InstanceManager) {
    this.binaryMessenger = binaryMessenger;
    this.instanceManager = instanceManager;
    this.api = new HttpAuthHandlerFlutterApi(binaryMessenger);
  }

  /**
   * Stores the `HttpAuthHandler` instance and notifies Dart to create and store a new
   * `HttpAuthHandler` instance that is attached to this one. If `instance` has already been added,
   * this method does nothing.
   */
  create(instance: ESObject, callback: Reply<void>) {
    if (!this.instanceManager.containsInstance(instance)) {
      this.api.create(this.instanceManager.addHostCreatedInstance(instance), callback);
    }
  }
}
