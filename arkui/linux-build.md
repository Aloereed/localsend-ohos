# Linux release 构建与两机同步

在 Linux 仓库根目录执行：

```bash
python3 arkui/build-release.py
```

默认使用 `~/command-line-tools` 下已安装的 HarmonyOS SDK 和 Node，以及 `~/jdk-21`。可通过 `OHOS_COMMAND_LINE_TOOLS` 和 `JAVA_HOME` 指定已有工具；另需 Python 3 和 OpenSSL。

签名输入保存在忽略目录 `.signing/`。其中 `release.json` 的 `product` 为原发布配置中的 default product，`signing` 为其对应 signingConfig；material 的 `storeFile`、`profile`、`certpath` 支持相对仓库根目录的路径。将原证书、provision、keystore 和匹配的 DevEco `material/` 一同放入该目录。不得将此目录加入 Git。

构建脚本核对 release provision 的包名与签名证书、调用 assembleApp、检查新生成 APP 的版本/release 标志和必要权限，并通过官方工具验证 APP 和 HAP 签名。生成物及报告位于 `arkui/artifacts/release/`；原生 build-profile 在退出时恢复。

已验证：SDK 26 上构建 2.0.154 / 2000154 release APP，官方签名验证通过。`Index` 的内部辅助方法更名为 `resolveSystemMaterial`，避免与 SDK 26 的组件 API 重名。M137–M154 新增或修改的 34 个测试文件通过。

## Windows / Linux 共同维护 arkui

两机都跟踪 `origin/arkui`，使用 `git pull --ff-only`。切换机器开始修改前先提交并推送当前机器的改动，再在另一台机器快进拉取；不要在两机分别为同一批变更创建不同提交。

```bash
git switch arkui
git pull --ff-only
# 修改、验证、提交后
git push origin arkui
```

若出现分叉，先保留两边修改并检查历史；不要 force push 或覆盖另一台机器的工作区。M137–M154 累计变更和 Linux 适配按同一组提交对象同步，M136 及以前历史未重写。
