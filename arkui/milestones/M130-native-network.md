# M130 · C++ 网络传输层

将剩余 ArkTS socket I/O 迁入 C++。新增非阻塞 IPv4/IPv6 TCP 客户端（保留 IPv6 scope），mbedTLS 客户端握手与对端证书 DER 读取，UDP 组播加入、发送和有界接收队列。TCP 连接建立在独立线程执行并有 5 秒期限；读写可被取消，读侧维持每次最多 64 KiB 的授信机制。

HTTP 接收和浏览器 HTTP 服务复用 PullServer；HTTPS 服务保持既有 mbedTLS 接收与关闭流程。发送流程改用 NativeClient，在提交 HTTP 请求或消费响应前检查证书指纹；握手卡住、写窗口阻塞、连接失败均释放连接和 TLS 状态。没有 HTTP 静默降级。NativeDatagram 承接发现广播，界面、协议状态、网卡信息查询仍由 ArkTS 管理。

主机适配层禁止构造 ArkTS socket，实际收发使用同源 C++ 模块。60 个主机测试文件通过（约 22 秒），包含独立 HTTP/HTTPS 对端、指纹变化拒绝、取消通知、v1/v2 会话恢复、浏览器分享。新增边界测试覆盖 80 次 TCP 失败、80 次立即取消、IPv6、握手取消、阻塞发送取消和 12 轮 UDP 二进制收发/关闭重绑。

HTTP 与 HTTPS 各完成 3 GiB 接收，一次 1 秒磁盘暂停及 384 次 10 ms 周期暂停后 SHA-256 一致，文件句柄归零。HTTPS 队列峰值 65,750 字节，HTTP 峰值 65,536 字节。日志：`backpressure-m130-3gib.log`、`backpressure-m130-http-3gib.log`。

组播加入和发送接口调用成功，但主机不能收到组播回环；独立 Node dgram 对照同样收不到。因此没有将该测试声称为局域网设备发现互通证明。鸿蒙设备上的 UDP 发现、Windows Flutter LocalSend 互通仍需实际检查，未访问设备。

保留 INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING，仍不声明 READ_PASTEBOARD / FILE_ACCESS_PERSIST。C++ 迁移并不能仅凭主机测试证明可去掉 INTERNET；本轮未删除。界面和授权交互没有改动。

版本 2.0.130 / 2000130，鸿蒙编译通过。未签名归档 `artifacts/AloeSend-2000130-M130-native-network-unsigned.hap`，SHA-256 `EBC778D47B303FDC77D9C6B4EE21005E6066FDF03E2D745C010182B3F5DB2F4C`。正式 APP 沿用 Flutter release 配置，归档与签名验证结果见 HANDOFF。
