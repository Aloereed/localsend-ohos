# M129 · 恢复原生网络权限

用户确认原生版本需要 INTERNET，并明确要求恢复。重新声明该权限，保留 GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING；不恢复仍在审批中的 READ_PASTEBOARD 和 FILE_ACCESS_PERSIST。

release 脚本对最终内嵌模块要求 INTERNET 存在、两项待审权限不存在，并继续检查 debug=false、版本、包名与发布签名。系统安全粘贴按钮、非持久文件授权行为沿用 M127；没有改动传输代码。本轮验证构建、包内清单和签名，未连接设备。正式包与 SHA-256 见交接。

版本 2.0.129 / 2000129，调试归档 `artifacts/AloeSend-2000129-M129-restore-network-permission-unsigned.hap`。
