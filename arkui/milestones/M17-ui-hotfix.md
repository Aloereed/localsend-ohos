# M17 · 三项实机问题修复

用户在 M15 实机反馈：前台收到分享也不显示接收界面；图标缩在左上角；下拉栏首次打开不显示选中值。

## 接收入口

在已安装 M15 的设备上只读检查并启动前台复现：53317 监听存在，但 HTTP/HTTPS 请求不能正常返回。设备日志出现 `CallOnConnectCallback fun === null`。

根因是按 Node 的习惯在 `listen()` 前注册服务端 `connect` 回调。HarmonyOS TCP/TLS 服务端要求成功监听后才订阅，原写法导致底层收到数据却没有交给应用，接收页面无法触发。

已调整 LocalSend 与浏览器分享的 TCP/TLS 服务端顺序；主机适配器也严格执行此 API 前置条件，避免原有宽松模拟再次掩盖问题。

依据：[OpenHarmony Socket 官方接口文档](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-network-kit/js-apis-socket.md)，TCPSocketServer / TLSSocketServer 的 on('connect')。

## 图标

Path 绘制命令使用 px，原代码把 24 单位路径放在 24 vp 区域后按尺寸缩放，高密度设备上图案仍小且偏左上。改为 Shape 的显式 `24px × 24px` viewport，映射到组件 vp 尺寸；线宽也使用 px 随视口统一缩放。

## 下拉初始值

所有六处 Select 同时绑定 `.selected()` 和 `.value()`：语言、浅深模式、设备类型、发送方式、网络筛选、批量命名。前者控制选项索引，后者控制按钮上初始显示的文字。

验证：18 组 LocalSend 集成、7 组浏览器服务集成通过；原生 debug 编译成功。设备上的旧版本用于复现与诊断；本次新包保持未签名，由用户部署回归。

产物：`artifacts/AloeSend-2000017-M17-ui-hotfix-unsigned.hap`。
