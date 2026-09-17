# M152 首次发现快速端口检查

发布配置后续更新：按用户要求改用 `C:/Users/huzheng/Downloads/aloesend5Release.p7b`，版本不变，最新发布文件为 `AloeSend-2000152-release-20260912-221935-signed.app` / `.hap`。构建、签名和内嵌 profile 一致性验证通过。APP SHA256 `5C60C41706FB3AA9FD34E0BAA0CCD97C99D4F9751A1A0AA624D0E4A31D985F5B`，p7b SHA256 `7502EEDEA862198EACD540DC1ED86DF55FDA8AEADAED2E2231CAE463C1921728`。未安装重打包。

版本 2.0.152 / 2000152。用户要求进一步缩短首次发现；151 真机首次约 38 秒、已有地址记录后约 3 秒。

自动扫描未知地址先做最多 350 ms 的 TCP 连接检查，不发送应用层数据；端口开放后再进行原有 HTTPS/HTTP 注册、客户端证书和身份校验。未通过短检查的地址保存到正常超时补查队列，在快速阶段覆盖完成后重新完整探测，避免慢设备永久被过滤。已知地址、收藏地址、手动刷新绕过短检查。

保留自动 2 并发、100 ms 间隔、每批最多 16 地址/6 秒、批间冷却、网卡公平性、忙时取消。预检查和正式注册共用扫描工作槽；取消、网络变化后不回填旧队列。开放端点会多一次无载荷 TCP 连接；交换身份仍由完整注册完成。

连接诊断新增“清除发现缓存并重新发现”，停止发现/接收服务后仅清除地址缓存及在线列表，再启动自动发现；保留收藏、文件、历史和身份，忙时不执行。用于重复验证首次发现，不用卸载/清除应用数据。新增文案有简繁中文和英文。

九个测试文件通过：discovery-port、discovery-priority、discovery-automatic、discovery-scan、selection-discovery、discovery-hints、discovery-reciprocal、flutter-locales、discovery-stages。新增测试覆盖真实 TCP 端口无应用数据、拒绝/超时/取消、短检查漏答后的完整补查、缓存和手动绕过、取消清理；发现缓存重置测试覆盖忙时不执行、保存清除及收藏保留。

正式构建、APP/HAP 签名验证通过。包：`AloeSend-2000152-release-20260912-220712-signed.app` / `.hap`。APP SHA256：`9FEEDF786A7E4E3D829880C79E889DF573340C0A3A80D81935146C5615AAEDBE`。

此前 hdc 安装发布包被手机以 9568322“不信任应用来源”拒绝，本次已请用户按既有方式安装 152 后继续真机冷扫描计时；当前不声称已测得 152 真机首次发现时间。源码未提交。
