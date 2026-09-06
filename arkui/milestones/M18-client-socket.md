# M18 · 发送端原生 Socket 初始化

延续 M17 实机问题的 API 审计，发现 TLSSocket 的消息、错误和关闭订阅也必须在成功 bind 后注册。发送端此前依赖 Node 风格的隐式本地绑定，不能代表 HarmonyOS 的原生行为。

- TCP/TLS 客户端显式绑定本地随机端口，按目标地址选择 IPv4/IPv6。
- bind 成功后订阅事件，再发起连接；绑定过程中发生取消或超时则停止后续连接。
- TLS 证书指纹仍在发送应用数据前验证。
- 主机适配器强制执行 bind 前置条件，实际 Node 连接也绑定对应本地地址族。

依据：[OpenHarmony Socket 官方文档](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-network-kit/js-apis-socket.md)，TLSSocket 的 on('message')、on('connect' | 'close')、on('error')。

验证：18 组 LocalSend 集成、7 组浏览器服务集成通过，含 IPv6、超时、指纹拒绝、真实二进制发送；原生 debug 编译成功。

产物：`artifacts/AloeSend-2000018-M18-client-socket-unsigned.hap`。包含 M17 全部修复，未签名，待用户部署验证。
