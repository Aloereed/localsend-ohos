# M128 · 移除 INTERNET 声明

用户明确要求直接移除 INTERNET；本版删除该权限声明，保留 GET_NETWORK_INFO 和 KEEP_BACKGROUND_RUNNING。此前已删除的 READ_PASTEBOARD、FILE_ACCESS_PERSIST 继续不声明。release 构建对最终 APP 内每个模块检查这三项均不存在。

没有修改传输实现。构建通过；没有访问设备，也没有验证移除 INTERNET 后的设备发现、HTTP/HTTPS 或文件收发行为，不能用主机测试替代权限环境验证。正式签名 APP 见交接。

调试产物：`artifacts/AloeSend-2000128-M128-no-internet-permission-unsigned.hap`，版本 2.0.128 / 2000128。

SHA-256：`62E16C65A1D855A85CCCA95793789A601474BC3D71011BC178B29E59DFAD7332`。
