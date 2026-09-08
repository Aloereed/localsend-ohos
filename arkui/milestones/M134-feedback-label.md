# M134 · 隐藏反馈入口群号

版本 2.0.134 / 2000134，包含 M133 支持 AloeSend 作者及 QQ 群反馈功能。

按用户要求，设置 → 帮助与支持的入口只显示“进群吐槽”，移除下方群号及对应英文文案。点击仍拉起 QQ 群 936959829；拉起失败时保留手动搜索群号的提示。

验证：locale.test.cjs 和 flutter-locales.test.cjs 通过。调试 HAP 和正式签名 APP 构建、归档信息见 HANDOFF.md。未访问设备，QQ 拉起及外部支持页面跳转仍待真机验证。

调试归档：[M134 unsigned HAP](../artifacts/AloeSend-2000134-M134-feedback-label-unsigned.hap)。源码与包的关联及 SHA-256 记录于 PACKAGES.md 和产物 JSON；正式包沿用 Flutter 发布身份。
