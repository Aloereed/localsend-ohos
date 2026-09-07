# M49 · HDS 系统悬浮材质

HarmonyOS API 23 及支持 HDS 的设备使用原生 HdsTabs 悬浮页签及自适应沉浸光感材质，底部留出间距，开启系统温控策略。API 22 保留自绘悬浮底栏。共享 TabContent，接收、发送、消息、设置内容保持一致；聊天详情隐藏底栏。

已通过 ArkUI 编译，保留 API 22 最低兼容要求并在调用 API 23 属性前检查设备版本和系统能力。材质观感尚待用户真机评估。

产物：`artifacts/AloeSend-2000049-M49-system-glass-unsigned.hap`，版本 `2.0.49`。

用户安装后反馈 HTTPS 确认接收后零进度，后续继续调查；本包不作为 HTTPS 故障已解决的验收结论。
