
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

import {
  Any,
  BasicMessageChannel,
  EventChannel,
  FlutterManager,
  FlutterPlugin,
  Log,
  MethodCall,
  MethodChannel,
  StandardMessageCodec
} from '@ohos/flutter_ohos';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, ReadOptions } from "@kit.CoreFileKit"
import { common , Want } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import util from '@ohos.util';
const TAG = "DownloadPluginTag";

export default class DownloadPlugin implements FlutterPlugin {
  private channel?: MethodChannel;
  private eventSink?: EventSink;
  private eventChannel?: EventChannel;
  private api = new DownloadApi();
  sendWant(uri:string): void {
    if(this.eventSink){
      this.eventSink.success(uri);
    }
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "samples.flutter.dev/downloadplugin");
    let that = this;
    this.channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        switch (call.method) {
          case "getDownloadPermission":
            that.api.getDownloadPermission(result);
            break;
          case "openFileManager":
            that.api.openFileManager(result,call.argument("uri") as string);
            break;
          case "startContinuousTask":
            that.api.startContinuousTask(result);
            break;
          case "stopContinuousTask":
            that.api.stopContinuousTask(result);
            break;
          case "copyFileWithReadable":
            that.api.copyFileWithReadable(call.argument("uri") as string, result);
            break;
          case "callEvent":
            that.eventSink?.success("Success at " + new Date());
            break;
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    })
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), "com.example.app/events");
    this.eventChannel.setStreamHandler({
      onListen(args: Any, events: EventSink): void {
        that.eventSink = events; // 将 events 赋值给外部的 eventSink
        Log.i(TAG, "onListen: " + args);
      },
      onCancel(args: Any): void {
        that.eventSink = undefined; // 取消 eventSink
        Log.i(TAG, "onCancel: " + args);
      }
    });

  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    Log.i(TAG, "onDetachedFromEngine");
    this.channel?.setMethodCallHandler(null);

  }

  getUniqueClassName(): string {
    return "DownloadPlugin";
  }
}

