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

import resourceManager from '@ohos.resourceManager';
import { FlutterAssets } from "@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin"

export abstract class FlutterAssetManager {
  private resourceManager: resourceManager.ResourceManager;

  constructor(resourceManager: resourceManager.ResourceManager) {
    this.resourceManager = resourceManager;
  }

  abstract getAssetFilePathByName(name: string)

  async list(path: string): Promise<string[]> {
    return await this.resourceManager.getRawFileList(path);
  }
}

export class PluginBindingFlutterAssetManager extends FlutterAssetManager {
  flutterAssets: FlutterAssets;

  constructor(resourceManager: resourceManager.ResourceManager, flutterAssets: FlutterAssets) {
    super(resourceManager);
    this.flutterAssets = flutterAssets;
  }

  getAssetFilePathByName(name: string): string {
    return this.flutterAssets.getAssetFilePathByName(name);
  }
}