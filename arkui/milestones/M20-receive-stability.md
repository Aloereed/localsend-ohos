# M20 · 接收进度、大文件 TLS 与下载目录

用户在 M19 实机复测发现：确认接收后没有进入进度页，大文件导致进程退出，下载目录授权与 Flutter 不一致。

## 根因与修复

- 接收会话进入 transferring 时，AppStore 发出一次 onReceiveStarted，主界面切到传输页；手动/自动接收共用此入口，后续进度更新不会反复抢导航。
- 真机故障记录：MatePad Pro，HarmonyOS 6.1.0.117，M19，2026-09-07 00:47:18，前台 SIGABRT。线程 OS_NET_TSAccRD 在系统 `libsocket.z.so / TLSSocketServer::RecvRemoteInfo` 调用 `__strlen_chk` 触发越界终止。不是可由 ArkTS catch 捕获的异常。诊断记录保存在本地忽略目录 `logs/latest-device-crash.txt`。
- 使用官方 Mbed TLS 3.6.7 LTS 的应用内 NAPI TLS 引擎，承载在 TCP 连接上，替换接收端系统 TLSSocketServer。持续保留 TLS 1.2/1.3、原有证书和指纹；没有降级 HTTP。网页加密接收同样改用此实现。
- 接收队列将等待写盘的数据合并为最多约 1 MiB 的批次，避免每个 TLS 小块分别发起异步磁盘/摘要更新造成队列溢出。保持缓冲区上限与异常清理。
- 对照 Flutter `DownloadPlugin.getDownloadPermission`，启动时请求 `DocumentPickerMode.DOWNLOAD`，验证本应用 Download 目录可写。默认写入 `/storage/Users/currentUser/Download/com.aloereed.aloesend`，保留自定义目录；拒绝授权时回退应用内保存。
- 默认目录直接流式写 `.part` 文件，完成长度与 SHA-256 校验后改名；已有同名文件自动加序号，不覆盖。无需保存两份大文件。
- 顺带补齐设备详情中无文件时的选择入口、消息入口，以及收藏备注按身份匹配。

## 验证

- 原生 arm64 debug 编译通过，HAP 包含应用内 TLS 库及许可说明。
- Windows 主机用相同的 C++ core/bridge 与 Mbed TLS 源码编译 Node NAPI 模块；ArkTS 服务测试加载该模块，而不是模拟 TLS。
- 19 组真实收发服务集成通过，包括 128 MiB 全部为 `0xA5`（不含零字节）的 TLS 上传、SHA-256 一致、直接写入下载目录、一次进度导航事件。该数据专门覆盖二进制被误当作 C 字符串的风险。
- 7 组网页服务、历史、通知/发现、DOWNLOAD 授权/取消/自定义目录/重名保护回归通过，文件句柄无泄漏。
- 主机 NAPI 构建：`./arkui/build-native-tests.ps1`（Node 头文件、MinGW 与 CMake 路径可传参数）。PowerShell 中执行 `node --test (Get-ChildItem arkui/tests/*.test.cjs).FullName`，全部 14 个测试文件通过。

产物：`artifacts/AloeSend-2000020-M20-receive-stability-unsigned.hap`。
未签名、未安装。新库的 HarmonyOS 真机加载、大文件收发与授权对话框仍待用户部署复测；主机验证不代替真机验证。

依赖来源与校验值见 `AloeSend/entry/src/main/cpp/vendor/README.md`，许可证与第三方声明随源码和包保留。
