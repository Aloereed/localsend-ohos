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

import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView'
import { DVModel, DVModelParameters } from '@ohos/flutter_ohos/src/main/ets/view/DynamicView/dynamicView'
import { Result, WebViewHostApi, WebViewPoint } from './GeneratedOhosWebView'
import web_webview from '@ohos.web.webview'
import { WebBuilder, OhosWebView } from './OhosWebView'
import { createDVModelFromJson } from '@ohos/flutter_ohos/src/main/ets/view/DynamicView/dynamicViewJson'
import { DVModelJson } from "./DynamicUtils"
import { InstanceManager } from './InstanceManager'
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import common from '@ohos.app.ability.common'
import { WebChromeClient } from './WebChromeClientHostApiImpl'
import { WebViewClient } from './WebViewClientHostApiImpl'
import { WebSettings } from './WebSettingsHostApiImpl'
import { DynamicUtils } from "./DynamicUtils"
import { DownloadListener } from './DownloadListenerFlutterApiImpl'
import { DisplayListenerProxy } from './DisplayListenerProxy'
import { JavaScriptChannel } from './JavaScriptChannel'
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { WebViewFlutterApiImpl } from './WebViewFlutterApiImpl.ets'
import window from '@ohos.window'
import display from '@ohos.display'

const TAG: string = "WebViewHostApiImpl";

export class WebViewHostApiImpl extends WebViewHostApi {
  private instanceManager: InstanceManager;

  private webViewProxy: WebViewProxy;

  private binaryMessenger: BinaryMessenger;

  private context: common.Context;
  private api?: WebViewFlutterApiImpl;

  constructor(
    instanceManager: InstanceManager,
    webViewProxy: WebViewProxy,
    binaryMessenger: BinaryMessenger,
    context: common.Context
  ) {
    super();
    this.instanceManager = instanceManager;
    this.webViewProxy = webViewProxy;
    this.binaryMessenger = binaryMessenger;
    this.context = context;
  }

  setContext(context: common.Context): void {
    this.context = context;
  }

  create(instanceId: number): void {
    let displayProxy: DisplayListenerProxy = new DisplayListenerProxy();
    displayProxy.onPreWebViewInitialization();
    const webView: WebViewPlatformView = this.webViewProxy.createWebView();
    displayProxy.onPostWebViewInitialization();
    this.instanceManager.addDartCreatedInstance(webView, instanceId);
  }

