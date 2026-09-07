# M131 · 旧版本文案、999 项选择与浮动底栏缩放

设置入口、导入确认框、结果摘要和失败提示不再向用户展示 Flutter 实现名称，统一称“旧版本”；英文映射同步调整。语言菜单 zh-TW 显示“繁體中文”，保留语言标识和实际翻译，并在同步脚本中明确覆盖名称，重新生成不会恢复地区后缀。Flutter 原版资源未改。

文件选择和消息文件附件 maxSelectNumber 从 100 提升为 999，文件夹仍单选。官方最新文档说明 DocumentSelectOptions 从 API 21 起不限制单次数量，本应用最低 API 22；本地 SDK 注释中的 500 尚未更新。图库 PhotoViewPicker 仍有单次 500 上限，因此不传无效的 999：一批选满时可选择“继续选择”，下一批最大 499，单轮累计到 999。消息图片附件使用相同流程，去重、提前完成、取消下一批、原清单原子保留均覆盖测试。

参考：[华为 Picker API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker)。

原生 HDS 底栏此前使用固定宽屏档位和百分比窄屏宽度，窗口变小时没有应用侧几何参数更新。现在依据实际窗口区域宽度重新计算栏宽（最大 520 vp）和居中间距，三种系统档位均接收当前数值；明确关闭偏手适配。兼容底栏复用同一几何计算，容器裁剪限制背景绘制范围。窗口变化不重建页面或重置选中标签、草稿。该改动针对背景偏移；不能仅凭主机计算测试证明系统玻璃渲染已修复，实际缩放待设备确认。

六个针对性测试文件通过：selection-limits、selection-atomic、flutter-settings、flutter-locales、privacy、immersive-window。覆盖 999 文件/附件，图库 500+499、取消/重复/原子性、语言同步、旧设置继承、隐私启动及系统栏逻辑；几何序列跨越 1440、840、600、440、390、320、280 vp 等宽度并确认始终居中且不越界。M130 网络代码没有改变，其 60 文件回归和 HTTP/HTTPS 各 3 GiB 测试仍为网络证据。

鸿蒙编译通过，版本 2.0.131 / 2000131。调试归档 `artifacts/AloeSend-2000131-M131-selection-layout-unsigned.hap`，SHA-256 `2246EAD4562753A1B3645EBE7C1E65ABC841F1780B09B655DD6131E6C88D182C`。发布包沿用 Flutter release 身份。未访问设备。用户追加明确要求移除 INTERNET，已从模块清单删除，发布脚本改为要求最终模块不含 INTERNET、READ_PASTEBOARD、FILE_ACCESS_PERSIST。最终只保留 GET_NETWORK_INFO 和 KEEP_BACKGROUND_RUNNING。本轮未验证鸿蒙无 INTERNET 权限时的网络行为。
