# M59 · Flutter 语言资源与地区识别

从 Flutter 实际运行的 `lib/gen/strings_*.g.dart` 提取 53 个语言/地区变体的静态文案，保留英文继承和 `_root` 引用。解析按类关系确定路径，不依赖已有错位的 Path 注释；新增消息文案与 AloeSend 品牌取运行时文件，不取内容较旧的 assets JSON。

原生语言选择接入上述 53 个变体及跟随系统，目前明确映射 61 条公共文案。地区、脚本和下划线格式可归一化，例如 zh-Hant-HK、sr_Cyrl_RS、en-US。阿拉伯语、波斯语、希伯来语和乌尔都语启用根布局从右向左方向。隐私政策沿用 Flutter 的中文/英文选择规则，其他语言的网页分享使用现有英文版本。

**翻译覆盖尚未完成。** 原生新增说明使用现有英文回退，设置页明确提示。语言选项存在不等于全部页面已完成翻译；后续继续审查映射和语言界面。RTL 也仅完成基础方向设置，仍需检查方向图标、弹层及实际排版。

## 验证

- 53 个唯一语言变体、英文继承、间接引用、Unicode/引号转义、错误引用及生成文件同步测试通过。
- 测试德语未覆盖的新增消息使用英文、中文消息与发送分类不被错位注释混淆、实际品牌名称、地区/脚本回退、系统语言和 RTL 判断。
- 全部 34 个主机测试文件通过，ArkTS 与未签名 HAP 构建成功，未访问设备。
- 同步命令：`node arkui/sync-locales.cjs`；检查命令：`node arkui/sync-locales.cjs --check`。映射见 `flutter-locale-keys.json`。

产物：`artifacts/AloeSend-2000059-M59-flutter-locales-unsigned.hap`，版本 `2.0.59`。

SHA-256：`B2ABB04DE317C926F498369D1ABED7B2B2C4018BF4282D28F728B1303AD32A22`。
