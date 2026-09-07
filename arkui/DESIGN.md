# HarmonyOS 界面打磨

用户要求保留原版 AloeSend Logo，并参考华为沉浸光感设计，避免把 Material 风格控件简单换成 ArkUI。

## 依据与兼容范围

- [用户指定的沉浸光感指南](https://developer.huawei.com/consumer/cn/doc/design-guides/immersivelight-0000002612101053)
- [华为设计首页：空间层次、材质与交互响应](https://developer.huawei.com/consumer/cn/design)
- [沉浸光感开启要求](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)
- [材质面积、嵌套与动态内容的功耗指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-constraints)

当前构建 SDK 为 API 24，最低兼容 API 22。M49 已接入 API 23 起提供的 HDS Tabs 浮动底栏与系统材质；这与较新通用 ArkUI 沉浸光感属性的 API 26 要求不同。运行时同时检查系统版本与 HDS 能力，较旧系统保留自定义浮动模糊底栏，不提高最低安装要求。

## M43–M49 浮动导航

- 原版 PNG Logo 保持不变；删除其周围形成方形底色的装饰，圆形外容器裁切。
- 手机底栏脱离页面底边，距左右和底部留出空隙；内容预留底部空间，避免最后一项被遮挡。
- API 23+ 使用 `HdsTabs.barFloatingStyle` 与系统自适应材质，尊重系统支持程度与功耗调节，避免在系统材质上再叠加不透明背景。
- API 22 使用圆角、渐变、模糊和轻阴影的浮动底栏；轻量效果模式关闭模糊。
- 仍需用户在设备上检查材质实际观感，不将编译通过称为已经验证折射、形变或触感。

官方依据：[HDS 系统材质](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/api/ui-design-hdsmaterial)。

## M22 设计落地

- 导航、浮动提示、消息输入区使用系统薄材质，内容卡片使用轻量半透明底色；不在滚动列表每张卡片上叠加模糊滤镜。
- 统一浅色雾白/灰蓝、深色石墨背景，以及内容、控件、浮层、细边界和环境色。主题强调色继续尊重用户设置。
- 首页采用开放的设备身份区，原始 Logo 完整保留；历史、任务和接收设置合并为有分隔线的操作组，减少重复大色块按钮与介绍卡片。
- 导航使用简洁图标与文字选中态，去除原 Material 风格图标背后的独立胶囊底。平板继续使用侧边导航。
- 顶部临时提示悬浮显示，不再插入布局挤动内容。详情标题栏与导航材质统一。
- 发送入口继续为单行横向滚动；次要按钮降为中性底色，仅关键确认/发送动作使用强调色。M23 将附近设备标题与选择器分行，给窄屏英文留出空间。
- 设置按钮采用统一中性控件底色，内容组保留原生开关、选择器和输入行为。
- 进度页保留 M21 的稳定节点，新增清晰百分比，使用原生线性进度平滑效果，尊重关闭动画的设置。
- 空状态采用开放留白，避免再套一张大卡片；消息输入区域形成独立操作层。

## 验证边界

M24 补充轻量效果和 OLED 纯黑背景。轻量效果关闭系统模糊、装饰阴影与环境色变化，表面改为实色；纯黑背景只在深色模式生效。默认均关闭，保留升级前外观。

编译验证 API、类型与资源；对比度验证覆盖新浅/深色控件底。未使用 DevEco GUI，未签名或安装。新界面的实际材质、触感、字重及不同设备尺寸最终观感仍需真机检查。
