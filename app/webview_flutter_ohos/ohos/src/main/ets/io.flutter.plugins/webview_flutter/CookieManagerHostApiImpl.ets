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

import { Result } from './GeneratedOhosWebView'
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { InstanceManager } from './InstanceManager'
import { CookieManagerHostApi } from './GeneratedOhosWebView';
import web_webview from '@ohos.web.webview'
export class CookieManagerHostApiImpl extends CookieManagerHostApi {
  private binaryMessenger: BinaryMessenger;
  private instanceManager: InstanceManager;

  constructor(binaryMessenger: BinaryMessenger , instanceManager: InstanceManager ) {
    super()
    this.binaryMessenger = binaryMessenger;
    this.instanceManager = instanceManager;
  }

  private getCookieManagerInstance(identifier: number): ESObject {
    const cookieManagerInstance: ESObject = this.instanceManager.getInstance(identifier)
    if (cookieManagerInstance) {
      return cookieManagerInstance
    }
    else {
      throw new Error("getCookieManagerInstance, no such instance")
    }
  }
  attachInstance(instanceIdentifier: number) {

  }

  setCookie(identifier: number, url: string, value: string) {
    web_webview.WebCookieManager.setCookie(url, value);
  }

  setAcceptThirdPartyCookies(identifier: number, accept: boolean) {
    web_webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(accept);
  }

  removeAllCookies(identifier: number, result: Result<boolean> ) {
    web_webview.WebCookieManager.clearAllCookiesSync()
    result.success(true)
  }

}

export interface cookieManager {
  removeAllCookies(identifier: number, result: Result<boolean> | null): void

  putAcceptThirdPartyCookieEnabled(accept: boolean): void

  setCookie(url: string, value: string): void
}
