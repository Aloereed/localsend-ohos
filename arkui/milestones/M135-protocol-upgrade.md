# M135 · 纠正旧 HTTP 设备记录

版本 2.0.135 / 2000135。

用户反馈 Android LocalSend 1.17.0 已开启加密，但 ArkUI 显示未加密，发送提示“设备提前关闭了连接”，Android 未出现接收确认；Windows 1.16.1 正常。ArkUI 的设备协议字段同时控制显示与实际传输，旧 HTTP 记录指向 HTTPS 监听端口时会产生上述故障。旧记录的具体来源尚未确认。

设备注册、收藏探测和首次接收请求遇到 HTTP 提前断连时，使用 HTTPS 的只读 info 请求验证端点及证书指纹。验证成功后更新附近设备、收藏和发送任务的加密状态，再发起接收请求。兼容 v1 info 回退；不将 HTTPS 降级为 HTTP，不重放文件上传。HTTPS 响应中陈旧的 protocol 字段不能覆盖已验证的连接协议。

验证：protocol-upgrade.test.cjs、favorite-discovery.test.cjs、service.test.cjs 三个主机测试文件通过，其中 service 含 30 组集成检查。新增测试使用真实 HTTPS 服务复现旧 HTTP 记录，覆盖探测、注册、完整二进制发送、只收到一次接收请求及指纹不匹配阻断。鸿蒙构建与产物归档结果见 HANDOFF.md 和 PACKAGES.md。

限制：主机复现不等同于 Android 真机互操作验证。本轮曾只读查询已连接鸿蒙设备的日志，但未取得可定位这次故障的网络日志；未安装新包，Android 1.17.0 和 Windows 1.16.1 的实机回归仍待完成。

调试归档：[M135 unsigned HAP](../artifacts/AloeSend-2000135-M135-protocol-upgrade-unsigned.hap)。
