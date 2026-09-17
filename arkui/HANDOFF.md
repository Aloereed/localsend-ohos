# M154 正式包交接

版本 2.0.154 / 2000154。发布 Release 配置已使用 aloesend5Release.p7b，本次也补入通用 build-profile.json5.template。设置 → 外观新增默认开启的“使用 #尾号区分地址”：开启分地址显示，关闭按指纹合并并展示多地址，立即生效并持久保存。保留端点列表供切换，十六进制证书指纹忽略大小写。详见 [M154](milestones/M154-device-display-mode.md)。

七个相关测试文件通过，正式构建、APP/HAP 签名及内嵌 p7b 一致性校验通过。最终包：[APP](artifacts/release/AloeSend-2000154-release-20260915-220501-signed.app)、[HAP](artifacts/release/AloeSend-2000154-release-20260915-220501-signed.hap)。APP SHA256 `178407C8C9B6655203D87C5B3DD2D3D84CC034245404166E10CAEA9263FA8E22`。未安装真机，源码未提交。

# M153 历史交接

版本 2.0.153 / 2000153。确认 LocalSend 旧版的 IPv4 尾号标记用法后，在 AloeSend 接收页设备名下、发送页附近/收藏设备卡片加入 `#12` 等标记；多本机尾号去重，保留完整地址，IPv6 不生成短号。见 [M153](milestones/M153-device-address-tags.md)。

格式化边界检查、release 构建及 APP/HAP 签名验证通过，内嵌 profile 与用户指定的 aloesend5Release.p7b 一致。正式包：[APP](artifacts/release/AloeSend-2000153-release-20260915-215815-signed.app)、[HAP](artifacts/release/AloeSend-2000153-release-20260915-215815-signed.hap)。APP SHA256：`012FA54302BD2FB69F6C50C225C8104E90080095957CE9D158E23C3B9733D7AB`。未连接/安装真机，源码未提交；M152 的真机首次发现计时仍未完成。

# M152 历史交接

发布签名更新：用户指定 `C:/Users/huzheng/Downloads/aloesend5Release.p7b`，已替换 `app/ohos/build-profile.Release.json5` 的 profile 路径并重打，版本仍为 2.0.152。最新包：[APP](artifacts/release/AloeSend-2000152-release-20260912-221935-signed.app)、[HAP](artifacts/release/AloeSend-2000152-release-20260912-221935-signed.hap)。正式构建、APP/HAP 签名验证通过，提取的两个内嵌 p7b SHA256 均与用户指定文件一致。APP SHA256：`5C60C41706FB3AA9FD34E0BAA0CCD97C99D4F9751A1A0AA624D0E4A31D985F5B`。本次未安装设备。

版本 2.0.152 / 2000152。用户要求继续加快首次发现；自动未知地址先用 350 ms 无载荷 TCP 检查过滤空端口，开放后才进行完整注册。短检查漏答地址进入正常超时补查阶段，已知/收藏/手动绕过。保留 2 并发和正常操作避让，诊断增加仅清除发现缓存并重启发现的入口。见 [M152](milestones/M152-fast-first-discovery.md)。

九个相关测试文件通过，正式构建及 APP/HAP 签名通过。[APP](artifacts/release/AloeSend-2000152-release-20260912-220712-signed.app)、[HAP](artifacts/release/AloeSend-2000152-release-20260912-220712-signed.hap)。已请用户安装 152 后继续真机无缓存测量（此前 hdc 发布包安装被 9568322 拒绝），尚未验证真机提速数字。源码未提交。

# M151 历史交接

版本 2.0.151 / 2000151。已真机复现 150 冷启动后超过两分钟才发现 Windows .12；Windows TCP 正常但未见 UDP 监听，不能将我主动诊断的 GET 当作官方注册。保留扫描限速，改为邻近地址优先，并持久保存最多 16 个已验证端点作为下次扫描顺序提示；提示不直接显示在线、不固定旧身份。增加注册成功耗时日志，详见 [M151](milestones/M151-device-discovery.md)。

八个相关测试文件通过，正式构建及 APP/HAP 签名通过。[APP](artifacts/release/AloeSend-2000151-release-20260912-215524-signed.app)、[HAP](artifacts/release/AloeSend-2000151-release-20260912-215524-signed.hap)。hdc 安装因 9568322 拒绝，随后用户自行装好 151，未卸载/清数据。真机首次约 38 秒主动注册发现 .12，保存地址后再次启动约 3 秒；HTTPS 注册分别 158/154 ms，确认无需 Windows 刷新。Windows UDP 缺失的内部原因仍未知，首次新设备不保证秒发现。用户已授权真机与常亮；源码未提交。

# M150 历史交接

版本 2.0.150 / 2000150。用户确认本机鸿蒙 AloeSend、对端 LocalSend 1.18.2，有时对端进入发送页后才相互发现。可见模式主动探测改为直接注册，一次连接交换身份；收到公告后的失败注册增加有界、低频定向重试，忙时取消让步，网络变化/停止清空。保留 M149 子网扫描限速，详见 [M150](milestones/M150-reciprocal-discovery.md)。

12 个相关测试文件通过，release 编译与 APP/HAP 签名校验通过。正式包：[APP](artifacts/release/AloeSend-2000150-release-20260912-213555-signed.app)、[HAP](artifacts/release/AloeSend-2000150-release-20260912-213555-signed.hap)。未安装设备，未完成与官方 1.18.2 的真机复测，不能断言现场问题全部解决。源码未提交。

# M149 历史交接

版本 2.0.149 / 2000149。用户确认 M148 已解决选一个小文件后的长等待，要求进一步优化扫描不影响正常功能。自动子网扫描改为 2 并发、100 ms 请求间隔，每批最多 16 地址/6 秒；批间至少 10 秒、完整扫描后至少 60 秒冷却。手动扫描最多 4 并发、25 ms 间隔。忙时中止在途探测并保留未完成地址，网卡交替扫描。详见 [M149](milestones/M149-background-discovery.md)。

十个相关测试文件完成验证：discovery-priority、discovery-automatic、discovery-scan、selection-discovery、discovery-stages、discovery-recovery、discovery-ipv6、hotspot-discovery、interactions、selection-cancel。priority 的旧时间断言按“完成后冷却”调整后复测通过。release 编译及 APP/HAP 签名验证通过。正式包：[APP](artifacts/release/AloeSend-2000149-release-20260912-211923-signed.app)、[HAP](artifacts/release/AloeSend-2000149-release-20260912-211923-signed.hap)。未安装此包或测量真机性能，源码未提交。

# M148 历史交接

