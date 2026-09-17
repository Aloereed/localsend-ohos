# M154 设备显示模式与发布模板

版本 2.0.154 / 2000154。

最终构建、APP/HAP 签名和内嵌 p7b 一致性验证通过。包 `AloeSend-2000154-release-20260915-220501-signed.app` / `.hap`，APP SHA256 `178407C8C9B6655203D87C5B3DD2D3D84CC034245404166E10CAEA9263FA8E22`。

核对发布配置：`app/ohos/build-profile.Release.json5` 已使用 `C:/Users/huzheng/Downloads/aloesend5Release.p7b`；通用 `build-profile.json5.template` 原 material 为空，本次也写入新 profile 路径。调试配置继续使用原调试身份。

设置 → 外观新增“使用 #尾号区分地址”，新安装、旧配置升级及恢复默认均开启。开启时发送列表按发现地址分别显示，接收页显示本机尾号；关闭时发送列表沿用按指纹合并的设备记录，一张卡片列出其保留的 IPv4/IPv6 地址，接收页及收藏卡片隐藏尾号。切换立即生效并保存到设置。

参考官方 1.18.2 `packages/core/src/discovery/store.rs`：以指纹识别同一设备，保留多个通道。AloeSend 新增有界端点列表保留多地址，网络注册仍使用现有最近更新的端点；本次不引入上游整套通道排序/故障转移机制。不同指纹即使同名或 IP 尾号相同，也不会合并。批量选择按设备去重，避免同一设备重复接收。

验证：device-display、discovery-hints、discovery-ipv6、flutter-locales、send-targets、favorite-discovery、conversations 七个测试文件通过，覆盖默认值、两种列表、多地址/IPv6、同名不同身份、重复公告、证书指纹大小写、即时切换、批量去重、设置重开恢复与恢复默认，以及双栈真实 HTTPS 文件传输。新增文案仅补简繁中文和英文。未安装或操作真机。
