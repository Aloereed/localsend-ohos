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

import { FlutterAbility, FlutterEngine } from "@ohos/flutter_ohos"
import { GeneratedPluginRegistrant } from "../plugins/GeneratedPluginRegistrant"
import DownloadPlugin from "./DownloadPlugin"
import { AbilityConstant, UIAbility, Want } from "@kit.AbilityKit"
import { systemShare } from "@kit.ShareKit"
import { BusinessError } from "@kit.BasicServicesKit"
import { fileIo as fs, ReadOptions } from "@kit.CoreFileKit"
import { buffer } from "@kit.ArkTS"
import { common } from "@kit.AbilityKit"
import util from '@ohos.util';
function createFile(openuri: string): void {
    // 文件不存在时创建并打开文件，文件存在时打开文件
    try{
        fs.unlinkSync("/data/storage/el2/base/openuri.txt");
    }catch (e){
        console.info("file not exist")
    }
    let file = fs.openSync(
        "/data/storage/el2/base/openuri.txt",
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE
    )
    // 写入一段内容至文件
    let writeLen = fs.writeSync(file.fd, openuri)
    console.info("The length of str is: " + writeLen)
    // 创建一个大小为1024字节的ArrayBuffer对象，用于存储从文件中读取的数据
    let arrayBuffer = new ArrayBuffer(1024)
    // 设置读取的偏移量和长度
    let readOptions: ReadOptions = {
        offset: 0,
        length: arrayBuffer.byteLength,
    }
    // 读取文件内容到ArrayBuffer对象中，并返回实际读取的字节数
    let readLen = fs.readSync(file.fd, arrayBuffer, readOptions)
    // 将ArrayBuffer对象转换为Buffer对象，并转换为字符串输出
    let buf = buffer.from(arrayBuffer, 0, readLen)
    console.info("the content of file: " + buf.toString())
    // 关闭文件
    fs.closeSync(file)
}
function urlDecodeManual(encodedString: string): string {
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
    return decodeUTF8(result);
  }

function decodeUTF8(utf8String: string): string {
    const utf8Bytes = new Uint8Array(utf8String.length);
    for (let i = 0; i < utf8String.length; i++) {
      utf8Bytes[i] = utf8String.charCodeAt(i);
    }
    return new util.TextDecoder().decodeToString(utf8Bytes);
  }

function copyFileWithReadable(fromUri: string): string {
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
        return ""
    }
    let writeFile: fs.File
    try {
        // filename从uri转路径

        writeFile = fs.openSync(
            `/data/storage/el2/base/cache/${urlDecodeManual(filename)}`,
            fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE
        )
        console.info("open output file success")
    } catch (e) {
        console.error(`open output file failed: ${e}`)
        return ""
    }
    fs.copyFileSync(readFile.fd, writeFile.fd)
    console.info("COPY DONE")
    return `file://docs/data/storage/el2/base/cache/${filename}`
}
export default class EntryAbility extends FlutterAbility {
    private myDownloadPlugin?: DownloadPlugin
    configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        this.myDownloadPlugin = new DownloadPlugin()
        this.addPlugin(this.myDownloadPlugin)
    }
    onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
        systemShare
            .getSharedData(want)
            .then((data: systemShare.SharedData) => {
                data.getRecords().forEach(
                    (record: systemShare.SharedRecord) => {
                        // 处理分享数据
                        let uri = record.uri
                        if (uri == null || uri == undefined) {
                            console.info("The length of str")
                            return
                        } else {
                            console.info("share uri:" + uri)
                            // 如果uri的第8到11个字符不是“docs”或“medi”，则复制
                            if (
                                uri.substring(7, 11) != "docs" &&
                                uri.substring(7, 11) != "medi"
                            ) {
                                uri = copyFileWithReadable(uri)
                            }
                            this.myDownloadPlugin?.sendWant(uri)
                        }
                    }
                )
            })
            .catch((error: BusinessError) => {
                console.error(
                    `Failed to getSharedData. Code: ${error.code}, message: ${error.message}`
                )
            })
    }
    async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
        try{
            fs.unlinkSync("/data/storage/el2/base/openuri.txt");
        }catch (e){
            console.info("file not exist")
        }
        let alluri = ""
        systemShare
            .getSharedData(want)
            .then((data: systemShare.SharedData) => {
                const alluri = data
                    .getRecords()
                    .map((record: systemShare.SharedRecord) => {
                        let uri = record.uri
                        // 如果uri的第8到11个字符不是“docs”或“medi”，则复制
                        // if (
                        //     uri &&
                        //     uri.substring(7, 11) !== "docs" &&
                        //     uri.substring(7, 11) !== "medi"
                        // ) {
                        //     uri = copyFileWithReadable(uri)
                        // }
                        // if(uri != null && uri !== undefined)
                        //     this.myDownloadPlugin?.sendWant(uri)
                        return uri
                    })
                    .filter((uri) => uri != null && uri !== undefined)
                    .join("\n")
                if (alluri) {
                    console.info("alluri:" + alluri)
                    createFile(alluri)
                }
            })
            .catch((error: BusinessError) => {
                console.error(
                    `Failed to getSharedData. Code: ${error.code}, message: ${error.message}`
                )
                // this.context.terminateSelf()
            })
            await super.onCreate(want, launchParam)
    }
}
