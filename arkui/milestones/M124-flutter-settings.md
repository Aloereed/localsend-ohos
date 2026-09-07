# M124 · Flutter 设置继承

新增独立的 `flutter_settings_import_v1` 迁移标记，读取 FlutterSharedPreferences 的 `flutter.ls_*` 键。不会因为收藏、历史和消息的旧迁移已经完成而跳过设置迁移。

## 对应范围

| Flutter 选项 | 原生行为 |
| --- | --- |
| alias、theme、color、locale | 名称、明暗主题、系统/LocalSend/OLED/Yaru 配色、语言标签归一化 |
| quick_save、quick_save_from_favorites、receive_pin | 快速接收、收藏设备快速接收、文字 PIN |
| save_to_history、auto_finish、open_message_tab_on_incoming_files | 保留记录、自动完成、接收后打开消息 |
| save_to_gallery | 接收后提示通过系统确认保存相册 |
| enable_animations、lightweight_effects | 动画、减少视觉效果 |
| port、timeout、multicast_group、https | 端口、发现超时、组播、加密 |
| send_mode、device_type、device_model、advanced_settings | 发送模式、设备类型和型号、高级设置展开 |
| share_via_link_auto_accept | 浏览器分享自动接受 |
| destination | 保存目标目录；仍需有效系统权限，不伪造授权状态 |
| network_whitelist / network_blacklist | 单独列表转为包含/排除模式，保留空白名单的阻止发现语义 |

首次覆盖安装自动继承。已有原生设置键优先，包括 false 和空字符串；不能根据“值等于默认值”推断用户没改过。对于已经用过原生版的用户，设置 → 帮助与支持 → 从 Flutter 导入设置，在应用内确认后覆盖对应旧选项。进行传输、浏览器分享或证书重置时不可导入；持久化队列内再次检查，快照采用执行时的原生设置。

Flutter 默认不写入的语言跟随系统、自动完成关闭、相册提示开启和轻量效果开启，在能确认旧安装存在时补齐。其他原生专用选项、本机证书、收藏、消息和历史保持原状。网络新值通过现有待生效横幅提示重启服务。

格式或枚举无效的值计入未兼容，不进行宽松真假值或数字转换。两组同时生效且黑名单非空时，原生单模式无法无损表达，保留原生筛选并计入未兼容。桌面窗口位置、托盘、旧版 UI 开关等没有原生对应项，不迁移。Flutter 源文件不写入、不删除；写入失败恢复原生设置和迁移标记，可再次尝试。

## 验证

59 个主机测试全部通过，19.3 秒；最终 ArkTS 构建通过。新测试覆盖字段映射、中文 PIN、语言、列表编码、布尔 false、原生优先、旧标记补迁移、首次启动、重启保留改动、显式导入、写入失败回滚、无旧安装、非法字段、空白名单、组合列表、证书保留和原数据只读。修正初始化测试的模拟，使 Flutter 偏好读取与原生初始化尝试分别计数。

未访问设备，真实覆盖安装后的偏好文件与目录授权仍待用户验收。

产物：`artifacts/AloeSend-2000124-M124-flutter-settings-unsigned.hap`；版本 `2.0.124 / 2000124`。

SHA-256：`6F744603CFFE47DCD201E10F305AADBB4C8F3C70DBCBEA05C0F9AA5039AEC226`。
