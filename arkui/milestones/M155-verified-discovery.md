# M155 发现地址验证

版本 2.0.155 / 2000155。

修复 UDP 公告、接收注册与传输请求直接将来源地址插入设备列表的路径。此前来源地址即使后续握手失败也会保留，存在网络转发时显示网关分身的风险；尚未取得网友网络抓包，不能断言所有反馈都是同一原因。

现在先反向连接对应地址上的 LocalSend 接口，检查响应格式及设备指纹匹配，通过后才加入设备列表及地址提示缓存。接收注册先正常回复，再使用 GET 验证来源，避免双方反复 POST 注册；隐藏模式同样只读验证。传输接收确认不等待设备列表验证。两种显示方式均适用，不按 .1 或网关身份简单屏蔽，允许真实热点主机参与传输。

验证：discovery-gateway、discovery-ipv6、service（31 组）、discovery-recovery、protocol-upgrade、mutual-tls、add-address、device-display、discovery-hints、discovery-reciprocal、favorite-discovery 共 11 个测试文件通过。覆盖转发地址无服务、错误身份、无效响应、真实 .1 服务、隐藏模式、注册回环保护、双栈混合加密与文件传输。正式构建和 APP/HAP 签名验证通过；未在网友实际网络环境复测。

归档：`AloeSend-2000155-release-20261009-081412-signed.app` / `.hap`。APP SHA256 `379CE0C55AF46C1E67BC740A63CCB534D7C7CEE7259453B82913BABA7B89F9E0`。
