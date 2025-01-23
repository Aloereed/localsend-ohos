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

import { FlutterAssetManager } from './FlutterAssetManager';
import { FlutterAssetManagerHostApi } from './GeneratedOhosWebView';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG:string = "FlutterAssetManagerHostApiImpl"
export class FlutterAssetManagerHostApiImpl extends FlutterAssetManagerHostApi {
  private flutterAssetManager: FlutterAssetManager;

  constructor(flutterAssetManager: FlutterAssetManager) {
    super()
    this.flutterAssetManager = flutterAssetManager;
  }

  async list(path: string): Promise<string[]> {
    try {
      let paths: string[] = await this.flutterAssetManager.list(path);
      if (paths.length == 0) {
        return [];
      }
      return paths;
    } catch (err) {
      Log.e(TAG, "mkdirSync failed err:" + err);
    }
    return [];
  }

  getAssetFilePathByName(name: string): string {
    return this.flutterAssetManager.getAssetFilePathByName(name)
  }
}

