# 设备发现对照：LocalSend v1.18.2

后续状态：本报告列出的六项缺口已在 [M138](milestones/M138-discovery.md) 实现修复。以下保留修复前审查证据。

对照日期：2026-09-10。GitHub 最新正式版为 [v1.18.2](https://github.com/localsend/localsend/releases/tag/v1.18.2)。本地基于当前包含 M137 未提交修复的工作区。本次进行源码审查及主机故障注入，未修改产品实现，未连接用户设备。下面是可解释反馈的代码缺口，尚不能断言每个用户遇到的是同一个原因。

## 优先处理

| 优先级 | 本地缺口 | 与上游的差异及影响 |
| --- | --- | --- |
| P1 | 没有子网扫描兜底 | discover 仅发送 UDP 并探测收藏地址；没有收藏的新设备在组播被拦截时没有主动发现路径。上游提供组播、已知地址、等待后扫描本机 /24 的分阶段发现，扫描并发上限 50。HTTP/HTTPS 都会受影响。 |
| P1 | 组播失败后不恢复 | startNow 组播 bind/join 失败只记日志，接收服务仍标记 running；discover 和回前台只继续 announce，不重建 socket。运行中 UDP error 同样只记录，换网也只更新地址列表。上游具有组播失败通知和重启循环，1.18.2 发布说明亦包含服务恢复修复。 |
| P1 | 仅一个默认路由组播 socket | 本地绑定 0.0.0.0，加入一次组播组，没有逐接口加入、没有明确选择出站组播接口。上游每个可用 IPv4 地址建立 socket，设置 IP_MULTICAST_IF，逐接口发送。多网卡、VPN、热点/蜂窝并存时可能漏掉实际 Wi-Fi。当前 SDK MulticastSocket 暴露的 addMembership 仅接受组播 NetAddress，不能把其 address 简单替换成本机 IP 来实现指定接口。 |
| P2 | 单个网络属性读取失败会中止整个枚举 | getConnectionProperties 在 for 循环内没有单网隔离；较早的失效网络句柄抛错时，正常 Wi-Fi 不再读取，localIps/interfaces 保留旧值。默认筛选关闭时不一定单独导致发现中断；启用白名单/黑名单时，旧地址和同子网判断会直接影响放行。 |
| P2 | HTTP→HTTPS 发现纠正缺少反向注册 | register/probe 的早断连回退执行 verifyHttpsPeer，只 GET /info 后返回。本机保存对端，但未再向对端 POST /register；组播只通一个方向时，对方仍可能看不到本机。这一项与协议记录不匹配有关，不能解释所有非加密场景。 |
| P2 | IPv6 发现和接收缺失 | 出站 Transport 已能连接 IPv6，但自动发现只有 IPv4 UDP，接收监听也是 0.0.0.0；上游额外加入 ff12::fd3a:e420，保留链路本地 scope，并支持双栈监听。IPv6-only 或只有 IPv6 路径可用时存在明确功能差异。不能只添加 IPv6 广播而不补接收链路。 |

本地主要位置：[LocalSendService](AloeSend/entry/src/main/ets/network/LocalSendService.ets)、[EntryAbility](AloeSend/entry/src/main/ets/entryability/EntryAbility.ets)、[Addresses](AloeSend/entry/src/main/ets/network/Addresses.ets)。

## 本次主机复现

通过现有 host-runtime 加载实际 .ets 逻辑，替换 NetworkKit 故障边界，不访问局域网：

1. 首次组播 bind 注入 Wi-Fi 未就绪错误，之后调用两次 discover(false)：组播 socket 构造次数仍为 1，证实刷新不会重试初始化。
2. getAllNets 返回两个网络，首个属性读取抛错，第二个为正常 wlan0：只访问第一个句柄，证实正常网卡被跳过。
3. HTTP register 注入提前关闭，HTTPS info 返回正常：请求顺序为 HTTP POST register、HTTPS GET info，没有 HTTPS POST register，证实缺少双向发现收尾。
4. 合法 v2.2 数据报省略 announce：本机添加设备，反向注册次数为 0。这是额外的协议兼容性差异，但本次核对的上游发送代码携带 announce:true，故不把它列为最新版反馈的已确认原因。

上述复现只证明应用控制流缺口；路由选择、系统回收 socket、真实组播阻断和 IPv6 环境仍需设备证据。

## 建议修复顺序

先独立恢复发现 socket：初始化失败、error/close、网络变化和前台恢复应能触发重建，并避免为恢复发现而中断正在进行的文件传输。网络枚举按单网隔离错误；HTTPS 纠正后补发注册。

再补分阶段 IPv4 子网扫描，限制并发、超时、扫描频率和取消生命周期，遵守网络筛选及隐藏设置；未知目标分别处理 HTTPS 与 HTTP，不能把本机接收加密开关当作对方协议。已有 HTTPS 身份验证失败时应继续保留拒绝，不能降级绕过。

逐接口组播及完整 IPv6 属于后续网络层工作，需要验证 NetworkKit 能力边界，再选择最小原生补充方式。上次撤回 C++ 网络迁移的现状应保留为设计约束，不宜顺带重新迁移整套传输。

子网扫描也无法穿透 AP 客户端隔离或禁止设备间 TCP 通信的网络；如果手动 IP 同样失败，应区分网络可达性与自动发现失败。

## 上游依据

- [v1.18.2 discovery/mod.rs](https://github.com/localsend/localsend/blob/v1.18.2/packages/core/src/discovery/mod.rs)：分阶段发现、已知地址、/24 扫描、注册确认。
- [v1.18.2 multicast/socket.rs](https://github.com/localsend/localsend/blob/v1.18.2/packages/core/src/multicast/socket.rs)：逐网卡加入组播、出站接口绑定、IPv6。
- [v1.18.2 multicast/mod.rs](https://github.com/localsend/localsend/blob/v1.18.2/packages/core/src/multicast/mod.rs)：多次公告、兼容 announce 标记、错误通知。
- [v1.18.2 discovery.dart](https://github.com/localsend/localsend/blob/v1.18.2/packages/localsend_isolates/lib/src/task/discovery/discovery.dart)：发现服务重启循环。

下载的上游源码缓存位于本地忽略目录 arkui/logs/upstream-1.18.2/。
