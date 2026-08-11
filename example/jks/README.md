# 测试签名（可提交仓库） / Test signing (OK to commit)

仅用于 `auto_moto_dash` **示例应用**本地 / CI 打包，**不可**用于正式发布。

For the `auto_moto_dash` **example app** local / CI builds only — **not** for production release.

| 项 / Item | 值 / Value |
|----|-----|
| 文件 / File | `auto_moto_dash_test.jks` |
| alias | `auto_moto_test` |
| storePassword / keyPassword | `automoto123` |
| 有效期 / Validity | 约 10000 天 / ~10000 days |

Gradle 配置 / Gradle config：`example/android/key.properties`
