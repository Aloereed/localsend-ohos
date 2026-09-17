# M137 · 客户端 TLS 身份与系统手势条

版本：2.0.137 / 2000137。

LocalSend 1.18.0 的服务端在未启用网页服务时要求客户端证书。此前 Transport 使用空 secureOptions，虽然已正确选择 HTTPS 并校验服务端指纹，仍不能满足双向 TLS 握手要求。

- 所有 LocalSendService 出站 HTTPS 请求携带本机持久化证书及私钥，包含发现、注册、请求接收、上传、重试和取消。
- 本机 HTTP 接收模式也初始化证书身份，以支持向 HTTPS 设备发送。初始化共享在途 Promise，注册和发送在构造声明指纹前等待身份就绪。
- 服务端证书指纹仍在发送 HTTP 请求前校验。
- 系统手势条通过 setSpecificSystemBarEnabled('navigationIndicator', false) 隐藏。透明系统栏和安全区计算保留，页面加载后及返回前台重新应用。

新增 mutual-tls.test.cjs 使用要求客户端证书的真实 Node HTTPS 服务端：旧匿名 TLS 请求失败；发现、注册、150003 字节二进制上传、取消成功；服务端指纹不匹配时不发送请求。测试覆盖本机关闭接收加密的情形。既有协议纠正测试改为使用独立接收端身份，避免把自身身份当作对端。

本轮主机测试不能替代 HarmonyOS NetworkKit 真机握手和系统栏渲染验证，未安装设备、未推送。

依据：[LocalSend v1.18.0 服务端](https://github.com/localsend/localsend/blob/v1.18.0/packages/core/src/http/server/mod.rs)、[客户端证书校验](https://github.com/localsend/localsend/blob/v1.18.0/packages/core/src/http/server/common/client_cert_verifier.rs)。