版本 2.0.148 / 2000148。用户反馈 147 选择一个 1.4 MB 文件后长等待，稍后恢复。只读获取已连接设备 hilog，见照片选择器返回和同期密集扫描；无法从现有日志精确归因。修复选择/附件读取期间仍可进行子网扫描的资源竞争：选择开始取消在途扫描和兜底计时，选择期间延后前台自动发现，结束后保留 3 秒界面恢复空档。增加超过 500 ms 的文件打开/属性/关闭耗时日志，不记录文件路径。详见 [M148](milestones/M148-selection-discovery.md)。

selection-discovery、selection-cancel、selection-atomic、selection-limits、folder-selection、discovery-automatic、interactions 七个测试文件通过；release 编译及 APP/HAP 签名通过。正式包：[APP](artifacts/release/AloeSend-2000148-release-20260912-211128-signed.app)、[HAP](artifacts/release/AloeSend-2000148-release-20260912-211128-signed.hap)。未安装此包，未测真机前后耗时，不声称已确认全部根因。源码未提交。

# M147 历史交接

版本 2.0.147 / 2000147。发送页“附近的设备”标题旁新增随主题色显示的“传输有问题？”按钮，进入现有使用帮助页。帮助顶部新增三项常用建议：可信局域网内双方关闭加密并完全退出重启（Windows 含托盘退出、可能加快传输及明文说明）、接收设备发送页刷新、双方更新应用。简繁中文和英文已补齐。

flutter-locales、flutter-templates 测试、release 编译和 APP/HAP 签名验证通过。正式包：[APP](artifacts/release/AloeSend-2000147-release-20260912-210213-signed.app)、[HAP](artifacts/release/AloeSend-2000147-release-20260912-210213-signed.hap)。未安装真机，源码未提交。

# M146 历史交接

版本 2.0.146 / 2000146。修复自动发现中“有一个设备确认即跳过整个子网扫描”的条件，已知设备响应不再阻止发现漏掉组播的新设备。保留一分钟自动扫描冷却、16 并发及传输期间暂停；组播监听每分钟主动重建，定时任务异常写诊断，下一轮继续。见 [M146](milestones/M146-automatic-discovery.md)。

discovery-automatic、discovery-stages、discovery-scan、discovery-recovery、discovery-ipv6、hotspot-discovery、interactions、add-address 八个测试文件通过，release 编译及 APP/HAP 签名验证通过。正式包：[APP](artifacts/release/AloeSend-2000146-release-20260912-205718-signed.app)、[HAP](artifacts/release/AloeSend-2000146-release-20260912-205718-signed.hap)。包含热点及地址添加修复；未安装真机，源码未提交。

# M145 历史交接

版本 2.0.145 / 2000145。修复地址添加路径对空编码结果读取 length：空请求体直接生成零长度字节数组，空响应直接解码为空字符串；证书数据缺失时明确失败并禁止按裸地址回退明文。HTTPS 初次探测错误写入诊断。详见 [M145](milestones/M145-add-address.md)。

add-address、addresses、protocol-upgrade、mutual-tls、file-checksum、service 六个测试文件通过，其中 service 31 组。release 编译及 APP/HAP 签名校验通过。正式包：[APP](artifacts/release/AloeSend-2000145-release-20260912-205140-signed.app)、[HAP](artifacts/release/AloeSend-2000145-release-20260912-205140-signed.hap)。包含 M144 热点发现改动。无当前已连接设备，用户只确认点击添加后报错，未提供加密状态或调用栈；空编码返回值为主机注入复现条件，不能声称已确认真机根因。源码未提交。

# M144 历史交接

版本 2.0.144 / 2000144。针对 138 用户反馈“手机开热点双向不可发现”，补齐不在 getAllNets 列表中的系统网卡：鸿蒙使用 getifaddrs 获取运行中非回环 IPv4/IPv6 地址、作用域和掩码，与 NetworkKit 合并后统一过滤并用于组播、扫描及本机地址。现有 15 秒发现刷新可处理热点切换。详见 [M144](milestones/M144-hotspot-discovery.md)。

八个相关测试文件通过，包括热点拓扑、发现恢复/扫描/阶段/IPv6、保存网络设置、网页 IPv6 和原生真实网卡枚举/组播。release 编译、APP/HAP 签名校验通过。正式包：[APP](artifacts/release/AloeSend-2000144-release-20260912-203909-signed.app)、[HAP](artifacts/release/AloeSend-2000144-release-20260912-203909-signed.hap)。未安装鸿蒙真机，未确认反馈者设备上的实际根因已全部解决；源码未提交。

# M143 历史交接

版本 2.0.143 / 2000143。网页文件列表新增“全部下载（ZIP）”，单次确认下载整批文件；文字继续提供网页复制。使用流式 ZIP64，不缓存整批文件，不需要浏览器允许多个自动下载。复用现有链接有效期、下载确认/自动允许、进度和取消。详情见 [M143](milestones/M143-web-batch-download.md)。

web-batch、web、web-page、web-language、web-template 五个测试文件通过，release 编译及 APP/HAP 签名验证通过。正式包：[APP](artifacts/release/AloeSend-2000143-release-20260911-194902-signed.app)、[HAP](artifacts/release/AloeSend-2000143-release-20260911-194902-signed.hap)。源码未提交，未安装设备，真机浏览器保存仍待验证。

# M142 历史交接

版本 2.0.142 / 2000142。网页模板的“导入网页”“导出模板”和“恢复默认网页”按钮显式绑定 AppStore.accentText/controlSurface，与页面其他次级按钮一致，随主题更新。主题颜色对比度测试、release 编译及 APP/HAP 签名验证通过；真机视觉待验证。

正式包：[APP](artifacts/release/AloeSend-2000142-release-20260911-194255-signed.app)、[HAP](artifacts/release/AloeSend-2000142-release-20260911-194255-signed.hap)。源码未提交，未安装设备。

# M141 历史交接

版本 2.0.141 / 2000141。接收页快捷操作列表顶部增加“通过链接分享”，复用发送页的 web 路由和同一个链接收发页面，沿用已有翻译和链接图标。返回后仍在接收页。

9 组浏览器分享集成检查通过，release 编译、APP/HAP 签名校验通过。正式包：[APP](artifacts/release/AloeSend-2000141-release-20260911-193920-signed.app)、[HAP](artifacts/release/AloeSend-2000141-release-20260911-193920-signed.hap)。未安装真机，源码尚未提交。

# M140 历史交接

后续维护约束：默认只跟进原版的简体中文、繁体中文和英文本地化；其他原版功能与语言变更均等用户明确要求再同步。保留已有语言资源。

版本 2.0.140 / 2000140，已完成 LocalSend 1.18–1.18.2 适用于当前鸿蒙应用的新增功能及平台对应实现，包含 M137–M139 的 TLS、沉浸导航、发现与文件持久权限修复。详见 [M140](milestones/M140-localsend-118.md)、[功能对齐清单](localsend-1.18-feature-audit.md)、[平台对应](platform-1.18.md) 和 [网页模板说明](web-template.md)。

