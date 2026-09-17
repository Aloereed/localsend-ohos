# LocalSend 1.18 新增语言资源

`v1.18.2/be.json`、`ga.json`、`hy.json` 为 LocalSend 官方 v1.18.2 的原始翻译文件，2026-09-11 获取。附带同一版本的 Apache-2.0 LICENSE。

源文件位于 https://github.com/localsend/localsend/tree/v1.18.2/app/assets/i18n 。不修改上游 JSON；AloeSend 名称、旧版不存在的条目和动态模板通过 `../upstream-locales.cjs` 适配。

执行 `node arkui/sync-locales.cjs` 与 `node arkui/sync-templates.cjs` 重新生成 ArkUI 资源。`--check` 只校验生成结果。生成器不会联网，旧 53 种语言继续沿用本项目 Flutter 运行时资源，新增三种使用这些固定版本的源文件。

静态引用按官方 `@:` 语法解析。仅覆盖原生界面已有键；官方缺失的键继续采用现有英文回退。复数分支和命名参数按官方文本生成，未知参数、循环引用或缺少默认分支会中止生成。
