# M145 · 地址添加空值处理

用户报告点击通过地址添加后出现 cannot read property length of undefined，未提供对端加密状态或调用栈，当前 hdc 无连接设备。

复现：将主机 TextEncoder 模拟为对空字符串返回 undefined，未修复源码通过实际 HTTP 地址添加时出现同样的 length 异常，记录 logs/M145-before.log。SDK 声明应返回 Uint8Array，这个注入实验验证了代码缺口，并不证明用户系统一定走了此分支。官方编码实现参考 [js_textencoder.cpp](https://github.com/openharmony/commonlibrary_ets_utils/blob/master/js_util_module/util/js_textencoder.cpp) 和 [native_module_util.cpp](https://github.com/openharmony/commonlibrary_ets_utils/blob/master/js_util_module/util/native_module_util.cpp)，只读副本保存在 logs/M145-*。

修复：空输入直接返回 Uint8Array(0)，GET 等空请求固定 Content-Length: 0；非空编码缺失则报明确错误，空响应不调用原生解码器。TLS 远端证书及解码后的字节为空时，以身份错误中止，不发送 HTTP 内容、不回退明文。裸地址协议探测保留普通连接失败时的 HTTP 回退，并记录最初 HTTPS 错误供诊断。

验证：add-address 通过真实 HTTP/HTTPS、带协议和裸地址、v1 回退、反向注册、中文/emoji 字节、证书缺失与禁止明文回退；注入相同编码行为后添加成功。addresses、protocol-upgrade、mutual-tls、file-checksum 和 service 回归通过，后者包含 31 组及文件句柄检查。共六个测试文件，日志 logs/M145-*.log。

2.0.145 / 2000145 正式构建、APP/HAP 签名通过。包括 M144 的热点接口修复。未安装设备，需用户复测以确认这次报告的实际触发点。