正式签名包：[APP](artifacts/release/AloeSend-2000140-release-20260911-192730-signed.app)、[HAP](artifacts/release/AloeSend-2000140-release-20260911-192730-signed.hap)。release 编译及 APP/HAP 签名验证通过。76 个测试文件完成验证：73 文件批次中三项失败修复后复测通过，另两个新增测试及原生组播测试单独通过。

APP SHA-256：`03B6128F8BACEC23868CB8CFFF9721D24290ACDEDD67EF539AB0FCDB66835398`。HAP SHA-256：`1176D35924ABEFB5566A8247666A1F1072D8BF6AE979CBA8878CA6FC6CE81533`。

源码尚未提交，sourceDirty=true，用户原有 output/ 保持未跟踪。未安装设备或推送；鸿蒙真机跨端互传、导航观感、重启后目录访问及桌面快捷入口待设备验证。

# M139 正式包交接

版本 2.0.139 / 2000139。恢复 FILE_ACCESS_PERSIST 声明、系统保存目录选择后的持久化授权，以及导出前的授权激活。保留下载目录回退和应用内接收文件。四项相关主机测试、最终 release 编译及 APP/HAP 签名校验通过，实际鸿蒙重启后访问待验证。详情见 [M139](milestones/M139-file-access-persist.md)。

正式签名包：[APP](artifacts/release/AloeSend-2000139-release-20260911-003834-signed.app)、[HAP](artifacts/release/AloeSend-2000139-release-20260911-003834-signed.hap)。包含前轮 M137/M138 修复，源码修改未提交。

# M138 历史交接

版本 2.0.138 / 2000138。发现机制补齐六项差异：组播恢复、分阶段子网扫描、逐网卡组播、单网错误隔离、HTTPS 纠正后的反向注册、IPv6 发现与接收。包含前轮 M137 修复，详情见 [M138](milestones/M138-discovery.md)。

68 个主机测试文件通过（66 文件完整批次、stages 单独执行、native 组播放行本机网络执行）。主机真实双接口 IPv4/IPv6 组播通过；IPv4/IPv6 HTTP/HTTPS 双向发现与文件内容验证通过。鸿蒙 debug/release 编译、APP 与模块签名校验通过。

正式签名包：[APP](artifacts/release/AloeSend-2000138-release-20260910-230203-signed.app)、[HAP](artifacts/release/AloeSend-2000138-release-20260910-230203-signed.hap)。APP SHA-256：28128283AFB06CA8C5BDC714AFC7D1EAF758B53B091E14058E0A5B6232FD5264。

源码修改未提交，sourceDirty=true。用户原有 output/ 保持未跟踪。未安装设备、未推送远程；鸿蒙真机与 LocalSend 1.18.2 跨端互操作待装包检查。原生补充限定于组播发现及既有 HTTPS 背压接收的 IPv6 地址支持，未重做 M130 整套网络迁移。

# M137 历史交接

版本 2.0.137 / 2000137。出站 HTTPS 携带本机证书和私钥，适配 LocalSend 1.18 强制客户端身份；隐藏系统手势条并在页面加载后和回前台重新应用。详情见 [M137](milestones/M137-mutual-tls-immersion.md)。

63 个主机测试文件通过（完整回归中的 interactions 旧模拟缺少身份上下文，修正模拟后单独复测通过）。debug/release 编译、APP 与模块 HAP 签名校验通过。沿用 Flutter 发布身份，源码修改尚未提交，sourceDirty=true。

正式包：[APP](artifacts/release/AloeSend-2000137-release-20260910-215558-signed.app)、[HAP](artifacts/release/AloeSend-2000137-release-20260910-215558-signed.hap)。APP SHA-256：2EC89A5DAB90B2E50B470FF3D9B4209FB0E46C4895045B358260BB6E2A308049。

未安装设备、未推送；HarmonyOS NetworkKit 与 LocalSend 1.18 实际互传、系统栏真机显示仍待确认。用户原有 output/ 保持未跟踪。

# M136 历史交接

版本 2.0.136 / 2000136，源码 `1388b8e0f72606c97e020d4a58fa476cf97ab739`。系统分享入口补充 general.file 通用文件声明，覆盖无后缀、未知后缀及混合文件分享的类型匹配缺口。详情见 [M136](milestones/M136-share-file-types.md)。包含 M135 的旧 HTTP 设备记录纠正。

正式签名包：[APP](artifacts/release/AloeSend-2000136-release-20260909-202151-signed.app)、[HAP](artifacts/release/AloeSend-2000136-release-20260909-202151-signed.hap)。release 构建、APP 与独立 HAP 签名验证通过，沿用 Flutter 发布身份；模块版本、包名、debug=false 和权限检查通过。APP SHA-256：`63671F0C202CEDC1C9C60068F244663DBABDA60C4B7D23C4BC94C96C846FD0E6`；HAP SHA-256：`3965F336CE04CEBE47066A404FFBA29437619B6EF5275FFCAB8E8FED932E22F2`。

incoming-share.test.cjs 已通过，验证单个无后缀、未知后缀和混合文件导入后的文件名、字节内容、大小及句柄释放。鸿蒙调试编译通过，调试归档：[M136 unsigned HAP](artifacts/AloeSend-2000136-M136-share-file-types-unsigned.hap)，SHA-256：`444CCD2FD9A0EB1CA44EF02A26B339CB29C6A7707830786FE5B73037966D2143`。14 个里程碑归档包校验通过。

系统分享目标筛选和应用拉起仍待真机验证；需要安装新包后，从系统文件管理器分别分享无后缀、未知后缀及混合批次。本轮未安装新包、未上传或推送。构建时源码已提交，包清单正在更新，用户原有 output/ 保留未跟踪，因此正式包元数据 sourceDirty=true。

# M135 历史交接

版本 2.0.135 / 2000135，源码 `855e8e0681d05a8a510ba678b4f0c3cb2ea974f7`。旧 HTTP 记录连接 HTTPS 设备提前断连时，验证 HTTPS 和证书后更新设备协议并重新发起接收请求。详情与限制见 [M135](milestones/M135-protocol-upgrade.md)。

正式签名包：[APP](artifacts/release/AloeSend-2000135-release-20260909-201019-signed.app)、[HAP](artifacts/release/AloeSend-2000135-release-20260909-201019-signed.hap)。沿用 Flutter 发布身份，APP 与独立 HAP 签名验证通过；模块版本、包名、debug=false 和权限检查通过。APP SHA-256：`B95480681723A9FA66AEA54151437442B0B8BB9BA96E1D236333386F031D846C`；HAP SHA-256：`655FC8A649FAFF49A724652D29467268FBB48F0F0A0E439CD7F85DD3C56C6FA2`。

