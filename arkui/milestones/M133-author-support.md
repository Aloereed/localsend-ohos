# M133 · 支持作者与 QQ 群反馈入口

版本 2.0.133 / 2000133。

ArkUI 设置中的支持入口、页面标题和按钮统一为“支持作者”，删除原 LocalSend 作者的 GitHub Sponsors、Ko-fi 按钮，改为打开 https://afdian.com/a/aloereed。说明改为支持 AloeSend 作者持续开发，保留所有文件分享功能免费使用的说明；应用界面不显示支持平台名称。

设置 → 帮助与支持新增“进群吐槽”，显示 QQ 群号 936959829。点击通过专用方法调用系统 viewData，使用 QQ 群资料页 URI 拉起 QQ。上下文不可用或拉起失败时提示手动搜索群号。普通 openUrl 仍仅接受 HTTP/HTTPS。同步补充英文文案。

验证：locale.test.cjs、flutter-locales.test.cjs 两个现有测试通过；临时主机断言验证作者链接、QQ群号及群资料类型、拉起失败提示和普通链接协议限制。2.0.133 鸿蒙调试编译通过，保留项目现有编译警告。未访问设备，QQ 实际拉起及外部支持页面跳转待真机验证。

调试归档：[M133 unsigned HAP](../artifacts/AloeSend-2000133-M133-author-support-unsigned.hap)。SHA-256：`F509E2BB3AE1D62674FE778949F809F80A19E23A604FB30D636F0C0AE25521A3`。

本次未生成正式签名 APP，未上传或推送远程。源码提交关联记录在产物 JSON 和 PACKAGES.md 中。
