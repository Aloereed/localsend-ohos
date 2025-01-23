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

import { OhosObjectHostApi as OhosObjectHostApi } from './GeneratedOhosWebView';
import { InstanceManager } from './InstanceManager';
import { WebViewPlatformView } from './WebViewHostApiImpl';

export class OhosObjectHostApiImpl extends OhosObjectHostApi {
  private instanceManager: InstanceManager;

  /**
   * Constructs a {@link OhosObjectHostApiImpl}.
   *
   * @param instanceManager maintains instances stored to communicate with Dart objects
   */
  constructor(instanceManager: InstanceManager) {
    super()
    this.instanceManager = instanceManager;
  }

  dispose(identifier: number) {
    this.instanceManager.remove(identifier);
  }
}
