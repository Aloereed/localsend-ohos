# M106 · 目录搜索键盘与滚动位置

主页面目录弹层采用 RESIZE_ONLY 键盘避让，与其他编辑弹层保持一致。目录列表绑定 Scroller，成功切换目录以及修改搜索条件时回到顶部，避免沿用旧列表的滚动位置。过期目录读取仍通过 generation 校验丢弃。

本轮仅补齐 M105 搜索入口的界面行为，最终 ArkTS 未签名构建成功。未访问设备，键盘遮挡、列表回顶与小屏空间仍需实机验收。

产物：`artifacts/AloeSend-2000106-M106-folder-keyboard-unsigned.hap`，版本 `2.0.106`。

SHA-256：`66F84C9B7E81CB30316E8C966239CC1AFEEF219FDF8715815770F3E3387E4CC5`。
