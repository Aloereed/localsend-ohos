# M150 双向发现与注册重试

版本 2.0.150 / 2000150。

release 编译及 APP/HAP 签名验证通过。正式包：`AloeSend-2000150-release-20260912-213555-signed.app` / 同名 `.hap`，位于 `arkui/artifacts/release/`。APP SHA256：`3647FB504F6A8D89DFF838C774C0D294D110A399EF578B947494F0EBB5C08916`。

用户补充：本机为鸿蒙 AloeSend，对端 LocalSend 1.18.2；有时对端进入发送页后本机才发现对端，先后顺序不确定。对端系统、加密状态未确认。只读设备 hilog 见组播网卡加入，不能据此确认用户现场的全部根因。

比照本地保存的官方 1.18.2 源码 `packages/core/src/discovery/mod.rs`，其主动探测直接 POST register；本机此前 GET info 后再开连接 POST register。可见模式现改成一次注册交换双方身份，减少一次连接和两步之间的失败窗口；404 回退 v1/register。隐藏模式继续只读取 info，旧 HTTP 记录升级 HTTPS、证书指纹校验和客户端证书保持不变。

收到公告后的注册失败原来只记日志，必须等待下一次公告或扫描。现保留最多 16 个失败端点，每 15 秒最多定向重试 2 个，轮转失败项；成功移出队列，证书身份错误不重试。忙时不启动，重试期间每 100 ms 检查正常操作并取消连接，停止服务或网络变化清空旧任务。后台子网扫描的并发、短批次、限速、冷却与文件选择避让不变。

验证：discovery-reciprocal 新增测试覆盖无第二次远端公告即可重试、重复公告合并、队列上限、重试冷却、忙时暂停和取消、身份错误、停止后旧回调不回填。add-address 使用真实 HTTP/HTTPS 检查单次 POST、v1 回退、隐藏 GET 与证书错误不降级。mutual-tls 使用要求客户端证书的 HTTPS 服务检查一次请求同时交换身份。

共 12 个相关测试文件通过：discovery-reciprocal、add-address、mutual-tls、protocol-upgrade、discovery-priority、discovery-automatic、discovery-stages、discovery-ipv6、selection-discovery、discovery-scan、discovery-recovery、hotspot-discovery。测试日志位于 `arkui/logs/M150-*.log`。主机适配测试不等同于鸿蒙与官方客户端真机联调；不声称已验证现场现象完全消失。未安装设备，源码未提交。
