# M58 · Flutter 主题预设的原生配色

设置增加系统配色、AloeSend、OLED、Yaru 和自定义颜色。AloeSend 原始主色 `#34C759` 来自 Flutter `config/theme.dart`；Yaru 橙色、浅色背景与深色表面取自仓库内的 Yaru 主题资源。控件和导航继续使用鸿蒙原生实现。

系统配色读取系统 `sys.color.brand`，配置变化时刷新；资源不可用时保留最近的有效值。OLED 在深色下使用纯黑背景与内容表面，浅色保持可读。五个原生自定义颜色继续可选，切换预设不覆盖用户的自定义值。旧原生配置缺少预设字段时按自定义模式读取，保留升级前颜色；新安装默认 AloeSend。

文字、按钮、开关和进度使用经过对比度调整的有效颜色；浏览器分享同步当前主题色。预设不会修改动画或轻量效果选择。

验证：主题专项检查所有预设的文字及白色按钮标签对比度、系统颜色变化、OLED 深浅色、Yaru 色值、自定义值保留、重启和旧设置升级。全部 33 个主机测试文件通过；ArkTS 系统资源和未签名包编译成功。实际系统色与材质显示待用户设备检查，本轮未访问设备。

系统色使用依据：[华为 Navigation 文档的系统 brand 颜色示例](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/api/ts-basic-components-navigation)。系统配色遵循鸿蒙资源，不声称实现 Android 壁纸动态色算法。

产物：`artifacts/AloeSend-2000058-M58-theme-presets-unsigned.hap`，版本 `2.0.58`。

SHA-256：`69600A6B710983656824119F1BAC6CA90E07838D6FE3548B0B7203BE01882C97`。