三个针对性主机测试文件（含 30 组 service 集成检查）、鸿蒙 debug/release 编译通过。调试归档：[M135 unsigned HAP](artifacts/AloeSend-2000135-M135-protocol-upgrade-unsigned.hap)，SHA-256：`C8C87062D178EA42A8C69EE51AE17184E0CEEDB93FFDC7F0D76C746A3486713E`。13 个里程碑归档包校验通过。此前沿用 2000134 的临时验证包移至 artifacts/experiments，避免与正式 M134 归档混淆。

构建元数据 sourceDirty=true：构建时源码已提交，包清单正在更新，用户原有 output/ 保留未跟踪。未安装、上传或推送新版本。排查时只读查询过连接的鸿蒙设备日志，未获得这次断连的定位日志；Android 1.17.0 和 Windows 1.16.1 真机回归仍待完成，旧 HTTP 状态的来源尚未确认。

# M134 历史交接

版本 2.0.134 / 2000134，源码 `61d1a58aa57e8a3c317175bf4e3a8ebc1957da41`。设置入口只显示“进群吐槽”，隐藏下方群号，保留 QQ 拉起及失败提示；包含 M133 的“支持作者”页面。详见 [M134](milestones/M134-feedback-label.md)。

正式签名包：[APP](artifacts/release/AloeSend-2000134-release-20260908-232754-signed.app)、[HAP](artifacts/release/AloeSend-2000134-release-20260908-232754-signed.hap)。沿用 Flutter 发布身份，APP 与独立 HAP 签名校验通过，APP 内模块版本、包名、debug=false 和权限检查通过。APP SHA-256：`65A4B1A0A43A4AB9744B691472ACD3491D603EA7B0D2281C462100D1A94BD7D0`；HAP SHA-256：`3FE87433E5E84A286E83041382B1708752AB25E74A30FAC671396949F71908BF`。

两项语言测试及调试、release 构建通过。调试归档 [M134 unsigned HAP](artifacts/AloeSend-2000134-M134-feedback-label-unsigned.hap)，12 个归档包校验通过。构建元数据 sourceDirty=true：仓库保留用户原有未跟踪 output/，源码修改已提交，包清单在归档阶段更新。未访问设备、未上传或推送远程，实际 QQ 拉起及支持页面跳转仍待真机验证。

# M133 历史交接

版本 2.0.133 / 2000133。ArkUI 支持界面统一显示“支持作者”，跳转 AloeSend 作者的指定链接；帮助与支持新增“进群吐槽”，拉起 QQ 群 936959829，失败时提示手动搜索。英文文案已同步。详情见 [M133](milestones/M133-author-support.md)。

两项语言测试、链接与 QQ 拉起的主机断言、鸿蒙调试编译通过。未访问设备，实际外部页面跳转和 QQ 群资料页拉起仍需真机验证。

调试包：[M133 unsigned HAP](artifacts/AloeSend-2000133-M133-author-support-unsigned.hap)，SHA-256：`F509E2BB3AE1D62674FE778949F809F80A19E23A604FB30D636F0C0AE25521A3`。本次未生成正式签名 APP；最新正式包仍为下述 M132。

# M132 历史交接

最新正式包：[2.0.132 signed release APP](artifacts/release/AloeSend-2000132-release-20260908-002452-signed.app)，源码 `eb7ca12873fa4a4c2f23c0cf0f07bff0d986b093`，构建前工作区干净。沿用 Flutter 发布签名，APP 与独立模块 HAP 签名验证通过。SHA-256：`B555F397CE20261FED05121D8041CC4A26B6153F3B8350D85FA2EE947D3361EC`。

按用户要求先备份 `codex/backup-arkui-cpp-20260908`（`9b0a7a48`），再撤回 M130 新增 C++ 迁移。cpp 和 ets/network 已恢复至 `bfb9b164`：NetworkKit 发送、HTTP 接收和 UDP 发现，保留此前已有 C++ HTTPS 接收背压。文案、999 项选择和底栏布局与备份分支一致。

用户此次明确要求恢复 INTERNET，取代 M131 的移除要求。最终包仅声明 INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING；仍无 READ_PASTEBOARD / FILE_ACCESS_PERSIST。

60 个主机测试、鸿蒙编译和签名校验通过。未访问设备。实际 NetworkKit 传输和底栏缩放效果待用户部署检查。调试归档 `artifacts/AloeSend-2000132-M132-networkkit-rollback-unsigned.hap`，SHA-256 `F03F4E7A1DFDB59E8FEA649E0A9D4687C32217693CD2B658B909FEC96E1C76EB`。细节见 [M132](milestones/M132-networkkit-rollback.md)。

# M131 历史交接

最新发布包：[2.0.131 signed release APP](artifacts/release/AloeSend-2000131-release-20260908-001733-signed.app)，源码 `4afc50b247501c1f324c48cdaa6df289b7800d60`，构建前工作区干净。沿用 Flutter 发布签名，APP 与独立 HAP 签名验证通过。SHA-256：`63146A53855AA9BE7D3F956E6D877C9FD460B4039FDD19BB445C97C274A3938B`。

用户最新明确要求移除 INTERNET，已执行且发布脚本会拒绝包含 INTERNET 的包。最终仅声明 GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING，不含 READ_PASTEBOARD / FILE_ACCESS_PERSIST。不要因为历史 M129/M130 的保留说明再次加回。未验证鸿蒙无 INTERNET 权限时的设备发现与传输行为。

包含 M130 完整 C++ 网络迁移，以及 M131 旧版本导入文案、语言菜单“繁體中文”、999 文件/附件选择、图库 500+499 分批选择。图库单次 500 是系统上限，选满后在应用提示中选择继续添加。取消下一批保留上一批，取消本次读取保留原发送清单。

底栏根据当前窗口宽度重新传入 HDS 三个档位的明确栏宽和居中间距，兼容底栏共用计算，容器限制绘制范围。六个针对性主机测试和鸿蒙编译通过；主机几何测试跨越大窗口到窄屏。系统玻璃背景实际渲染、手机窄屏表现和无 INTERNET 权限的网络行为仍待用户设备确认，未访问设备。

调试包 `artifacts/AloeSend-2000131-M131-selection-layout-unsigned.hap`，SHA-256 `2246EAD4562753A1B3645EBE7C1E65ABC841F1780B09B655DD6131E6C88D182C`。详情见 [M131](milestones/M131-selection-layout.md)。

# M130 历史交接

最新发布包：[2.0.130 signed release APP](artifacts/release/AloeSend-2000130-release-20260908-000306-signed.app)，源码 `28d1d3079dabfc41d81dc582ba50a15a1213e786`，构建前工作区干净，沿用 Flutter 发布签名。SHA-256：`23AD28806E081EE04576578C138A3924B1E0DB397015991C72605480F7A5FD73`。

