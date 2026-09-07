# M126 · 系统底栏沉浸

根页面在忽略上下系统安全区时使用 LayoutPolicy.matchParent，替代百分比高度，背景覆盖整个窗口和底部导航区域。保持内容安全区内边距，悬浮导航和操作按钮仍避让系统手势区域。透明导航栏外，窗口背景也同步页面底部的 canvasColor，防止布局切换时露出默认底色；主题改变与返回前台时刷新。底部避让计入底部挖孔区域。

实现参考华为官方[窗口沉浸式](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-window-immersive)关于 ignoreLayoutSafeArea 与 LayoutPolicy.matchParent 配合的说明，以及本地 API 24 声明。没有通过隐藏系统手势条来代替沉浸。

窗口测试新增透明底栏、明暗内容颜色、窗口底色及底部挖孔避让检查；与隐私/前台生命周期测试共 2 个针对性测试文件通过。最终 ArkTS 构建通过。未访问设备，实际导航模式和底部观感仍待用户部署确认。

产物：`artifacts/AloeSend-2000126-M126-bottom-immersion-unsigned.hap`，版本 2.0.126 / 2000126。

SHA-256：`324937E353BF6D410CFC30E8B4CB9A15F830B818B55E3155CE9DAA87E872D572`。
