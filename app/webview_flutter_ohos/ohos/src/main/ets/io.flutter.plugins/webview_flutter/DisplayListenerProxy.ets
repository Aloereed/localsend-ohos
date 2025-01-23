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

import display from '@ohos.display';

export class DisplayListenerProxy {
  private static TAG = "DisplayListenerProxy";

  private listenersBeforeWebView: mDisplay[] = new Array<mDisplay>();

  async onPreWebViewInitialization(): Promise<void> {
    this.listenersBeforeWebView = (await this.yoinkDisplayListeners()) as mDisplay[];
  }

  private async yoinkDisplayListeners(): Promise<display.Display[]> {
    const res = await display.getAllDisplays()
    return res
  }

  async onPostWebViewInitialization() {
    let webViewListeners: mDisplay[] = (await this.yoinkDisplayListeners()) as mDisplay[];

    webViewListeners = webViewListeners.filter((item: ESObject) => this.listenersBeforeWebView.indexOf(item) === -1)

    if (webViewListeners.length === 0) {
      return;
    }

    const onDisplayAdded = (displayId: number) => {
      for (let display of webViewListeners) {
        display.addCallback(displayId);
      }
    }

    const onDisplayRemoved = (displayId: number) => {
      for (let display of webViewListeners) {
        display.removeCallback(displayId);
      }
    }

    const onDisplayChanged = (displayId: number) => {
      if (webViewListeners.filter(item => item.id === displayId).length === 0) {
        return;
      }
      for (let display of webViewListeners) {
        display.changeCallback(displayId);
      }
    }

    for (let display of webViewListeners) {
      display.changeCallback = onDisplayChanged;
      display.addCallback = onDisplayAdded;
      display.removeCallback = onDisplayRemoved
    }

    for (let display of webViewListeners) {
      display.off("remove");
      display.off("add");
      display.off("change");

      display.on("remove", onDisplayRemoved)
      display.on("add", onDisplayAdded)
      display.on("change", onDisplayChanged)
    }
  }
}

interface mDisplay extends display.Display {
  on: ESObject,
  off: ESObject,
  changeCallback,
  removeCallback,
  addCallback,
}