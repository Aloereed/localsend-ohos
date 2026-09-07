# M67 · 编辑弹层的滚动与键盘避让

发送文字/地址/重命名、接收批量/单项重命名及设备快捷选择弹层改为可滚动表单。设备快捷选择使用大尺寸弹层容纳五种入口。内容溢出时能纵向滚动，不依赖固定屏幕高度。

编辑弹层和语言搜索显式使用 `SheetKeyboardAvoidMode.RESIZE_ONLY`。依据本机 HarmonyOS SDK 的 `ets/component/common.d.ts`，该模式从 API 13 支持：键盘出现时调整内容区域大小。现有最低 API 22 可用。

## 验证

- 最终 ArkTS 与未签名 HAP 构建通过。
- 本轮只修改视图布局，没有添加镜像实现的单元测试，也没有重跑网络测试来代替视觉验证。
- 未连接设备。键盘下的滚动焦点、系统返回手势、大字体、横屏和无障碍效果仍待实机检查。

产物：`artifacts/AloeSend-2000067-M67-scrollable-sheets-unsigned.hap`，版本 `2.0.67`。

SHA-256：`00905841F6C2FC3ED670872118E2821609DD1C9E713AE458BC33CE537EFB0815`。