C++ 网络迁移完成：TCP/TLS 发送、HTTP/HTTPS 接收、浏览器 HTTP/HTTPS 分享和 UDP 发现 I/O 都走原生库；ArkTS 保留界面、协议状态和网卡信息查询。60 个主机测试文件通过；HTTP、HTTPS 各 3 GiB 慢写盘测试哈希一致，队列峰值分别 65,536 / 65,750 字节，文件句柄归零。组播回环在本机和独立 Node 对照均不可用，实际局域网发现仍待设备检查。未访问设备。

APP 和独立 HAP 签名验证通过；最终权限为 INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING，不含两个待审权限。没有以 C++ 主机测试推断鸿蒙可以删除 INTERNET。调试包 SHA-256 `EBC778D47B303FDC77D9C6B4EE21005E6066FDF03E2D745C010182B3F5DB2F4C`。细节见 [M130](milestones/M130-native-network.md)。

# M129 历史交接

最新发布包：[2.0.129 signed release APP](artifacts/release/AloeSend-2000129-release-20260907-233453-signed.app)，源码 `0ef0766c97ad1d0ea2621a8492fb474372d01360`，构建前工作区干净，沿用 Flutter 发布签名。SHA-256：`42D0540C9183BA8BAF827E396B2C798232DFBFE1CBDE7626B81F97EC8B585435`。

用户最新明确要求恢复原生 INTERNET，此要求取代 M128 的删除要求。最终模块仅声明 INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING；READ_PASTEBOARD 和 FILE_ACCESS_PERSIST 仍不声明。debug=false、版本和包名检查通过，APP 与独立 HAP 签名检查通过。未访问设备。

调试归档：`artifacts/AloeSend-2000129-M129-restore-network-permission-unsigned.hap`，SHA-256 `F9A51B7ECE7B822C5A72DF38D71975F56DE35B19C5A81E647767B0C9849FA207`。

## M128 历史交接（权限要求已被 M129 取代）

最终发布包：[2.0.128 signed release APP](artifacts/release/AloeSend-2000128-release-20260907-232654-signed.app)，源码 `25e3258a23e29c40e8abd5d75779e23089330b01`，构建前工作区干净，沿用 Flutter 发布签名。SHA-256：`D3900AF4674CEB25174A31307AC7177F01F31540F216E1B438DFDA7843F5B31E`。

按用户明确要求删除 INTERNET。最终内嵌模块仅声明 GET_NETWORK_INFO 和 KEEP_BACKGROUND_RUNNING，debug=false，版本 2.0.128 / 2000128；APP 与独立 HAP 签名校验通过。未访问设备，未验证删除权限后的设备端联网行为。此前对局域网权限的说明已告知用户，用户仍明确要求删除；不要擅自恢复权限。

## M127 历史交接

最终上架包：[2.0.127 signed release APP](artifacts/release/AloeSend-2000127-release-20260907-232231-signed.app)。源码 `a7b7ccf6fd89a53a73b2de74e89d75abd6983251`，构建前工作区干净，沿用 Flutter 发布身份。SHA-256：`EF1824470108070AF458B8E6F48BDB18F2F10FA9ED85086F1AFFB8D80FDF9AE4`。

最终 APP 内模块检查通过：debug=false，版本 2.0.127 / 2000127，只有 INTERNET、GET_NETWORK_INFO、KEEP_BACKGROUND_RUNNING 三个权限声明，不含用户仍在申请的 READ_PASTEBOARD / FILE_ACCESS_PERSIST。APP 及独立模块 HAP 签名验证通过。59 个主机测试通过，未访问设备，未上传商店。系统粘贴按钮和 DOWNLOAD 授权实机交互仍待检查。

调试包：[M127 unsigned HAP](artifacts/AloeSend-2000127-M127-store-permissions-unsigned.hap)，SHA-256 `292159D7C09BC8875777B084E6E3F50EAF2AC50963C18162662351C2623180A8`。

## M126 历史交接

已按用户要求另行生成使用 Flutter 发布签名的 [2.0.126 release APP](artifacts/release/AloeSend-2000126-release-20260907-225915-signed.app)。构建源码 `d74af5b77942b67b3e6b05e589507b998a79b7fc`，构建前工作区干净。APP 与独立模块 HAP 签名验证均通过，APP 签名证书与 Flutter release profile 一致。原生日常配置已恢复。SHA-256：`1ACECA630C48EF99B5EF2A8E576803A155756CB886AF6B038657CEFF1E426F12`。这是本次应交付的正式签名包；release 目录更早的 unsigned 或试打包不是最终交付。

最新包：[AloeSend-2000126-M126-bottom-immersion-unsigned.hap](artifacts/AloeSend-2000126-M126-bottom-immersion-unsigned.hap)，版本 2.0.126 / 2000126，产品源码 `3772c4c5`，分支 `arkui`。

SHA-256：`324937E353BF6D410CFC30E8B4CB9A15F830B818B55E3155CE9DAA87E872D572`。

M126：根页面 matchParent 延伸到底部系统栏，窗口背景同步页面底色，保留内容避让；窗口及前台生命周期 2 个针对性主机测试、编译通过。未访问设备，实际导航区域观感仍需部署确认。此前全部功能累计保留。

## M125 交接记录

最新包：[AloeSend-2000125-M125-empty-clipboard-unsigned.hap](artifacts/AloeSend-2000125-M125-empty-clipboard-unsigned.hap)，版本 2.0.125 / 2000125，产品源码 `a4beff75`，分支 `arkui`。包含此前累计实现。

SHA-256：`851EF5D7C8814B40CE8C4C410C052D82E39DA8CB71F7ABC92C5BC4380C0F9FBE`。

M125：空剪贴板普通提示、读取期间被清空的竞态处理、非文字与权限反馈；真实读取错误仍报错，待发送选择保留。59 个主机测试及构建通过，未访问设备。

## M124 交接记录

最新包：[AloeSend-2000124-M124-flutter-settings-unsigned.hap](artifacts/AloeSend-2000124-M124-flutter-settings-unsigned.hap)，版本 2.0.124 / 2000124，产品源码提交 `a44f22fe`，分支 `arkui`。包含此前累计实现。

SHA-256：`6F744603CFFE47DCD201E10F305AADBB4C8F3C70DBCBEA05C0F9AA5039AEC226`。

M124：Flutter 设置独立迁移，支持已完成历史迁移的旧原生安装；已有原生值优先，设置 → 帮助与支持 → 从 Flutter 导入设置提供明确覆盖入口。映射范围、无对应项和目录权限说明见 M124 里程碑。59 个主机测试、构建通过；未访问设备，真实覆盖安装及系统目录权限仍待验收。

## M123 交接记录

最新包：[AloeSend-2000123-M123-immersive-cancel-unsigned.hap](artifacts/AloeSend-2000123-M123-immersive-cancel-unsigned.hap)，版本 2.0.123 / 2000123，产品源码提交 `5b65a6bf`，分支 `arkui`。包含 M1–M123 累计实现。

