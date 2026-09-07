# 文件夹发送核对

基线：保留的 Flutter `app/lib/provider/selection/selected_sending_files_provider.dart` 与 `app/lib/util/send_ignore.dart`。

- Flutter 递归列出文件，发送名称包含顶层文件夹名及内部相对路径。原生系统文件夹选择的 `folderSelection` 和自定义下载目录 `downloadFolderFiles` 均保留这个层级。
- `SendIgnore.isIgnoreFile` 当前直接返回 `false`，规则并未加载；不能因为类存在就认为运行时支持 `.sendignore`。隐藏文件及 `.sendignore` 应照常进入发送清单。
- `selection-atomic.test.cjs` 已加入实际隐藏文件和 `.sendignore`，确认匹配其内容的普通文件仍发送，同时保留 M64 的失败整次回滚检查。
- 自定义下载目录遍历使用 `lstat` 并跳过符号链接，保护其目录边界。系统文件夹遍历使用 `stat` 跟随链接；Flutter 的目录遍历也默认跟随链接，但 Dart 自带循环检测。当前原生系统路径没有等价循环检测，这一差异仍待处理，不能据普通嵌套目录测试宣称全部遍历语义一致。
- HarmonyOS `fileIo.Stat` 提供 inode，但此 SDK 未提供设备编号。仅凭 inode 在可能跨卷的链接树中判断身份不够严谨，不能贸然用它跳过合法目录。需要进一步验证系统文档 URI 的链接能力与可用的规范路径接口。

本轮没有连接设备，没有更改文件夹选择产品行为，也没有为纯测试/核对变更生成新的安装包。最近可安装产物仍为 M69；完整目标继续进行。
