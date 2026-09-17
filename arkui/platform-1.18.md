# LocalSend 1.18 平台功能在鸿蒙端的对应方式

本次交付是当前项目的原生 HarmonyOS HAP/APP。上游来源固定为 [LocalSend v1.18.2](https://github.com/localsend/localsend/tree/v1.18.2)。以下逐项区分应用功能与操作系统专属打包/集成，避免将其他系统的可执行文件或桌面接口声称已包含在鸿蒙包中。

| 上游平台功能 | 鸿蒙对应与验证 |
| --- | --- |
| Android 快捷设置磁贴启动应用 | 提供系统桌面快捷操作“发送文件”“通过链接收发”，直接打开对应页面。声明使用 SDK `modulecheck/shortcuts.json` 的 wants/parameters 格式和 `ohos.ability.shortcuts` 元数据；HAP 编译检查通过。不是 Android TileService。 |
| Windows 系统分享、macOS Dock 文本拖入（含未启动） | 已注册系统 sendData 文本/链接/文件，EntryAbility 冷/热启动统一处理。启动前隐私未确认时排队；incoming-share 与 launch-118 测试验证数据及队列。 |
| CLI / GUI --text、-t 启动传入文字 | 提供 HarmonyOS Want 参数 `aloesend.text`，加入发送清单并打开发送页；不自动向陌生设备发送。冷/热启动和 UTF-8 字节长度测试通过。官方独立桌面 CLI 二进制不作为本 HAP 的子程序分发。 |
| Android 后台传输 | 使用 DATA_TRANSFER 后台任务；传输与校验和计算阶段均申请，取消/完成后释放，ScreenKeeper 配合前台状态释放亮屏。 |
| 桌面自定义网页目录 | 鸿蒙沙箱改为文件选择器导入、导出和恢复，见 web-template.md；模板持久化且复用服务端接收确认。 |
| macOS ComputerName | 鸿蒙名称读取 marketName/productModel，并可编辑名称；不读取 macOS 主机名。 |
| macOS Command+Comma、Dock、打开 macOS 防火墙；Linux GTK 装饰 | 属于对应系统 shell/window manager 集成，鸿蒙包不使用 AppKit、Dock、GTK 或 macOS 防火墙设置。本应用保留原生设置入口、诊断页和 ArkUI 窗口。 |
| Windows CLI 版本信息、Linux AppImage 版本 | 属于 EXE/AppImage 产物元数据，鸿蒙使用 AppScope versionName/versionCode 和签名 HAP/APP 元数据。不会在鸿蒙产物中生成无用的 EXE/AppImage。 |

开发调试时可用当前设备的 hdc/aa 启动工具传入文字（设备须已安装应用并允许调试）：

```powershell
hdc shell aa start -a EntryAbility -b com.aloereed.aloesend --ps aloesend.text "Hello"
```

其他 HarmonyOS 应用也可通过显式 Want 的 parameters 传递同一字符串。`aloesend.route` 只接受 `send` 或 `web`，不会按任意参数执行代码、文件操作或自动开始传输。

主机测试和 SDK 编译验证了实现与声明。桌面是否显示快捷操作、系统分享面板和屏幕视觉效果仍依赖具体 HarmonyOS 设备，未将模拟环境测试声称为真机测试。
