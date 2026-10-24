# M156 · 自选保存目录 URI 修复

版本 **2.0.156 / 2000156**，2026-10-16。

用户反馈：默认保存位置是 `/storage/Users/currentUser/Download/com.aloereed.aloesend`，通过系统选择器选择同一目录后保存为 `file://docs/storage/Users/currentUser/Download/com.aloereed.aloesend`，接收文件却只留在应用沙箱。

## 修复

- 已定位 `AppStore.saveReceivedCopy` 把选择器 URI 直接传给目录检查、递归建目录及文件创建；普通路径的旧测试未覆盖这一输入。
- 持久化设置和 `fileShare.activatePermission` 继续使用原始 URI；授权激活后通过 `new fileUri.FileUri(destination).path` 获取读写路径，用于检查、目录创建、重名避让、写入和导出位置记录。已有 URI 设置无需重新选择即可使用修复。
- 保留系统 URI 转换，避免手工去掉 `file://` 后留下 `docs` 或误处理编码字符。参考 [OpenHarmony 保存用户文件示例](https://github.com/openharmony/docs/blob/master/en/application-dev/file-management/save-user-file.md) 及本机 SDK 的 `@ohos.file.fileuri.d.ts`。
- 自选目录仍沿用 `AloeSend-<传输编号>/相对文件名` 布局；接收先暂存应用内，再写入选定目录。真实权限撤销或目录不可用时仍保留接收原件并提示失败。
- 本次在已有 M155 未提交改动上修复，保留其发现地址验证实现；未提交、未推送、未安装设备。

## 验证

- 新增 `destination-uri.test.cjs`：修复前因目录检查收到 URI 而失败，修复后通过。覆盖截图中的下载目录 URI、自选目录、中文/空格/百分号/井号、设置保留原始 URI、新实例恢复配置后激活授权、本次传输指定目录、同名文件避让、授权撤销后保留原件，以及文件句柄关闭。
- `download-directory`、`folder-selection`、`selection-atomic`、`selection-cancel`、`history-path`、`history`、`service` 通过，共 **8 个测试文件**；`service` 包含 **31 组集成测试**。
- 首次构建与服务测试被执行沙箱的 EPERM/EACCES 阻断；在获准放开的构建/回环测试环境中重跑通过。
- release ArkTS 编译、最终包版本/权限检查、APP 和独立 HAP 签名校验通过；`git diff --check` 通过。
- **待真机验收**：安装后选择截图中的目录接收文件；选择带中文及空格的其他目录并重启应用再接收；在系统文件管理器确认文件位置和内容。主机测试不代表设备上的持久授权已实测。

## 归档

- [正式 APP](../artifacts/release/AloeSend-2000156-release-20261016-192536-signed.app)
- [签名 HAP](../artifacts/release/AloeSend-2000156-release-20261016-192536-signed.hap)
- APP SHA256：`32BEAC7E2688ED6D933F842CE0872DFAD2AEBE62FF4D9476C16D7C976FAEC618`
- 构建与服务回归日志：`arkui/logs/M156-release.log`、`arkui/logs/M156-service.log`；其余五个相关回归文件的日志为 `arkui/logs/M156-<测试名>.log`。
