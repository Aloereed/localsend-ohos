# LocalSend 1.18 功能对齐清单

目标：将 LocalSend 从 1.18 开始引入的新功能补到当前原生鸿蒙应用。基线为 2026-09-11 查询的最新正式版 v1.18.2；不以部分测试通过代替全部完成。

官方来源：[更新记录](https://localsend.org/changelog)、[v1.18.2 源码](https://github.com/localsend/localsend/tree/v1.18.2)。对照用的官方源码下载到忽略目录 `logs/upstream-1.18.2/`。

用户后续约束：默认只跟进原版的简体中文、繁体中文和英文本地化；其他功能与语言变更除非用户明确要求，不再主动同步原版。此前已导入的语言保留。

| 功能 | 当前证据 / 尚待工作 |
| --- | --- |
| 通过链接接收 | 已核查 SendView 无文件也可进入，WebShareView 无文件也可启动；web 集成 9 组涵盖 PIN、同意、上传、停用，web-page 验证消息/取消/失败保留，空文件页面 HTTP/HTTPS 通过 |
| 浏览器收件页面拖放（1.18.2） | 补递归目录与普通文件混选、多批目录枚举、路径保留、取消及失败时保留原选择；生成脚本行为测试通过 |
| 自定义颜色取色器 | 已补 RGB 全范围滑块、十六进制输入、预览、应用/取消；颜色值与对比度主机测试通过，真机交互待验证 |
| IPv6 | M138 发现/接收双栈；本轮补网页 HTTP/HTTPS 双栈监听、IPv6 方括号链接、从未过滤网卡获取 IPv6 和单协议族绑定失败回退，web-ipv6 通过 |
| 默认开启校验和生成与验证 | 已补 sha256 发送/接收、分块计算、进度/取消、两项独立设置及 422 最多三次上传；file-checksum、service 集成及回归验证通过，真机互操作待验证 |
| 默认自动接收收藏设备文件 | 新默认 true，保留已保存的 false；favorite-autoaccept 实际 HTTPS 测试验证身份匹配后自动接收、关闭选项后要求同意 |
| 十进制大小单位 | formatSize 使用 1000，补至 TB/PB；size-units 验证各单位边界 |
| 长传输剩余时间 | 已支持 mm:ss、h:mm:ss、天+h:mm:ss；59/60 分钟及 24 小时边界测试通过 |
| 重复文件命名 file (1).txt | 接收命名、下载目录及自定义目录导出均避让，隐藏文件无错误扩展名拆分；size-units/download-directory/receive-names 通过 |
| 初次启动尊重系统动画偏好 | API 23 使用 accessibility.isAnimationReduceEnabled，旧系统读取 ANIMATOR_DURATION_SCALE；仅初始化缺失的动画选项并持久化，保留手动设置。新旧 API 与失败回退测试通过 |
| 后台文件传输 | DATA_TRANSFER 覆盖传输与校验和计算；launch-118 验证计算及取消活动状态，screen-keeper 验证亮屏释放 |
| 快速启动入口 | 鸿蒙桌面快捷操作“发送文件”“通过链接收发”及路由参数，SDK schema/编译验证；系统差异见 platform-1.18.md |
| 系统分享菜单与未启动时接收文字 | sendData 声明、文件/文本导入、冷/热启动与隐私队列由 incoming-share/launch-118 验证 |
| 桌面 CLI 与 --text/-t | 鸿蒙通过 Want 的 aloesend.text 启动传参加入发送清单；独立桌面 CLI 不在 HAP 中分发，完整平台映射见 platform-1.18.md |
| 桌面网页模板覆盖（1.18.2） | 已提供鸿蒙系统选择器导入/导出、应用内持久化与恢复默认；本端合并收发页面由单模板覆盖，真实 HTTP 与文件失败保留测试通过，见 web-template.md |
| 平台专属增强 | platform-1.18.md 逐项记录 macOS/Windows/Linux 专属接口和产物的适用边界；鸿蒙使用自己的窗口、系统分享、名称、诊断和包版本 |
| 新增语言 | 已导入 1.18.1 白俄罗斯语、爱尔兰语及 1.18.2 亚美尼亚语原始资源；56 种语言静态/动态文案、搜索、区域码与浏览器选择测试通过 |

同时回归更新中的通用修复：不跟随对端重定向、不使用系统代理、监听和发现恢复、旧版收藏互操作、多文件流畅性、完成释放亮屏、文本字节长度与消息展示、媒体格式保存回退。它们不替代上述新功能。

当前结论：面向本项目 HarmonyOS HAP/APP 的新增功能实现及主机/SDK 验证完成。操作系统专属功能按 platform-1.18.md 明确对应与不适用范围；未声称提供 Windows/macOS/Linux 可执行程序，也未声称已完成鸿蒙真机测试。以下阶段记录保留历史，其中旧待办以本表及最终验收为准。

## 第一阶段证据（M140 工作中）

- 官方 `packages/core/src/model/transfer.rs` 定义 `sha256`；`http/server/v2.rs` 校验失败返回 422，并限制上传尝试为 3 次。
- 本端对官方字段优先验证，同时保留历史 `hash` 字段兼容。校验失败删除部分文件，不写成功路径；发送仅对明确的 422 自动重试，普通连接错误沿用原处理。
- `file-checksum.test.cjs` 通过：独立 Node SHA-256 对照、64 KiB 分块、空文件/UTF-8 文本、文件大小变化、取消清理、真实 HTTP 元数据、关闭发送校验以及 422 重试上限。
- `service.test.cjs` 31 组通过：官方 sha256 实际 HTTPS 收件、错误文件清理、关闭验证、重试上限及原有协议/传输回归；零文件句柄泄漏。日志 `logs/M140-service.log`。
- 最终此阶段源码鸿蒙 debug 编译通过，未发布正式 M140 包。日志 `logs/M140-debug.log`。已有 M139 正式包保持可用。
- 后续继续本清单其余功能；不要将本阶段当作用户全部目标完成。

## 第二阶段证据

- 增加 RGB/Hex 取色器、收藏自动接收新默认、小时/天 ETA、首次系统动画偏好。`appearance-118.test.cjs`、`colors.test.cjs`、`transfer-metrics.test.cjs`、`flutter-settings.test.cjs`、`settings-reset.test.cjs` 均通过。
- 取色器可选择全部 24 位 RGB 颜色；应用前只改草稿，非法 Hex 禁用应用，取消不改当前主题。已有预设色块保留。
- SDK 依据：本地 API 23 `@ohos.accessibility.d.ts` 和旧版 `@ohos.settings.d.ts`；调用带运行版本判断与异常回退，无新增权限。
- 尚未完成：链接收件/拖放完整审计、网页模板配置、链接 IPv6、语言导入、平台专属入口逐项对照与全量回归。目标保持进行中。

## 第三阶段证据

- `web-page.test.cjs` 新增混合文件/目录、多批次目录枚举、嵌套 Unicode 路径、实际二进制内容、取消和读取失败不覆盖旧选择测试。读取目录期间锁定选择与发送，取消按钮可中止枚举。
- `web-ipv6.test.cjs` 以实际监听验证 HTTP/HTTPS IPv6 页面与下载、IPv4 同时访问、只有网卡列表有 IPv6 的链接生成、未选文件的收件页面、重启清理；模拟单协议族不可用时另一协议族仍可服务。
- `web.test.cjs` 9 组通过，`web-language.test.cjs` 通过。链接收件沿用既有 PIN/接收确认，不绕过同意流程。
- 浏览器通常不能使用包含本机网卡作用域的 link-local IPv6 URL，自动链接只选 IPv4 或无作用域的非 link-local IPv6。跨设备实际网络仍需装包验证。
- 后续剩余：网页模板配置、语言导入、平台入口/CLI 的具体对照、其他尚待行的验证、全量回归与最终正式包。第二阶段的旧待办由本阶段进度更新，不表示全目标已完成。

## 第四阶段证据

- 官方 v1.18.2 的 be/ga/hy JSON 与 LICENSE 保存在 `upstream-locales/v1.18.2/`；生成过程不联网，固定来源可重现。
- 通过 `upstream-locales.cjs` 接入静态标签、引用、带参数文案与复数。既有本地品牌名与 53 种语言保留，官方缺失字段沿用英文回退。
- `flutter-locales.test.cjs`、`flutter-templates.test.cjs`、`web-language.test.cjs`、`language-choices.test.cjs`、`upstream-locales.test.cjs` 通过。后者直接与官方 JSON 比较标签和参数输出，并检查每种新语言实际翻译超过 100 个标签。
- 后续继续网页模板配置、平台入口/CLI 对照、其余未完成验证与最终打包；当前未宣告全部功能完成。

## 第五阶段证据

- 模板入口接入 WebShareView，存储及渲染在 WebTemplate，WebShareService 启动时读取模板；不改变上传/下载确认路由。
- `web-template.test.cjs` 通过：实际文件持久化、超限/空文件保留旧模板、单次字面替换、取消/导出/恢复、活动分享禁止改模板和实际 HTTP 页面。
- 鸿蒙 debug 编译通过；`flutter-locales.test.cjs` 回归通过。新增模板文案及前阶段新文案补了繁体中文，后续本地化按用户新约束执行。
- 剩余继续平台入口与 CLI 适用性逐项对照、表中其他未完成验证、全量回归与签名正式包。

## 最终验收 · 2.0.140

- 主机完整批次 73 个测试文件，初始 70 通过。saved-network-settings、send-subset、session-retry-integration 暴露的问题已修复，并在 M140-retest 日志中通过；同时复测 appearance-118/file-checksum/initialization/flutter-settings。
- 新增 favorite-autoaccept、size-units 两项通过；discovery-native 在允许本机真实网络的环境下通过。总计 76 个测试文件完成验证。download-directory 新增自定义目录碰撞用例并复测通过。
- 修复后的校验和行为与上游一致：计算失败只省略该文件可选校验和，继续协商与传输其他文件；取消仍立即终止。首次动画偏好单独保存，写入失败不破坏旧设置读取。
- 最终 release ArkTS 编译、APP 与独立 HAP 签名校验通过；metadata 含 FILE_ACCESS_PERSIST、INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING。
- 正式 APP：`artifacts/release/AloeSend-2000140-release-20260911-192730-signed.app`，SHA-256 `03B6128F8BACEC23868CB8CFFF9721D24290ACDEDD67EF539AB0FCDB66835398`。同名 `.hap` 为独立签名安装包。
- 无设备安装、无提交/推送；实际 HarmonyOS 桌面显示、窗口效果、系统授权及跨设备互操作属于明确列出的真机验证限制。
