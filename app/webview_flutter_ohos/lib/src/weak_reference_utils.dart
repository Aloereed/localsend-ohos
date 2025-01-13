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

/// Helper method for creating callbacks methods with a weak reference.
///
/// Example:
/// ```
/// final JavascriptChannelRegistry javascriptChannelRegistry = ...
///
/// final WKScriptMessageHandler handler = WKScriptMessageHandler(
///   didReceiveScriptMessage: withWeakReferenceTo(
///     javascriptChannelRegistry,
///     (WeakReference<JavascriptChannelRegistry> weakReference) {
///       return (
///         WKUserContentController userContentController,
///         WKScriptMessage message,
///       ) {
///         weakReference.target?.onJavascriptChannelMessage(
///           message.name,
///           message.body!.toString(),
///         );
///       };
///     },
///   ),
/// );
/// ```
S withWeakReferenceTo<T extends Object, S extends Object>(
  T reference,
  S Function(WeakReference<T> weakReference) onCreate,
) {
  final WeakReference<T> weakReference = WeakReference<T>(reference);
  return onCreate(weakReference);
}