  loadData(instanceId: number, data: string, mimeType: string, encoding: string): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().loadData(data, mimeType, encoding, " ", " ");
  }

  async loadDataWithBaseUrl(
    instanceId: number, baseUrl: string, data: string, mimeType: string, encoding: string, historyUrl: string
  ): Promise<void> {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    await webView.waitControllerAttached();
    try {
      // 当baseUrl为空时，其值默认为resource://rawfile/。这样设置是为了解决<a href="">标签锚点无效问题。
      webView.getController().loadData(data, mimeType, encoding, baseUrl == null || baseUrl.trim().length === 0 ? "resource://rawfile/" : baseUrl , historyUrl == null ? " " : historyUrl);
    } catch (err) {
      Log.e(TAG, "loadDataWithBaseUrl err = " + err);
    }
  }

  async loadUrl(instanceId: number, url: string, headers: Map<string, string>): Promise<void> {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    await webView.waitControllerAttached();
    try {
      if (url.startsWith("resources/rawfile/")) {
        webView.getController().loadUrl($rawfile(url.replace("resources/rawfile/","")), this.toWebHeaders(headers));
      }else {
        webView.getController().loadUrl(url, this.toWebHeaders(headers));
      }
      webView.setUrl(webView.getController().getUrl());
    } catch (err) {
      Log.e(TAG, "loadUrl err = " + err);
    }
  }

  toWebHeaders(headers: Map<string, string>): Array<web_webview.WebHeader> {
    let result: Array<web_webview.WebHeader> = new Array;
    if (headers == null || headers.size == 0) {
      return result;
    }
    for (let arr of headers) {
      let key = arr[0];
      let value = arr[1];
      let header: web_webview.WebHeader = { headerKey: key, headerValue: value };
      result.push(header);
    }
    return result;
  }

  async postUrl(instanceId: number, url: string, data: Uint8Array):  Promise<void> {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    await webView.waitControllerAttached();
    try {
      webView.getController().postUrl(url,data.buffer);
    } catch (err) {
      Log.e(TAG, "postUrl err = " + err);
    }
  }

  getUrl(instanceId: number): string {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getController().getUrl();
  }

  canGoBack(instanceId: number): boolean {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getController().accessBackward();
  }

  canGoForward(instanceId: number): boolean {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getController().accessForward();
  }

  goBack(instanceId: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().backward();
  }

  goForward(instanceId: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().forward();
  }

  reload(instanceId: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().refresh();
  }

  clearCache(instanceId: number, includeDiskFiles: boolean): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().removeCache(includeDiskFiles);
  }

  evaluateJavascript(instanceId: number, javascriptString: string, result: Result<string>): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().runJavaScript(javascriptString)
      .then(
        scriptResult => {
          result.success(scriptResult);
        }
      )
      .catch(
        (error: ESObject) => {
          result.error(error);
        }
      )
  }

  getTitle(instanceId: number): string {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getController().getTitle();
  }

  scrollTo(instanceId: number, x: number, y: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().scrollTo(x, y);
  }

  scrollBy(instanceId: number, x: number, y: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.getController().scrollBy(x, y);
  }

  getScrollX(instanceId: number): number {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getScrollX();
  }

  getScrollY(instanceId: number): number {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return webView.getScrollY()
  }

  getScrollPosition(instanceId: number): WebViewPoint {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    return WebViewPoint.Builder()
      .setX(webView.getScrollY())
      .setY(webView.getScrollY())
      .build();
  }

  setWebContentsDebuggingEnabled(enabled: boolean): void {
    this.webViewProxy.setWebContentsDebuggingEnabled(enabled);
  }

  setWebViewClient(instanceId: number, webViewClientInstanceId: number) {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.setWebViewClient(this.instanceManager.getInstance(webViewClientInstanceId));
  }

  async addJavaScriptChannel(instanceId: number, javaScriptChannelInstanceId: number): Promise<void> {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    const javaScriptChannel: JavaScriptChannel = this.instanceManager.getInstance(javaScriptChannelInstanceId);
    await webView.waitControllerAttached();
    try {
      webView.getController().registerJavaScriptProxy(
        {
          postMessage: (message: string) => {
            javaScriptChannel.postMessage(message)
          },
        },
        javaScriptChannel.getJavaScriptChannelName(),
        ["postMessage"]
      )
      webView.getController().refresh()
    } catch (err) {
      Log.e(TAG, "addJavaScriptChannel err = " + err);
    }
  }

  removeJavaScriptChannel(instanceId: number, javaScriptChannelInstanceId: number): void {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    const javaScriptChannel: JavaScriptChannel = this.instanceManager.getInstance(javaScriptChannelInstanceId);
    webView.getController().deleteJavaScriptRegister(javaScriptChannel.getJavaScriptChannelName());
  }

  setDownloadListener(instanceId: number, listenerInstanceId: number) {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.setDownloadListener(this.instanceManager.getInstance(listenerInstanceId));
  }

  setWebChromeClient(instanceId: number, clientInstanceId: number) {
    const webView: WebViewPlatformView = this.instanceManager.getInstance(instanceId);
    webView.setWebChromeClient(this.instanceManager.getInstance(clientInstanceId));
  }

  getInstanceManager(): InstanceManager {
    return this.instanceManager;
  }


  onScrollChangedImpl(left: number, top: number, oldLeft: number, oldTop: number) {
    this.onScrollChangedImpl(left, top, oldLeft, oldTop);
    this.api?.onScrollChanged(
        this, left, top, oldLeft, oldTop, {reply: () => {} });
  }

  setApi(api: WebViewFlutterApiImpl) {
    this.api = api;
  }
}

