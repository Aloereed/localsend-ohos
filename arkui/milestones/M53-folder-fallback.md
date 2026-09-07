# M53 · 文件夹选择的运行时兼容

保留 Flutter 版的 `Download/com.aloereed.aloesend` 自定义文件夹选择流程。当设备缺少 FolderSelection 能力，或系统选择器实际返回 801（能力不支持）时，使用同一下载目录选择器。系统取消返回空列表时直接结束；其他错误继续显示，普通文件选择不会错误地跳到目录选择。

选择后先读取全部文件元数据，再一次性更新发送清单；重复选择不重复添加，目录边界和授权检查沿用 M47。

依据：Flutter `app/lib/util/native/pick_directory_path.dart`；[华为文件选择器文档](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker) 中 FOLDER 所需的 FolderSelection 能力。

验证：文件夹专项覆盖能力缺失、运行时 801、系统取消、权限错误、普通文件错误、子目录与中文名、去重、空目录、授权拒绝和目录越界；全部通过。ArkTS 编译成功。累计传输部分已在 M52 通过全部 29 个主机测试文件，本里程碑只修改文件夹选择流程。未访问用户设备。

产物：`artifacts/AloeSend-2000053-M53-folder-fallback-unsigned.hap`，版本 `2.0.53`。

SHA-256：`9D7B6781AE2C22D3F9425637088A3073A715B57F3FEEF453B1E92537DEF39FB8`。
