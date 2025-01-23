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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Proxy that provides access to the platform views service.
///
/// This service allows creating and controlling platform-specific views.
@immutable
class PlatformViewsServiceProxy {
  /// Constructs a [PlatformViewsServiceProxy].
  const PlatformViewsServiceProxy();

  /// Proxy method for [PlatformViewsService.initExpensiveAndroidView].
  ExpensiveOhosViewController initExpensiveOhosView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    return PlatformViewsService.initExpensiveOhosView(
      id: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
      onFocus: onFocus,
    );
  }

  /// Proxy method for [PlatformViewsService.initSurfaceAndroidView].
  SurfaceOhosViewController initSurfaceOhosView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    return PlatformViewsService.initSurfaceOhosView(
      id: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
      onFocus: onFocus,
    );
  }
}
