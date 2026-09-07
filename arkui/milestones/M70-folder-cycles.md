# M70 · 系统文件夹链接循环检测

系统文件夹递归遍历增加祖先身份检测。HarmonyOS 使用已打开目录描述符的 `fstat` 设备编号与 inode，循环返回祖先时跳过，正常目录链接继续展开。每次身份读取均在 finally 中关闭目录，选择清单仍保持整次提交。

Windows 主机验证使用卷序列号与文件编号；Node 与 MinGW 的 CRT 描述符表不同，必须通过 Node 的 `uv_get_osfhandle` 取得实际句柄，不能直接使用 MinGW `_get_osfhandle`。

## 验证

- 真实目录 junction 验证祖先循环被跳过、正常链接目标文件保留、相对路径正确、目录及文件句柄归零。
- 不存在目录的选择失败保留原清单。
- 全部 40 个主机测试文件通过。完整回归发现 M66 后一条旧断言仍期待重置不恢复勾选，已按 Flutter 行为更新；请求助手保留 await 的异常，同时避免清理错误掩盖原断言。
- HarmonyOS 原生库和 ArkTS 编译通过；未连接设备。系统文档 URI 打开目录描述符的实际支持仍待实机检查。

产物：`artifacts/AloeSend-2000070-M70-folder-cycles-unsigned.hap`，版本 `2.0.70`。

SHA-256：`1DAE14A278E3015236B3E7BAFEC68F1D50E0DDB3745286564249D6411B749C0C`。
