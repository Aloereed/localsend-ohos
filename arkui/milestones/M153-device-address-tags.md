# M153 设备 IP 尾号标记

版本 2.0.153 / 2000153。

正式构建、APP/HAP 签名及内嵌 aloesend5Release.p7b 一致性校验通过。包为 `AloeSend-2000153-release-20260915-215815-signed.app` / `.hap`；APP SHA256 `012FA54302BD2FB69F6C50C225C8104E90080095957CE9D158E23C3B9733D7AB`。

按用户要求核对 LocalSend：官方 v1.17.0 接收页使用 `#${ip.visualId}`，多个本机地址去重显示；工作区 Flutter 的 ip_helper.dart 定义 visualId 为点分地址最后一段，发送设备卡片也使用该标记。官方 v1.18.2 的接收页和设备卡片已改用不同展示，并非所有版本都保留此功能。

参考：[官方 v1.17.0 接收页](https://github.com/localsend/localsend/blob/v1.17.0/app/lib/pages/tabs/receive_tab.dart)、[官方 v1.18.2 设备卡片](https://github.com/localsend/localsend/blob/v1.18.2/app/lib/widget/list_tile/device_list_tile.dart)。

AloeSend 接收主页在设备名称下显示有效 IPv4 地址尾号，如 `#15 · #1`，尾号去重，服务离线时不显示。发送页附近设备及收藏卡片在设备名下显示随主题配色的 `#12` 标记。完整 IP 和端口继续显示，避免不同网段相同尾号被误认为相同设备；IPv6 不生成 IPv4 风格短号。标记不参与设备身份识别、地址解析或网络请求。

主机检查通过：IPv4 格式化、多网卡、重复尾号、空值/无效地址/IPv6 省略。见 `arkui/logs/M153-address-tags.log`。不涉及本地化文字或其他上游功能同步；未连接或安装真机。
