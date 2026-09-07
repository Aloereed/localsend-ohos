# M132 · 备份 C++ 分支并恢复 NetworkKit

按用户要求先建立备份分支 `codex/backup-arkui-cpp-20260908`，指向回退前 `9b0a7a486de8c46fe5383f5a7ef9f82d69fad5fe`。当前继续在 `arkui` 开发，未推送远程。

撤回 M130 提交 `28d1d307` 中的网络源码和配套测试，恢复到其父提交 `bfb9b164`。TCP/TLS 发送、HTTP 接收、浏览器 HTTP 服务和 UDP 发现恢复 NetworkKit。迁移之前已有的 C++ pull TCP / mbedTLS HTTPS 接收及慢写盘背压保留。已比较 cpp 与 ets/network 目录，和迁移前完全一致。

恢复 INTERNET 及发布包必须包含 INTERNET 的校验。READ_PASTEBOARD 和 FILE_ACCESS_PERSIST 继续排除。M131 的旧版本导入文案、繁體中文名称、999 文件及分批图库选择、底栏随窗口宽度更新均保留；components、model、pages 与备份分支没有差异。

原生主机库重建成功，全部 60 个主机测试文件通过（约 19 秒），鸿蒙编译通过。没有访问设备；NetworkKit 回退后的实机传输和玻璃底栏缩放仍待用户部署检查。

版本 2.0.132 / 2000132，调试归档 `artifacts/AloeSend-2000132-M132-networkkit-rollback-unsigned.hap`，SHA-256 `F03F4E7A1DFDB59E8FEA649E0A9D4687C32217693CD2B658B909FEC96E1C76EB`。正式发布 APP 沿用 Flutter release 身份，产物与签名验证结果见 HANDOFF。