class DownloadApi {
  getDownloadPermission(result: MethodResult) {
    // // 创建文件管理器选项实例
    // const documentSaveOptions = new picker.DocumentSaveOptions();
    // // 配置保存的模式为DOWNLOAD，若配置了DOWNLOAD模式，此时配置的其他documentSaveOptions参数将不会生效。
    // documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD; 
    let uri: string = '';
    // 请确保 getContext(this) 返回结果为 UIAbilityContext
    let context = getContext(this) as common.UIAbilityContext; 
    const documentViewPicker = new picker.DocumentViewPicker(context);
    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
    documentViewPicker.save(documentSaveOptions ).then((documentSaveResult: Array<string>) => {
    uri = documentSaveResult[0];
    console.info('documentViewPicker.save succeed and uri is:' + uri);
    }).catch((err: BusinessError) => {
    console.error(`Invoke documentViewPicker.save failed, code is ${err.code}, message is ${err.message}`);
    })
    Log.i(TAG, "level=" + uri);
    let wrapped: Map<String, Any> = new Map<String, Any>();
    if (uri != null) {
      result.success(uri);
    } else {
      Log.i(TAG, "getDownloadPermission else");
      wrapped.set("UNAVAILABLE", "Download level not available.");
      result.error("UNAVAILABLE", "Download level not available.", null)
    }
    Log.i(TAG, "getDownloadPermission finish");
  }
  startContinuousTask(result: MethodResult) {
    console.info("start a continuous task")
    let context = getContext(this) as common.UIAbilityContext; 
     let wantAgentInfo: wantAgent.WantAgentInfo = {
       // 点击通知后，将要执行的动作列表
       // 添加需要被拉起应用的bundleName和abilityName
       wants: [
         {
           bundleName: "com.aloereed.aloechatai",
           abilityName: "EntryAbility"
         }
       ],
       // 指定点击通知栏消息后的动作是拉起ability
       actionType: wantAgent.OperationType.START_ABILITY,
       // 使用者自定义的一个私有值
       requestCode: 0,
       // 点击通知后，动作执行属性
       actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
     };

     // 通过wantAgent模块下getWantAgent方法获取WantAgent对象
     wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
       backgroundTaskManager.startBackgroundRunning(context,
         backgroundTaskManager.BackgroundMode.DATA_TRANSFER, wantAgentObj).then(() => {
         // 此处执行具体的长时任务逻辑，如放音等。
         result.success("Success at " + new Date());
         console.info(`Succeeded in operationing startBackgroundRunning.`);
       }).catch((err: BusinessError) => {
         result.success("UNAVAILABLE")
         console.error(`Failed to operation startBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
       });
     });
   }

   stopContinuousTask(result: MethodResult) {
    let context = getContext(this) as common.UIAbilityContext; 
      backgroundTaskManager.stopBackgroundRunning(context).then(() => {
        result.success("Success at " + new Date());
        console.info(`Succeeded in operationing stopBackgroundRunning.`);
      }).catch((err: BusinessError) => {
        result.success("UNAVAILABLE")
        console.error(`Failed to operation stopBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
      });
   }
  openFileManager(result: MethodResult, fileUri: string) {
    let context = getContext(this) as common.UIAbilityContext;
    let uri = 'Open FE.';
    // 创建一个Want对象，用于描述启动系统文件管理器的意图
    let want: Want = {
      // 设置系统文件管理器的包名
      bundleName: 'com.huawei.hmos.filemanager',
      // 设置系统文件管理器的主Ability名称
      abilityName: 'MainAbility',
      parameters: {
        'fileUri': fileUri
      }
    };
    context.startAbility(want);
    let wrapped: Map<String, Any> = new Map<String, Any>();
    if (uri != null) {
      result.success(uri);
    } else {
      Log.i(TAG, "openFileManager else");
      wrapped.set("UNAVAILABLE", "Download level not available.");
      result.error("UNAVAILABLE", "Download level not available.", null)
    }
    Log.i(TAG, "openFileManager finish");
  }
urlDecodeManual(encodedString: string): string {
    let result = '';
    let i = 0;
    while (i < encodedString.length) {
      const char = encodedString[i];
      if (char === '%') {
        // 提取 %XX 形式的子字符串
        const hexCode = encodedString.substring(i + 1, i + 3);
        const byte = parseInt(hexCode, 16);
        // 将字节转换为字符
        result += String.fromCharCode(byte);
        // 跳过已经处理的三个字符
        i += 3;
      } else {
        // 直接添加普通字符
        result += char;
        i++;
      }
    }
    // 将结果从 UTF-8 编码转换为字符串
    return this.decodeUTF8(result);
  }
  decodeUTF8(utf8String: string): string {
    const utf8Bytes = new Uint8Array(utf8String.length);
    for (let i = 0; i < utf8String.length; i++) {
      utf8Bytes[i] = utf8String.charCodeAt(i);
    }
    return new util.TextDecoder().decodeToString(utf8Bytes);
  }

  copyFileWithReadable(fromUri: string,result: MethodResult) {
    // 创建文件可读流
    console.info("start copy")
    let filename = fromUri.split("/").pop()
    console.info(`file://docs/data/storage/el2/base/cache/${filename}`)
    // 创建文件可写流
    // 暂停模式拷贝文件。在拷贝数据时，将原始数据暂停，然后将数据复制到另一个位置，适用于对数据完整性和一致性要求较高的场景
    let readFile: fs.File
    try {
        readFile = fs.openSync(fromUri, fs.OpenMode.READ_ONLY)
        console.info("open file success")
    } catch (e) {
        console.error("open file failed")
        result.success("")
        return
    }
    let writeFile: fs.File
    try {
        // filename从uri转路径

        writeFile = fs.openSync(
            `/data/storage/el2/base/cache/${this.urlDecodeManual(filename)}`,
            fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE
        )
        console.info("open output file success")
    } catch (e) {
        console.error(`open output file failed: ${e}`)
        result.success("")
        return
    }
    fs.copyFileSync(readFile.fd, writeFile.fd)
    console.info("COPY DONE")
    result.success(`file://docs/data/storage/el2/base/cache/${filename}`)
}
}