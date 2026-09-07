# 文件夹发送核对

基线：保留的 Flutter `app/lib/provider/selection/selected_sending_files_provider.dart` 与 `app/lib/util/send_ignore.dart`。

- Flutter 递归列出文件，发送名称包含顶层文件夹名及内部相对路径。原生系统文件夹选择的 `folderSelection` 和自定义下载目录 `downloadFolderFiles` 均保留这个层级。
- `SendIgnore.isIgnoreFile` 当前直接返回 `false`，规则并未加载；不能因为类存在就认为运行时支持 `.sendignore`。隐藏文件及 `.sendignore` 应照常进入发送清单。
- `selection-atomic.test.cjs` 已加入实际隐藏文件和 `.sendignore`，确认匹配其内容的普通文件仍发送，同时保留 M64 的失败整次回滚检查。
- 自定义下载目录遍历使用 `lstat` 并跳过符号链接，保护其目录边界。系统文件夹遍历使用 `stat` 跟随链接；Flutter 的目录遍历也默认跟随链接并检测循环。M70 增加当前祖先目录的身份检查，跳过回到祖先的链接，正常目录链接仍展开。
- HarmonyOS `fileIo.Stat` 未提供设备编号，M70 通过已打开目录描述符调用原生 `fstat`，组合 `st_dev` 和 `st_ino`，避免跨卷 inode 相同造成误判。Windows 主机测试通过 Node 的 `uv_get_osfhandle` 获取正确 CRT 句柄，再组合卷序列号与文件编号。
- 本机真实 junction 测试验证祖先循环、正常链接、路径层级及零句柄泄漏。HarmonyOS 编译通过，但系统文档 URI 打开目录描述符的实机行为仍待用户检查。

未连接设备。M70 提供包含循环检测的未签名包；完整目标继续进行。
