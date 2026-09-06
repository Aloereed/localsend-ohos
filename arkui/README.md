# AloeSend 原生 ArkUI

当前建议先检查 **M24 / 2000024**：
[未签名 debug 包](artifacts/AloeSend-2000024-M24-appearance-options-unsigned.hap)。

完整的倒序下载路径、提交和 SHA-256 见 [包清单](PACKAGES.md)，各轮实现与验证见 [里程碑记录](milestones/)。

## 本轮修复与打磨

- **M21**：下载授权对话框已经创建目录时，复用目录，避免再次创建报 `File Exists`。同时处理并发建目录，并区分同名普通文件。
- **M21**：进度列表以会话/文件 ID 保持节点，读取最新状态，避免每次进度变化重新创建进度条；并行任务不再互相跳动位置。
- **M22**：原版 Logo 保留，统一浅深色表面、留白、分组列表、系统薄材质导航和悬浮通知；详情、设置、消息和发送页面同步调整。具体设计与平台兼容范围见 [设计说明](DESIGN.md)。
- **M23**：完成文件直接打开、零字节完成显示 100%、窄屏设备标题布局。继承此前自动发现、通知超时关闭、开关与选择器修复，以及五种发送类型单行滑动。
- **M24**：补齐轻量效果、OLED 纯黑背景和收藏设备发起会话；主题与会话专项回归通过。

## 明早建议检查

1. 安装最新包后，已有 `Download/com.aloereed.aloesend` 目录再次授权，应不再出现 `File Exists`；取消授权仍能接收到应用内。
2. 前台静置，应自动发现附近设备。发送大文件过来，确认接收后进入进度页；进度平稳更新，完成后文件可打开，下载目录内容完整。
3. 连续接收同名文件及带子目录文件，原有文件不被覆盖；测试传输取消和重试。
4. 检查浅/深色、平板侧栏与窄窗口底栏、横向发送入口、下拉选中值、高级设置开关、顶部提示自动消失。

最新代码通过 ArkUI 编译及全部 15 个宿主测试文件，包含实际 MbedTLS 128 MiB 二进制接收与 SHA-256 校验。宿主测试不能代替系统授权、后台任务、实际设备内存和视觉表现验证。本轮未使用 DevEco GUI，未签名、未部署；原版 Flutter 源码保留。

## 构建与验证

在仓库根目录的 PowerShell 执行：

```powershell
# 首次运行测试前构建宿主原生 TLS 模块（需要 MinGW、CMake 和 Node 头文件）
.\arkui\build-native-tests.ps1
& 'E:/Huawei/DevEco_Studio/tools/node/node.exe' --test (Get-ChildItem arkui/tests/*.test.cjs).FullName
.\arkui\verify-artifacts.ps1
```

新里程碑使用新的名称和递增版本号调用 `build.ps1`，完成验证并提交后用 `record-milestone.ps1` 记录源码提交。`verify-artifacts.ps1 -WriteCatalog` 刷新倒序清单。不要覆盖已归档版本。
