# M51 · HTTPS 接收按落盘速度读取

Windows LocalSend 重启后能够发送，但数 GiB 文件仍触发“写入速度不足，接收缓冲区已满”。旧 HTTPS 接收依赖系统消息推送；磁盘忙时，应用仍持续积累明文数据，最终超过 32 MiB 队列上限。

HTTPS 服务改为原生 TCP 按需读取。每次最多读取 64 KiB，ArkTS 完成解密、HTTP 解码和异步文件写入后才允许下一次读取。磁盘变慢时，操作系统 TCP 接收窗口会让发送方减速。保留现有 TLS 引擎、证书、LocalSend 协议和取消通知；关闭或失败也会释放等待中的读取确认。HTTP 接收路径本里程碑未调整。

## 验证

- 同一真实 TLS 测试人为暂停首次磁盘写入一秒：旧接收实现复现原错误，队列峰值 33,554,644 字节；新实现完成 128 MiB 接收且发送方受到 TCP 背压。
- 3 GiB 完整传输经过一秒磁盘暂停后成功，文件大小和 SHA-256 一致，应用接收队列峰值 65,750 字节，结束后文件句柄为零。耗时约 23 秒；这是 Windows 主机测试结果，不代表手机速度。
- 28 个主机测试文件全部通过，包括 HTTP/HTTPS 双端取消、取消后立即重新发送、TLS 分片和合并包、文件保存及浏览器共享。
- HarmonyOS ArkTS 和原生库编译成功。用户已离开设备，本次未安装、未访问设备，鸿蒙实机上的大文件接收仍待复测。

复测命令：`node --test arkui/tests/backpressure.test.cjs`；环境变量 `ALOE_LARGE_MIB=3072` 启用 3 GiB 校验。需先运行 `arkui/build-native-tests.ps1` 构建主机原生模块。

产物：`artifacts/AloeSend-2000051-M51-tcp-backpressure-unsigned.hap`，版本 `2.0.51`。

SHA-256：`81389BB21C2CF458D8F79FD3E30D0E79DE9A9C0649117CCA1906E6F8E70086B1`。
