# M157 · 消息会话身份一致性

版本 **2.0.157 / 2000157**，2026-10-16。

用户反馈接收文件后消息列表出现两个同名设备，最近文件不同，但点击后会话内容相同。源码中确认并在主机复现一条符合该现象的路径：`conversationList` 使用区分大小写的指纹作为键，`MessagesView.open` 却通过忽略证书指纹大小写的 `samePeer` 替换为在线设备，导致两个列表分组进入同一详情。尚未读取用户真机历史，不能断言现场记录只有这一种原因。

## 修复

- 提取统一的 `normalizedFingerprint`：64 位十六进制 SHA-256 指纹规范为小写，其他协议标识仍区分大小写；设备身份比较和会话键共用该规则。
- 消息分组、最近文件、搜索、会话详情、文件批次、草稿键、新消息计数及清空范围统一使用规范后的会话键。同名但不同指纹的设备保持分开。
- 打开会话改用 `currentConversationPeer`，与会话内刷新、发送前解析保持一致，仅更新相同会话身份的在线端点，避免无指纹地址记录因相同 IP 被替换到另一个历史分组。
- 旧历史直接按统一规则展示，不改写或删除历史数据；无需清空记录。包含 M155/M156 的现有修复。

## 验证

- 扩展 `conversations.test.cjs`，先复现原逻辑把大小写不同的同一证书拆成两行，再验证修复通过。
- 覆盖列表最新预览与打开后详情一致、按旧文件搜索仍显示最新预览、换 IP、同名不同身份隔离、批次归并、草稿复用、新消息计数、清空范围、非证书标识大小写及无指纹历史的身份保持。
- **8 个测试文件通过**：conversations、device-display、send-targets、history、flutter-import、incoming-messages、message-status、service；service 包含 **31 组集成测试**。
- release ArkTS 编译、最终包版本/权限检查、APP/HAP 签名验证及 `git diff --check` 通过。日志：`arkui/logs/M157-<测试名>.log`、`arkui/logs/M157-release.log`。
- **待真机验收**：覆盖安装后检查原重复会话是否归并，核对最新文件与详情，再收发文件确认只有一个会话更新；不同真实设备使用同名时应继续各自保留历史。

## 归档

- [正式 APP](../artifacts/release/AloeSend-2000157-release-20261016-193213-signed.app)
- [签名 HAP](../artifacts/release/AloeSend-2000157-release-20261016-193213-signed.hap)
- APP SHA256：`0D7E1AA0FD648601D09C94696378459719BD76612AEF31ED89654C1D921923BD`

未安装真机，源码未提交、未推送；保留原有工作区改动。
