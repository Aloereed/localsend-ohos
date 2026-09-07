# M99 · 自定义网络配置说明

对照 Flutter settings_tab，非默认端口、组播地址旁显示对应发现影响说明，复用 settingsTab.network.portWarning / multicastGroupWarning 的 53 语言模板。默认值直接来自 AppSettings，避免提示与应用默认配置分离。

恢复默认按钮只恢复这两个表单字段，仍需保存网络设置后提交；不重置其他设置、不立即重启服务。动态翻译映射累计 8 项，完整翻译仍未完成。

验证：逐语言对比默认端口和组播地址的模板结果、同步检查通过；最终 ArkTS 未签名构建成功。未访问设备，实际文字换行及高级设置交互仍待验收。

产物：`artifacts/AloeSend-2000099-M99-network-hints-unsigned.hap`，版本 `2.0.99`。

SHA-256：`A3FFCDB17643DFF9E76688CBB064AABA2C951956A15C52F0750201A0620C2A29`。