SHA-256：`D8379DB0230436ED57250C81791E2F4A2AFAE67A3228CEE666F0A6F2A5DC3C17`。

M123：全屏透明系统栏、明暗主题字体与系统区域避让；取消通知等待延长，v2 网络失败重试，致命接收错误响应等待取消通知完成；加密开关旁明确提示 Windows 托盘退出重开。58 个主机测试及最终构建通过。没有访问设备，状态栏观感及实际 Windows LocalSend 中断表现仍待用户确认，不能将主机通过等同于实机问题已消失。

## M122 交接记录

阶段验收与明确未完成项见 [验收记录](ACCEPTANCE.md)。M114–M120 已实现并主机验证同会话重试、逐文件失败处理、过期回退和取消。完整多语言、上游校验和设置和双端指纹核验页仍未完成。main 的 WebRTC 默认关闭、配对仍是 TODO，不再将其误列为已启用功能的缺项。不能将当前版本描述为全面对齐完成。

最新包：[AloeSend-2000122-M122-transfer-error-locales-unsigned.hap](artifacts/AloeSend-2000122-M122-transfer-error-locales-unsigned.hap)。版本 2.0.122，包含 M1–M122 累计实现，无需逐个安装。源码提交 `7db7138f9fbccb20eaff93aaae989e91b30e952a`，分支 `arkui`。

SHA-256：`EB403B97ABBDD865A1A3918336C06FACBC802B5174341C81A1F36D0FA613B072`。

M122：传输错误英文及数字 HTTP 状态模板，上传期间禁止语言切换刷新。最终 57 个主机测试、构建及 122 个包校验通过。未访问设备。

M121：浏览器 53 语言选项、RTL、104 个公共映射及安全文本嵌入。57 个测试、构建和 121 个包校验通过；3 GiB 慢写盘复测峰值 65,750 字节、哈希一致、句柄归零，55.4 秒。未访问设备。

M120：本次尝试字节数用于重试速度，保留历史时间；v1/v2 × HTTP/HTTPS 四组合双端恢复及取消通过。56 个测试、构建及 120 个包校验通过。未访问设备。

M119：英文模式补用 Flutter 映射，98 个标签逐项对照所有非简体中文语言。56 个测试、构建及 119 个包校验通过。专用文案多语言仍未完全覆盖，未访问设备。

M118：停止服务释放闲置发送凭据；8 MiB 原会话重试中接收端取消，双端 HTTP/HTTPS 终止、无回退确认且句柄归零。56 个主机测试、构建及 118 个包校验通过。未访问设备。

M117：文件级源读取/上传断连错误保留重试，清理集合互斥；明确取消、身份改变、失效会话仍终止。56 个主机测试、额外双端源文件恢复与清理竞态测试、构建及 117 个包校验通过。未访问设备。

M116：旧 token 403/404 后自动重新请求确认，仅补传未成功文件；不向过期会话发送取消。56 个主机测试、构建及 116 个包校验通过。未访问设备。

M115：发送端同会话重试，成功文件不重发，接收确认仅一次。55 个既有测试通过，新增第 56 个双原生 HTTP/HTTPS 重试测试通过。最终构建及 115 个包校验通过。未访问设备。

M114：接收端可恢复文件错误清理后返回 500 并保留 token；同 token 重试、后续文件、取消及重启失效通过真实 TLS 测试。55 个主机测试及最终构建通过，114 个包校验通过。未访问设备。

M113：接收端返回单文件 HTTP 500 后继续后续文件，最终批次保留错误，逐文件历史正确。55 个主机测试、构建和 113 个包校验通过。同会话重试仍未完成，未访问设备。

M112：旧配置缺失字段补默认值，保留明确关闭项、身份和旧主题颜色。55 个主机测试、最终编译和 112 个包校验通过。未访问设备。

M111：启动读取旧网络配置时仅恢复无效字段，保留有效设置与身份。55 个主机测试、构建及 111 个包校验通过。M110 另完成 3 GiB HTTPS 慢写盘复测，峰值 65,750 字节、SHA-256 一致、句柄归零。未访问设备。

M110：组播地址严格语法及范围校验、端口/超时整数校验，纠正有效输入清除旧错误。地址测试、最终编译与 110 个包校验通过，未访问设备。

M109：保存返回明确结果，名称/PIN/网络/加密设置只在成功后提示已保存。53 个主机测试、编译及 109 个包校验通过。未访问设备，输入保留便于失败后重试。

M108：保存与恢复设置串行执行，每轮保存取一致的当前快照，失败后队列继续，恢复执行前重查活动。累计 53 个主机测试、额外活动重查测试及编译通过，108 个包校验通过。未访问设备。

M107：全部取消接收选择后显示空选择提示，目录确认接入 Flutter 翻译，静态映射 98 项。语言测试及编译通过，107 个包校验通过。未访问设备，视觉验收仍待完成。

M106：目录弹层键盘避让与搜索/目录切换回顶，编译和 106 个包校验通过。未访问设备，实际键盘交互待验收。

M105：下载目录选择器先搜索后分页，切换目录清空查询，空/越界初始路径回到根目录。目录选择、语言回归及编译通过，105 个包校验通过。未访问设备，搜索交互待实机验收。

M104：设置入口标题、说明上下排列，避免长状态挤压标题，读屏共用当前状态。布局编译通过，104 个包校验通过。未访问设备，字体缩放和实际视觉仍待验收。

M103：停止期间拒绝新 TLS 会话，回归及构建通过，103 个包校验通过。M102 另完成 3 GiB 持续慢写盘测试，SHA-256 一致、峰值 65,750 字节、句柄归零，56.3 秒。未访问设备。

M102：底层 TLS 服务并行收尾，六个不主动关闭客户端的直接关闭从 6.1 秒降至 1.1 秒，会话释放后立即重启成功。关闭边界、提前响应、取消回归与编译通过，102 个包校验通过。未访问设备。

M101：定位 M100 的提前拒绝 HTTPS 重置，旧实现独立测试复现；关闭通知后有时限地排空在途密文，20 次 4 MiB 提前拒绝均收到完整 403。累计 51 个主机测试、编译及 101 个包校验通过。未访问设备，实机仍待验收。

M100：改名弹层绑定接收会话，服务拒绝过期会话操作，原请求结束关闭弹层。服务复跑与编译通过，100 个包校验通过。首次服务测试在新增用例之前出现 HTTPS ECONNRESET，日志 test-rename-session-first.log；复跑未复现，错误响应/关闭顺序仍待定位。未访问设备。

M99：自定义端口和组播地址增加 Flutter 发现影响说明，提供这两个表单字段的默认值恢复；动态模板累计 8 项。53 语言对照、同步与编译通过，99 个包校验通过。未访问设备。

