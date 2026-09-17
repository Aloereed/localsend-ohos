# M139 · 恢复文件持久化权限

版本 2.0.139 / 2000139。用户已取得 FILE_ACCESS_PERSIST 权限，恢复模块声明及持久化目录的使用；发布脚本检查正式包必须包含此权限。

- 支持 FolderSelection 的设备使用系统文件夹选择器，成功 persistPermission、activatePermission 后才保存默认目录。取消或授权失败保留原设置。
- 缺少 FolderSelection 或系统选择器返回 801 时继续使用应用下载目录浏览器，其他错误正常展示。
- 非下载目录每次导出前激活持久化授权，覆盖已有配置和本次传输指定的目录。授权撤销或目录失效时保留应用内接收文件。
- DOWNLOAD 特殊授权保持原流程，不作为 fileShare 持久化策略处理。

验证：download-directory、folder-selection、selection-atomic、selection-cancel 四项主机测试通过，覆盖授权顺序、重启实例激活、取消、失败、撤销、下载目录回退和文件内容保留。最终 release 编译及 APP/独立 HAP 签名校验通过，包内权限声明已检查。鸿蒙设备的实际重启及持久化权限生效待装包验证。

正式包：[APP](../artifacts/release/AloeSend-2000139-release-20260911-003834-signed.app)、[HAP](../artifacts/release/AloeSend-2000139-release-20260911-003834-signed.hap)。APP SHA-256：5B2DDF1C35712EB0E9308A51957B75C6AF1C0FC0B67FAEF39602552CC3E00D65。

包含 M137/M138 已完成修复。未提交、未推送、未安装真机。