export class WebViewPlatformView extends PlatformView {

  private WebCookieManager: web_webview.WebCookieManager = new web_webview.WebCookieManager();

  private controller: web_webview.WebviewController = new web_webview.WebviewController();

  private tempUrl: string = "";

  private downloadListener: DownloadListener = {} as ESObject;

  private webChromeClient: WebChromeClient | null = null;

  private webViewClint: WebViewClient | null = null;

  private webSettings: WebSettings | null = null;

  private dialogController: CustomDialogController | null = null;

  private scrollX: number = 0;

  private scrollY: number = 0;

  private returnValueForShouldOverrideUrlLoading: boolean = false;

  private controllerAttached: boolean = false;

  private onDisposeCallback?: () => void;

  private rotation: number = 0;

  onDownloadStart = (event: ESObject) => {
    if (this.downloadListener && this.downloadListener.onDownloadStart) {
      this.downloadListener.onDownloadStart(
        event.url,
        event.userAgent,
        event.contentDisposition,
        event.mimetype,
        event.contentLength
      )
    }
  }

  onPageBegin = (event: ESObject) => {
    if (this.webViewClint) {
      this.webViewClint.onPageStarted(this, event.url);
    }
  }

  onPageEnd = (event: ESObject) => {
    if (this.webViewClint) {
      this.webViewClint.onPageFinished(this, event.url);
    }
  }

  onErrorReceive = (event: ESObject) => {
    if (this.webViewClint) {
      this.webViewClint.onReceivedError(this, event.request, event.error);
    }
  }

  onOverrideUrlLoading = (request: WebResourceRequest) => {
    Log.i(TAG, "onOverrideUrlLoading request = " + JSON.stringify(request))
    if(request.getRequestUrl() == 'loaded:///'){
      return true;
    }
    return false;
  }

  onRefreshAccessedHistory = (event: ESObject) => {
    if (this.webViewClint) {
      this.webViewClint.doUpdateVisitedHistory(this, event.url, event.isRefreshed);
    }
  }

  onProgressChange = (event: ESObject) => {
    if (this.webChromeClient) {
      this.webChromeClient.onProgressChanged(this, event.newProgress)
    }
  }

  onGeolocationShow = (event: ESObject) => {
    if (this.webChromeClient) {
      this.webChromeClient.onGeolocationPermissionsShowPrompt(event.origin, event.geolocation)
    }
  }

  onGeolocationHide = () => {
    if (this.webChromeClient) {
      this.webChromeClient.onGeolocationPermissionsHidePrompt();
    }
  }

  onShowFileSelector = (event: ESObject) => {
    if (this.webChromeClient) {
      return this.webChromeClient.onShowFileChooser(this, event.result, event.fileSelector)
    }
    return false;
  }

  onPermissionRequest = (event: ESObject) => {
    if (this.webChromeClient) {
      this.webChromeClient.onPermissionRequest(event.request);
    }
  }

  onConsoleMessage = (event: ESObject) => {
    let message:ConsoleMessage = event.message;
    if (message.getMessageLevel() == MessageLevel.Error || message.getMessageLevel() == MessageLevel.Warn) {
      if (this.webChromeClient) {
        this.webChromeClient.onConsoleMessage(event.message);
      }
    } else {
      Log.d(TAG, "logLevel: " + message.getMessageLevel() + " "+ message.getMessage());
    }
    return true;
  }

  onWindowNew = (event: ESObject) => {
    if (this.webChromeClient) {
      this.webChromeClient.onCreateWindow(this, event.isAlert, event.isUserTrigger, event.handler)
    }
  }

  onWindowExit = () => {
    if (this.dialogController) {
      this.dialogController.close();
    }
  }

  onScroll = (event: ESObject) => {
    this.scrollX = event.xOffset;
    this.scrollY = event.yOffset;
  }

  onControllerAttached = () => {
    Log.d(TAG, "onControllerAttached");
    this.controllerAttached = true
  }