M98：打开中的会话按稳定身份更新发现地址，发送前再次解析；草稿键保持不变。换址、离线上线、IP 复用与发现缺席测试及编译通过，98 个包校验通过。未访问设备。

M97：消息草稿清理绑定本次返回的任务 ID，未启动时不会误认同附件旧成功任务。消息状态与选择清理回归、编译通过，97 个包校验通过。未访问设备，相关界面交互仍待验收。

M96：编辑/打开回调查询当前选择项，避免行复用捕获旧文字。修改前累计 50 个主机测试通过，本轮组件变更最终编译通过，96 个包校验通过。未访问设备，长文字重复编辑实机交互待验收。

M95：发送改名保留目录，纠正错误后按本次结果关闭，添加控制字符校验与键盘完成。新改名测试及成功选择清理回归、最终构建通过，95 个包校验通过。未访问设备。

M94：接收改名补回省略的原始扩展名，保留显式新扩展名；弹层显示原名，支持键盘完成。名称、服务集成和语言模板测试通过，最终编译及 94 个包校验通过。未访问设备，原生功能与视觉全面对齐仍在进行。

M93：接收确认分别显示提供数量、已选数量与大小，修正部分取消选择后的统计范围不一致；全选/反选按钮可换行。53 语言模板与大小计算测试、最终编译通过，93 个包校验通过。未访问设备，界面实际效果待检查。

M92：浏览器分享的等待请求与文件总数使用 Flutter 模板，增加管理页分组标题；动态模板由 2 项增至 4 项，53 语言数量对照、目录定位回归及编译通过。92 个包校验通过。未访问设备，翻译覆盖和实机验收仍未全部完成。

M91：图片详情接入可读副本回退、异步过期结果保护及解码失败图标；详情操作放入滚动区域。历史路径测试和最终编译通过，91 个包校验通过。未访问设备，图片显示和短屏交互仍待实机验收。

M90：诊断报告增加构建版本、系统 API、机型、采集时间及任务数量。49 个主机测试通过；当前源码重跑 3 GiB HTTPS 慢写盘测试成功，首次暂停一秒并追加 1,538 次 10 毫秒暂停，队列峰值 65,749 字节，SHA-256 一致、文件句柄归零，耗时 58.1 秒。仅主机验证，未访问设备，不能代替 Windows LocalSend 到鸿蒙实机复测。

M89：单台成功任务关闭时移除仍与原发送内容一致的选择；新内容/编辑、多台、失败均保留，每个结果只处理一次。49 个主机测试和构建通过，89 个包校验通过，未访问设备。

M88：六类操作加入 Flutter 静态翻译映射，总数 96 项，语言测试和构建通过；88 个包校验通过。下一项已确认差异是单台成功关闭后的发送清单清理（Flutter send_provider.closeSession），需保护新加入内容并保留多台模式清单。未访问设备。

M87：相册保存接入副本回退和源文件预检，部分失败仍持久化成功位置、保留剩余队列并报告数量。相册/历史路径测试与构建通过，87 个包校验通过。系统相册实际授权及失败占位项行为待实机验证，未访问设备。

M86：历史副本回退用于重新发送与系统分享，补齐仅副本记录的界面入口及路径更新刷新。48 个主机测试和最终构建通过，86 个包校验通过。相册保存回退仍待处理，未访问设备。

M85：历史打开和另存为支持可读副本回退，在保存选择器之前验证源文件。真实文件内容与句柄测试及编译通过；85 个包校验通过。未访问设备，其他历史文件动作仍在审查。

M84：共享管理页增加全量文件名搜索、初始 30 项和每次 50 项展开、收起及空状态。下载确认请求不分页。界面编译与 84 个包校验通过，未访问设备；实际长列表交互待检查。

M83：发送拒绝统一为 declined，接收确认结束后同步文件状态和结束时间。服务集成、消息状态、取消测试及构建通过，83 个未签名包已校验，未访问设备。

M82：任务列表只淘汰结束项，活动传输和等待确认不受 30 项上限挤压。活动状态与亮屏判断保持准确。47 个主机测试文件及构建通过，82 个未签名包校验通过，未访问设备。

M81：快捷跳转统一同步当前分页控制器，屏幕和系统返回共用逻辑，PIN 等待可返回取消。PIN 取消测试和构建通过；81 个包校验通过。HDS/普通底栏同步与键盘返回的实机效果待检查，未访问设备。

M80：原生设置、发送确认与浏览器上传均支持非数字及长 PIN；发送框加入错误反馈、隐藏/显示和键盘确认，取消清空。真实 HTTP PIN 流程、服务集成和浏览器脚本测试通过，最终构建与 80 个产物校验通过。未访问设备。

M79：接收端记录具体文件失败原因，其他未完成项显示任务停止，已完成文件保持成功和有效路径。真实 TLS 校验失败及双端取消回归、构建通过；79 个包已校验。未访问设备。

M78：发送文件区分实际失败与任务停止前尚未开始，错误显示在文件行并同步历史，支持复制。文件重试/错误、服务集成、消息状态测试和编译通过；78 个包校验通过。接收端错误归属尚待进一步对齐。

M77：活动文件新增逐项进度、字节数与百分比，整体进度和文件选择增加读屏标签。进度数值与语言测试、编译通过；77 个包已校验。界面动画和读屏实机效果待用户检查，本轮未访问设备。

M76：补齐单文件重试，后续批量操作排除已重试项，失败的新任务可以继续重试。新增真实 HTTP 四轮请求清单测试及服务集成回归通过，编译成功，76 个包校验通过。仍需接收方确认新的重试会话，未复用已终止会话的令牌。

M75：重试期间禁用旧入口并在服务端去重；新任务创建后旧任务只显示已重试，没有启动则可继续重试。服务集成及取消、消息状态、部分接收回归通过，编译成功；75 个未签名包已验证。原生重试仍创建新任务，Flutter 同会话单文件重试的差异保留在后续对齐范围中。

M74：对方部分接收时，上传开始前确定接受清单；进度分母和字节数排除跳过文件，完成/取消/失败不再显示剩余时间。真实 HTTP 部分接受与 204 预览确认测试通过，全部 44 个主机测试和构建通过；74 个累计未签名包已校验。

M73：动态提取器覆盖 53 个语言版本的 29 个模板；选择数量和浏览器链接说明已接入。42 个主机测试文件通过，ArkTS 参数字典调整后语言测试及编译复测通过。其余动态文案和原生新增说明的语言覆盖仍需继续，不能视为全部语言对齐。包清单已验证 73 个累计产物。

用户于 2026-09-07 上午离开设备并明确禁止访问。之后的工作仅使用源码、主机测试和命令行未签名构建；不得查询、连接或部署到设备。新的六小时工作窗口约到 15:30 CST，目标完成后可提前结束。

