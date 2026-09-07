# M101 · HTTPS 提前响应完整关闭

沿 M100 的 ECONNRESET 日志定位到：上传正文仍在到达时，拒绝无效令牌立即发送响应并关闭 TCP，未读输入可造成连接重置。独立真实 HTTPS 测试在旧实现第二次请求复现。

SecureConnection 发出 close_notify 后继续按原生读取信用丢弃在途密文，等待对端结束，整个关闭阶段最多一秒。收尾数据不进入 HTTP 或文件写入，随后统一释放 TLS/TCP。保留正常传输背压和有时限的强制释放。

验证：同一测试连续 20 次对 4 MiB 上传提前返回 403，响应状态及正文完整，文件接收字节为零。旧日志 early-tls-baseline.log，新日志 early-tls-current.log。累计 51 个主机测试全部通过（13.0 秒），含 HTTP/HTTPS 取消、立即重发、背压与服务错误处理；最终 ArkTS 未签名构建成功。未访问设备，Windows 主机验证不能代替鸿蒙实机验收。

产物：`artifacts/AloeSend-2000101-M101-tls-response-close-unsigned.hap`，版本 `2.0.101`。

SHA-256：`E1337EA9089BC83A834F2C288F4632EC727968831B259E4A2E839FF7CC4E539B`。
