# M144 · 热点网卡发现

用户反馈：138 版在手机自己开启热点时，既发现不了其他设备，也无法被发现。

代码确认的缺口：readAddresses 仅通过 connection.getAllNets/getConnectionProperties 读取地址。[OpenHarmony 网络管理接口说明](https://github.com/openharmony/communication_netmanager_base/blob/master/README.md) 定义的是连接网络的 NetHandle 列表。热点下游接口若未出现在列表中，本端不会为其加入组播，也无法计算其扫描网段；这是与反馈吻合的原因推断，尚无反馈者真机日志验证。

修复：现有发现 C++ 桥新增 networkInterfaces，鸿蒙使用 getifaddrs/freeifaddrs 枚举 UP、非回环接口，返回 IPv4/IPv6、前缀及 link-local 作用域；不要求互联网连接、不硬编码热点名称或网段、不申请热点管理权限。Windows 主机测试使用 GetAdaptersAddresses。与 NetworkKit 按接口和地址去重，保留原生作用域/前缀，按整张网卡重新应用用户允许/拒绝规则。一个来源失败仍使用另一个；两者均失败时保留原状态并记录错误。

合并后的列表接入原有逐接口组播、有限子网扫描、IPv6 监听和本机地址展示。15 秒自动发现及手动刷新都会重读，热点关闭/重开后清理旧绑定并加入新接口。原生改动仍限定于发现支持，TCP/TLS 发送继续使用 NetworkKit。

验证：hotspot-discovery 覆盖没有上游网络、仅有蜂窝上游、未出现在 NetHandle 中的热点、双来源去重、IPv6 scope、允许/拒绝规则、来源失败及热点移除/替换；通过组播绑定与扫描目标断言。discovery-native 实际枚举 Windows 网卡并与系统地址/前缀对照，真实双接口 IPv4/IPv6 组播及重复解绑通过。discovery-recovery、discovery-scan、discovery-stages、discovery-ipv6、saved-network-settings、web-ipv6 回归通过。共八个测试文件，日志 logs/M144-*.log。

2.0.144 / 2000144 release 编译及 APP/HAP 签名验证通过，包见 HANDOFF。主机测试不等同于手机热点实测；需反馈者升级后在热点开启、其他设备接入时刷新发现，并核查连接诊断中的热点接口/IP。如果仍失败，应基于该诊断继续区分接口枚举、组播、路由或设备热点访问限制。
