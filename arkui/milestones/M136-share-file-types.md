# M136 · 系统分享接收通用文件

版本 2.0.136 / 2000136，包含 M135 的旧 HTTP 设备记录纠正。

用户反馈：在系统文件管理器中右键分享，无后缀或部分未知后缀文件无法调出 AloeSend；多文件选择中只要包含这类文件，也无法调出。

EntryAbility 的 sendData 分享声明原来仅覆盖 general.object 逻辑内容分支。增加 general.file 通用文件分支，保留已有图片、文本、链接等匹配配置，两类文件声明的 maxFileSupported 均为 100。general.file 属于物理存储类型分支，不由 general.object 覆盖。参考：[华为 UTD 预置列表](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/uniform-data-type-list)。

验证：incoming-share.test.cjs 通过，覆盖无后缀文件、未知后缀文件以及与 PNG、TXT 混合分享。测试执行实际导入及文件复制逻辑，检查原文件名、字节内容、大小和文件句柄释放。调试包已检查包含新增的 general.file 声明。鸿蒙 debug/release 构建及签名归档结果见 HANDOFF.md。

主机导入测试不能替代系统分享目标筛选验证。尚未安装新包，需真机从文件管理器分别分享无后缀文件、未知后缀文件及混合批次，确认 AloeSend 出现并正常拉起。

调试归档：[M136 unsigned HAP](../artifacts/AloeSend-2000136-M136-share-file-types-unsigned.hap)。
