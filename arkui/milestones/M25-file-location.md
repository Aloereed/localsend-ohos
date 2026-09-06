# M25 · 文件所在目录

文件详情增加“所在文件夹”，沿用 Flutter 版本的鸿蒙文件管理器 Ability 和 `file://docs` 公共文档地址。优先定位另存副本，正确处理中文、空格和 `#`；应用内私有目录继续提供另存为，不展示无法浏览的路径入口。

验证：公共路径、URI 编码、另存副本与私有路径排除测试通过，ArkUI 未签名 debug 构建通过。系统文件管理器的最终定位行为需真机确认。

产物：`artifacts/AloeSend-2000025-M25-file-location-unsigned.hap`。