  setOnDisposeCallback(callback: () => void) {
    this.onDisposeCallback = callback;
  }

  onJsAlert = (event: ESObject): boolean => {
    if (this.webChromeClient && event) {
      return this.webChromeClient.onJsAlert(this, event.url, event.message, event.result);
    }
    return true;
  }

  onJsConfirm = (event: ESObject): boolean => {
    if (this.webChromeClient && event) {
      return this.webChromeClient.onJsConfirm(this, event.url, event.message, event.result);
    }
    return true;
  }

  onJsPrompt = (event: ESObject): boolean => {
    if (this.webChromeClient && event) {
      return this.webChromeClient.onJsPrompt(this, event.url, event.message, event.value, event.result);
    }
    return true;
  }

  onFullScreenEnter = (event: ESObject) => {
    let context = getContext(this) as common.UIAbilityContext;
    let windowClass = context.windowStage.getMainWindowSync();
    windowClass.setWindowSystemBarEnable([]);
    this.rotation = windowClass.getPreferredOrientation();
    let orientation: number = display.getDefaultDisplaySync().orientation;
    let isAllowFullScreenRotate = this.getWebSettings()?.getAllowFullScreenRotate();
    if (isAllowFullScreenRotate && (orientation == display.Orientation.PORTRAIT || orientation == display.Orientation.PORTRAIT_INVERTED)) {
      windowClass.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }
  }

  onFullScreenExit = () => {
    let context = getContext(this) as common.UIAbilityContext;
    let windowClass = context.windowStage.getMainWindowSync();
    windowClass.setWindowSystemBarEnable(['status', 'navigation']);
    windowClass.setPreferredOrientation(this.rotation);
  }
  
  getType(): string {
    return 'web';
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(WebBuilder);
  }

  dispose(): void {
    this.controller.stopAllMedia();
    this.onDisposeCallback && this.onDisposeCallback();
  }

  getController(): web_webview.WebviewController {
    return this.controller;
  }

  setUrl(url: string): void {
    this.tempUrl = url;
  }

  getUrl(): string {
    return this.tempUrl;
  }

  getWebCookieManager(): web_webview.WebCookieManager {
    return this.WebCookieManager
  }

  setDownloadListener(listener: DownloadListener) {
    this.downloadListener = listener;
  }

  setWebViewClient(webViewClient: WebViewClient) {
    this.webViewClint = webViewClient;
  }

  setWebChromeClient(webChromeClient: WebChromeClient) {
    this.webChromeClient = webChromeClient;
  }

  setDialogController(dialogController: CustomDialogController) {
    this.dialogController = dialogController;
  }

  getDialogController(): CustomDialogController | null {
    return this.dialogController;
  }

  getWebSettings(): WebSettings {
    if (this.webSettings == null) {
      this.webSettings = new WebSettingsImpl(this);
    }
    return this.webSettings!;
  }

  getScrollX(): number {
    return this.scrollX;
  }

  getScrollY(): number {
    return this.scrollY;
  }

  setReturnValueForShouldOverrideUrlLoading(value: boolean) {
    this.returnValueForShouldOverrideUrlLoading = value;
  }

  async waitControllerAttached() {
    if (!this.controllerAttached) {
      await this.checkControllerAttached()
    }
  }

  checkControllerAttached(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        let intervalId = setInterval(() => {
          if (this.controllerAttached) {
            clearInterval(intervalId)
            resolve()
          }
        }, 20)
      } catch (err) {
        reject()
      }
    })
  }

}

export class WebViewProxy {
  createWebView(): WebViewPlatformView {
    return new WebViewPlatformView();
  }

  setWebContentsDebuggingEnabled(enabled: boolean): void {
    web_webview.WebviewController.setWebDebuggingAccess(enabled);
  }
}

