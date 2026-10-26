# Android 本地与生产版本号

统一入口为 `android_version_code.py`，只计算/验证版本，不构建、签名、联网、打 tag 或修改工作区。

`versionCode = major×1,000,000 + minor×10,000 + patch×100 + channel`。

| versionName | versionCode |
| --- | ---: |
| `4.0.0-beta.1` | 4,000,001 |
| `4.0.0-beta.98` | 4,000,098 |
| `4.0.0` | 4,000,099 |
| `4.0.1-beta.1` | 4,000,101 |

beta 序号仅 1–98，99 留给正式版；minor/patch 为0–99，总码号不超过项目保守上限2,100,000,000。超限、已有/更低码号、非法版本、旧产品版本均拒绝，不自动换版本或进位。App 更新提示另按 SemVer 排序；名字与 Android 安装排序的整数码是两个概念。

2026-10-26 实际核验的公开 [3.9.0 APK](https://github.com/TNT-Likely/BeeCount/releases/download/3.9.0/beecount-3.9.0.apk) 为 `3.9.0+225`。这是已知迁移下界，不代表所有渠道永远只有225。

```sh
# 示例：仅当当前全部已交付包的最高实际码仍为225时使用该floor。
python3 tool/release/android_version_code.py 4.0.0-beta.1 --minimum-code 225 --json
python3 -m unittest discover -s tool/release -p 'test_android_version_code.py' -v
```

本地实际打包必须从线上APK/渠道及本地交付registry取得最高已发code，传入`--minimum-code`；每次真正交付后记录版本/码号/源SHA/APK hash，下次不得复用。不能把重新算出的码号当作线上事实。

Android Release workflow 也调用同一工具，替代原 `github.run_number`。**首次启用前必须**在仓库变量 `ANDROID_VERSION_CODE_FLOOR` 设置当前所有正式版/Beta最高实际码号，或手动运行时提供 `android_version_code_floor`；缺少时构建明确失败。实际本地 Beta 交付后、正式 CI 发布前更新该floor，避免私有Beta与CI计数脱节。未在本次变更中设置远端变量或触发workflow；iOS构建号公式不在本次修改范围。

同版本正式槽99高于全部Beta槽1–98；若已经交付更高版本的Beta，较低版本的正式包仍会被floor拒绝。需要调整版本计划，不能绕过退码门禁。