## 本次 HTTPS 问题

Windows LocalSend 重启后，零进度现象恢复。这是用户提供的实测结果，不能归因为某个未经真机验证的代码修改。

大文件“写入速度不足，接收缓冲区已满”已在主机复现：旧接收实现遇到一秒磁盘暂停，明文队列超过 32 MiB。M51 改为原生 TCP 按需读取，完成上一块解密和落盘后才读下一块。3 GiB 主机 TLS 传输经过磁盘暂停后成功，SHA-256 一致，接收队列峰值 65,750 字节，文件句柄归零。M52 进一步处理堵塞的发送、取消、关闭及监听端口复用。

- M52 全部 29 个主机测试文件通过；含 HTTP/HTTPS 双端取消及取消后立即重传。
- 新增 TCP 生命周期测试连续 12 轮验证无额度不读、单次最多 64 KiB、等待期间对方退出、阻塞发送释放和同端口重启。
- M53 文件夹专项及 ArkTS 构建通过；系统报告不支持文件夹选择时进入下载目录选择器，取消和其他错误不误触发兜底。
- M54–M55 增加双向消息状态与持久化、部分批次结果、失败原因、未完成文件操作保护。31 个主机测试文件及编译通过；重启测试明确重用已保存的偏好值。
- M56–M57 合并批次消息显示，搜索与分页保留整个批次，支持逐项操作及整批重新发送、删除。32 个主机测试文件及编译通过。
- M58 增加系统配色、AloeSend、OLED、Yaru 与自定义预设，检查对比度、配置更新、重启和升级颜色保留；33 个主机测试文件及编译通过。
- M59 接入 53 个原版语言变体、61 条公共文案及基础 RTL 方向，地区/脚本、生成资源和回退测试通过。全部 34 个主机测试文件及编译通过。
- M60 语言搜索覆盖原文、本地化/英文名称及代码；全部 35 个主机测试文件和编译通过。当前代码再测 3 GiB HTTPS 完整性通过，队列峰值 65,749 字节。
- M61 返回/入口箭头和弹层方向适配完成，地址、链接及路径使用 LTR；语言专项与编译通过，实际 RTL 视觉与菜单交互仍待设备验证。
- M62 补齐收藏 IP/端口编辑及页面同步，收藏和地址专项、编译通过；身份保留、非法输入、重复端点和实际存储重启均有测试。
- M63 自动名称随确认的设备信息更新，手动备注与导入标记保留；真实 HTTP 探测、身份/降级保护和旧存储验证通过。全部 37 个主机测试文件及编译通过。
- M64 补齐快捷选择入口，统一成功/取消结果并避免文件夹读取失败留下部分清单。全部 38 个主机测试文件及编译通过。
- M65 将公共翻译映射扩展至 90 条，53 个语言变体重新生成；语言专项与编译通过。
- M66 对齐接收重置和编号默认值，确认后锁定逐项选择；真实 HTTP 接收、批量命名专项与最终编译通过。批量按钮支持换行，视觉仍待检查。
- M67 编辑弹层增加滚动及键盘内容缩放，SDK API 13 起支持，最终编译通过。实际焦点、输入法和大字体仍待用户检查。
- M68 多设备目标按身份解析，实际发送与计数共用结果；改名/地址变化、重复、消失和 IP 复用专项及编译通过。
- M69 动态文案单次替换并保留名称原文；美元语法、嵌套槽位样式、重复槽位与缺失参数测试及编译通过。
- M70 以原生设备/卷与文件编号检测目录祖先循环，真实 junction 测试保留普通链接并跳过循环。全部 40 个主机测试及原生/ArkTS 编译通过。
- M71 增加读取数量和取消扫描；中途打开文件取消、句柄关闭、原清单保留、重试、附件及自定义目录测试通过。全部 41 个主机测试和编译通过。
- M72 明确空间不足、权限和只读错误；真实 HTTPS 中途写入失败后清理，并立即完整接收下一份文件。服务集成 28 组及编译通过。
- 72 个归档包的 SHA-256、内嵌版本、源码提交、ArkTS 和原生库校验通过。
- 以上均不代表本轮已完成鸿蒙设备的大文件、内存或后台验证。

## 用户方便时优先检查

1. 用 Windows LocalSend 发送几个 GiB 文件，HTTPS 下不再因缓冲区满中断；确认大小和内容完整。磁盘繁忙时允许发送速度降低。
2. 双端分别取消、发送端退出、中断后立即再发，确认双方及时结束且不会残留“正在处理请求”。
3. 已存在的下载目录再次授权不报 File Exists；同名文件、子目录及保存失败时检查详情中的实际路径。
4. 原 Logo 无方形底；浮动 HDS 底栏、浅深色、大字体、窄屏、进度条、开关、下拉值和自动消失提示。
5. 覆盖 Flutter 安装后收藏、历史、消息导入；此项需要一致的安装签名。原 Flutter 存储不会由导入器修改。
6. 不支持系统文件夹选择的设备使用 Download/com.aloereed.aloesend 内的自定义选择器；系统分享、照片保存、文件打开、后台传输等继续由用户复测。

## 继续补齐的源码范围

总目标仍在进行，不能将核心收发修复等同于全部 Flutter 功能已经打平。

- 文件夹审计见 [FOLDER_PARITY.md](FOLDER_PARITY.md)：隐藏文件和 `.sendignore` 按 Flutter 实际行为传输，新增回归通过。M70 已补齐系统文件夹的祖先循环检测，使用原生设备与文件编号。仍需用户验证系统文档 URI 的目录描述符支持。

- 消息显示：M54–M57 已补齐双向状态、批次展示和操作，仍需用户检查窄屏、较大字体与弹层手势的实际效果。
- 语言：M59 已接入 53 个语言变体，M65 已扩展至 90 条公共文案，M60 已改善长列表选择。原生新增说明仍有英文回退，需要继续扩大覆盖。M69 审计确认动态模板及复数方法尚未由静态 getter 提取器覆盖，后续需保留参数与复数分支。M61 已补齐 RTL 图标/弹层方向，实际视觉与系统交互仍待检查。新增消息文案以实际 Dart 生成文件为准，不能仅按 assets/i18n JSON 判断运行时内容。M58 已补齐主题配色预设。
- 继续检查接收选项、历史操作与系统文件交互的功能差异，并打磨自适应布局和无障碍。M62–M63 已补齐已收藏设备的 IP/端口编辑、自动名称及备注更新策略。
- HDS API 23 系统材质已接入；不要沿用此前“只能模糊、必须 API 26”的过时结论。实际视觉效果仍需设备检查。

详细里程碑、范围和材质依据见 [PACKAGES.md](PACKAGES.md)、[MIGRATION.md](MIGRATION.md)、[DESIGN.md](DESIGN.md)。