class WebSettingsImpl implements WebSettings {
  private webView: WebViewPlatformView;
  params: DVModelParameters = new DVModelParameters;
  domStorageAccess: boolean = false;
  allowWindowOpenMethod : boolean = false;
  multiWindowAccess : boolean = false;
  backgroundColor : string = "";
  javaScriptAccess : boolean = false;
  mediaPlayGestureAccess : boolean = false;
  zoomAccess : boolean = true;
  overviewModeAccess : boolean = false;
  wideViewModeAccess: boolean = false;
  fileAccess : boolean = true;
  textZoomRatio : number = 0;
  textZoomRatioCallback?: (ratio: number) => void;
  isAllowFullScreenRotate: boolean = false;

  constructor(webView: WebViewPlatformView) {
    this.webView = webView;
    //this.params = webView.getView().params;
  }

  setDomStorageEnabled(flag: boolean) {
    this.domStorageAccess = flag;
  }

  getDomStorageEnabled() : boolean{
    return this.domStorageAccess;
  }

  setJavaScriptCanOpenWindowsAutomatically(flag: boolean) {
    this.allowWindowOpenMethod = flag;
  }

  getJavaScriptCanOpenWindowsAutomatically() : boolean{
    return this.allowWindowOpenMethod;
  }

  setSupportMultipleWindows(support: boolean) {
    this.multiWindowAccess = support;
  }

  getSupportMultipleWindows()  : boolean{
    return this.multiWindowAccess;
  }

  setBackgroundColor(color: number) {
    // number 无法实现透明度，所以转成 string
    let colorStr = `#${color.toString(16).padStart(8, '0')}`;
    this.backgroundColor = colorStr;
  }

  getBackgroundColor() : string{
    return this.backgroundColor;
  }

  setJavaScriptEnabled(flag: boolean) {
    this.javaScriptAccess = flag;
  }

  getJavaScriptEnabled() : boolean {
    return this.javaScriptAccess;
  }

  async setUserAgentString(userAgentString: string) {
    await this.webView.waitControllerAttached();
    this.webView.getController().setCustomUserAgent(userAgentString);
    // 解决webview无法返回首页的问题，参考文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs-V5/faqs-arkweb-88-V5
    this.webView.getController().loadUrl(this.webView.getUrl())
  }

  setMediaPlaybackRequiresUserGesture(require: boolean) {
    this.mediaPlayGestureAccess = require;
  }

  getMediaPlaybackRequiresUserGesture() : boolean{
    return this.mediaPlayGestureAccess;
  }

  setSupportZoom(support: boolean) {
    this.zoomAccess = support;
  }

  getSupportZoom() : boolean{
    return this.zoomAccess;
  }

  setLoadWithOverviewMode(overview: boolean) {
    this.overviewModeAccess = overview;
  }

  getLoadWithOverviewMode() : boolean {
    return this.overviewModeAccess;
  }

  setUseWideViewPort(use: boolean) {
    this.wideViewModeAccess = use;
  }

  getUseWideViewPort() : boolean {
    return this.wideViewModeAccess;
  }

  setDisplayZoomControls(enabled: boolean) {
    //TODO:确认是否支持
  }

  setBuiltInZoomControls(enabled: boolean) {
    //TODO:确认是否支持
  }

  setAllowFileAccess(enabled: boolean) {
    this.fileAccess = enabled;
  }

  getAllowFileAccess() : boolean {
    return this.fileAccess;
  }

  setTextZoom(textZoom: number) {
    this.textZoomRatio = textZoom;
    this.textZoomRatioCallback && this.textZoomRatioCallback(textZoom);
  }

   async getUserAgentString(): Promise<string> {
    await this.webView.waitControllerAttached();
    return this.webView.getController().getCustomUserAgent();
  }

  getTextZoom() : number{
    return this.textZoomRatio;
  }

  onTextZoomChanged(callback: (ratio: number) => void): void {
    this.textZoomRatioCallback = callback;
  }

  setAllowFullScreenRotate(enabled: boolean) {
    this.isAllowFullScreenRotate = enabled;
  }

  getAllowFullScreenRotate() : boolean {
    return this.isAllowFullScreenRotate;
  }
}