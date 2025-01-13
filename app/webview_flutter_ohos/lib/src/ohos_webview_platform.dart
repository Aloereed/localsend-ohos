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

import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'ohos_webview_controller.dart';
import 'ohos_webview_cookie_manager.dart';

/// Implementation of [WebViewPlatform] using the WebKit API.
class OhosWebViewPlatform extends WebViewPlatform {
  /// Registers this class as the default instance of [WebViewPlatform].
  static void registerWith() {
    WebViewPlatform.instance = OhosWebViewPlatform();
  }

  @override
  OhosWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return OhosWebViewController(params);
  }

  @override
  OhosNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return OhosNavigationDelegate(params);
  }

  @override
  OhosWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return OhosWebViewWidget(params);
  }

  @override
  OhosWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return OhosWebViewCookieManager(params);
  }
}
