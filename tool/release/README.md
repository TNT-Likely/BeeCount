# Android 本地与生产版本号

统一入口为 `android_version_code.py`，只计算/验证版本，不构建、签名、联网、打 tag 或修改工作区。

版本名与安装码分开管理，按**全部渠道和本地已交付记录的最大 code** 分配：

| 场景 | 最高已发 code | 新 code |
| --- | ---: | ---: |
| `4.0.0-beta.1`（本次） | 225 | 226 |
| `4.0.0-beta.2` | 226 | 227 |
| 最后一个可用 `4.0.0` Beta | 298 | 299 |
| `4.0.0` 正式 | 299 | 300 |
| 正式后下一次发包 | 300 | 301 |

`4.0.0-beta.N` 使用 `floor+1`，仅允许 226–299；floor 已到 299 时拒绝继续发本轮 Beta。`4.0.0` 正式及后续版本使用 `max(300, floor+1)`，以后正常逐次累加。Beta 序号不机械决定安装码；从版本名本身无法推算 code。所有 code 均不得超过 2,100,000,000，拒绝旧产品名、本地已交付版本名回退、复用/退码和溢出，不静默切换版本计划。

2026-10-26 实际核验的公开 [3.9.0 APK](https://github.com/TNT-Likely/BeeCount/releases/download/3.9.0/beecount-3.9.0.apk) 为 `3.9.0+225`。这是已知迁移下界，不代表所有渠道永远只有225。

```sh
# 示例：仅当当前全部已交付包的最高实际码仍为225时使用该floor。
python3 tool/release/android_version_code.py 4.0.0-beta.1 --minimum-code 225 --json
python3 -m unittest discover -s tool/release -p 'test_android_version_code.py' -v
```

本地实际打包必须从线上APK/渠道及本地交付registry取得最高已发code，传入`--minimum-code`；每次真正交付后记录版本/码号/源SHA/APK hash，下次不得复用。不能把重新算出的码号当作线上事实。

Android Release workflow 也调用同一工具，替代原 `github.run_number`。**首次启用前必须**在仓库变量 `ANDROID_VERSION_CODE_FLOOR` 设置当前所有正式版/Beta最高实际码号，或手动运行时提供 `android_version_code_floor`；缺少时构建明确失败。实际本地 Beta 交付后、正式 CI 发布前更新该floor，避免私有Beta与CI计数脱节。未在本次变更中设置远端变量或触发workflow；iOS构建号公式不在本次修改范围。

本轮所有 Beta 的 code 均小于300，首个正式版从300起，高于本轮全部 Beta。若已交付更高产品版本，不能用较低版本名继续发包；应调整版本计划。

## 本地 APK wrapper

`local_apk.py` 只处理本地候选。默认 `prepare` 做签名预检与冻结源码准备；只有额外给 `--execute` 才调用 Flutter。工具不会联网查版本、推送、打 tag、触发 CI、安装 App 或自动把候选记为已交付，也不代替功能、性能和真实数据升级验收。

准备时必须明确：目标提交的完整40位 SHA、所有已发渠道最高实际 versionCode、独立核实的线上证书 SHA256、Java17、Flutter与Android SDK路径。源仓须为 `TNT-Likely/BeeCount`。工作区未提交改动不会进入 `git archive` 冻结副本；不能用 `HEAD`、分支名或工作区文件混入候选。

### 签名输入

签名只接受权限 `0600`、当前用户拥有的普通 JSON 文件，或以下四个环境变量。不要在 shell 历史、命令行参数、提交或聊天中填写口令。

| 私有JSON字段 | 环境变量 |
| --- | --- |
| `storeFile` | `BEECOUNT_APK_STORE_FILE` |
| `storePassword` | `BEECOUNT_APK_STORE_PASSWORD` |
| `keyAlias` | `BEECOUNT_APK_KEY_ALIAS` |
| `keyPassword` | `BEECOUNT_APK_KEY_PASSWORD` |

JSON必须恰好包含这四个非空字符串。keystore同样要求当前用户私有普通文件，拒绝符号链接、`debug.keystore`、`ci-debug.keystore`及`androiddebugkey`。

`KeyStoreProbe.java` 从临时私有 Java Properties 文件读取配置，真正解锁 `PrivateKeyEntry`，导出公开证书指纹，拒绝 debug/CI证书，再与外部提供的预期指纹严格比较。缺字段、错误store/key口令、alias不是私钥、证书不符均在任何Flutter调用前失败。不会通过Gradle的debug签名fallback试错。

路径、空白、反斜线、换行、冒号、等号、Unicode与非BMP字符按 `Properties.load(InputStream)` 规则转义。预检通过后将同一份四字段文件放入冻结副本的 `android/key.properties`；预检失败、仅prepare或真正构建退出时，均清理本run的Properties与keystore副本，不删除调用方材料。日志为私有文件，控制台不输出外部命令原始错误；误传未知口令参数时也不会回显其值。

### 已交付 registry

使用独立私有JSONL文件及相邻 `.head.json` 水位凭据。推荐 `.docs/v4-beta-apk/delivery-registry.jsonl`；它与早期方案草稿中的整份JSON不是同一种格式，不能直接混用。必须先检查有无历史交付，再显式初始化，工具不会因文件丢失而自动重置。

```sh
# 仅在核实还没有本地交付历史时执行一次；父目录需已存在。
python3 tool/release/local_apk.py init-registry \
  --registry .docs/v4-beta-apk/delivery-registry.jsonl
```

每次交付采用文件锁与 `O_APPEND` 追加，只记录公开产物身份和验收报告hash，不重写旧行。链式hash校验行的顺序及内容；独立水位凭据检测完整尾行被删的情况。文件或凭据缺失、截断、码号复用、链不一致均拒绝。写入中断造成水位不同也会拒绝，需人工依据交付证据恢复，不能重新初始化绕过。它防止工具或日常误操作覆盖历史，并非能抵抗同一用户恶意同时改写两份文件的WORM存储；应保留离线交付回执和线上floor证据。

实际floor为 `max(--minimum-code, registry最高已交付code)`，随后调用共用版本计算器。例如显式floor仍为225但本地已交付226，下一候选必须分配227，不能复用226。历史项独立校验合法版本名和正整数递增code；不按Beta序号反推历史code。`--minimum-code`仍然必填，不能用本地registry代替商店、GitHub及其他渠道核查。

### 默认准备及显式构建

以下示例中的环境变量只保存公开参数或私有文件路径；凭据文件内容由操作者提前私密准备。示例不会创建或读取用户的真实签名。

```sh
python3 tool/release/local_apk.py prepare \
  --repo "$PWD" \
  --source-sha "$BEECOUNT_FROZEN_COMMIT" \
  --version 4.0.0-beta.1 \
  --minimum-code "$BEECOUNT_VERIFIED_CHANNEL_FLOOR" \
  --registry .docs/v4-beta-apk/delivery-registry.jsonl \
  --expected-certificate "$BEECOUNT_VERIFIED_PUBLIC_CERT_SHA256" \
  --credentials-file "$BEECOUNT_PRIVATE_SIGNING_JSON_PATH" \
  --java-home "$JAVA_HOME" \
  --sdk-root "$ANDROID_SDK_ROOT" \
  --flutter "$BEECOUNT_FLUTTER_PATH"
```

仅准备成功不代表APK已构建。要实际构建，使用同一组确定参数并额外传 `--execute`；会创建新的私有run并重新预检。`--run-parent`可选，指定已存在的本地私有输出父目录。

wrapper 在冻结副本执行离线 `flutter pub get --offline --enforce-lockfile`，要求锁文件和已冻结生产源码不漂移，再用正常 `lib/main.dart`、`--release --flavor prod --no-pub` 构建。唯一允许的源码新增是Flutter正常生成的精确路径 `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`，单列为`generated-source-overlay.json`并记录SHA；不会放开其他`.java`新增，也不允许已提交文件变化。build后包括这份生成文件在内的生产源码必须逐字节相同。

显式注入 `CI_VERSION`、Git SHA、UTC构建时间、`GOOGLE_PLAY=false`与false QA/recording/gallery标志，不继承宿主tokens或`DART_DEFINES`；Flutter/Dart analytics显式抑制。默认仍按项目既定三ABI与universal输出；wrapper不叠加`--split-per-abi`，只根据 `prodRelease/output-metadata.json` 唯一arm64项选择候选。可加 `--arm64-only`，同时使用 Flutter 单 `android-arm64` target 和受控 Gradle `BEECOUNT_APK_ABI=arm64-v8a` 开关（只允许此值），限制 NDK ABI、禁用 universal 输出，并拒绝 metadata/目录中出现额外 APK。冻结提交必须包含此 Gradle 开关。所有 wrapper 构建显式要求正式签名，不能触发 Gradle 的开发 fallback。

默认依赖读取仍为 `--offline --enforce-lockfile`；CI 可显式加 `--allow-pub-network` 下载锁定依赖，但仍保持 `--enforce-lockfile` 和源码、锁文件逐字节校验。Gradle自身的缓存/依赖解析仍遵守项目配置；工具没有把“本地构建”冒称为完整网络沙箱。

开发gallery仅在已审查的两个`kDebugMode`入口使用。发布专用副本剔除 `assets/v4_gallery/` 声明/文件，移除gallery样例导入图并保留不可用stub；不改工作区。新增生产素材依赖或未知gallery入口会拒绝。`release-overlay.json`记录每个文件修改前后SHA、删除清单、pubspec精确diff和stub完整替换内容；构建清单明确包含overlay，不能宣称产物与原提交所有字节相同。

### 实际 APK 门禁与交付

全部通过才复制到run的`delivery/`，该目录只有一份arm64 APK，校验报告位于外层：

- `aapt`解析实际包名、versionName/code、minSdk23、targetSdk36、正常MainActivity；实际Manifest不得含debuggable/testOnly/instrumentation或QA身份。
- ZIP中必须只有arm64 native ABI，`libapp.so`及`libflutter.so`为实际arm64 ELF；不得带`kernel_blob.bin`/Dart JIT payload。文件名、`release`标签或metadata都不能替代这些检查。
- `apksigner verify`必须成功，恰好一个signer且指纹严格匹配独立预期值；`zipalign -c -P 16 -v 4`只读验证16KB对齐。
- 验包排除gallery、fixture标记、QA材料、数据库、备份/签名材料等污染；检查ZIP CRC与路径。不得靠签名后修改ZIP剔除内容。
- 构建日志出现既有Gradle签名fallback标记会拒绝；构建前后锁文件及已冻结生产源码必须一致。目录中的APK复制后重算SHA，且交付前再次核registry最高码号。

`manifest.json`的`artifact-verified-awaiting-functional-qa`仅说明上述产物检查通过，功能验收仍是“未执行”。关于页的版本显示、真实数据原位升级、性能及回退等需要正常App/隔离验收，不能从静态检查推断通过。

人工验收完成且确实向用户交付后，再用实际非空验收报告追加registry。工具记录报告hash及操作者确认，不会把任意报告文件内容自动判为功能通过。

```sh
python3 tool/release/local_apk.py record-delivery \
  --manifest "$BEECOUNT_APK_RUN/manifest.json" \
  --acceptance-report "$BEECOUNT_ACTUAL_ACCEPTANCE_REPORT" \
  --minimum-code "$BEECOUNT_RECHECKED_CHANNEL_FLOOR" \
  --confirm-delivered
```

这一步会重新校验同一APK、再次要求当前全部渠道floor，拒绝被替换的产物和已被超越的码号。签名文件、口令、用户数据不进入registry或交付目录；只向用户交一份APK。生产CI前仍需把新最高码号同步到正式发布的floor。

### 工具测试

```sh
python3 -m unittest discover -s tool/release -p 'test_*.py' -v
```

额外设置本机`JAVA_HOME`可运行真实Java Properties Unicode往返检查。设置`ANDROID_SDK_ROOT`及`BEECOUNT_FLUTTER_FOR_PREFLIGHT_TEST`可运行“无任何真实密钥的损坏keystore”真实Java拒绝测试，确认临时文件清理，绝不执行Flutter。设置`BEECOUNT_PUBLIC_APK_FIXTURE`为已核SHA的公开3.9.0 APK可用实际aapt/apksigner/zipalign只读核验产物；没有提供时明确skip，不下载也不伪造成功APK。单元测试中的subprocess替身仅验证签名口令/证书错误分支，不能冒称真实签名构建已通过。

## Android / iOS 统一 Beta 发布

只使用 `.github/workflows/beta-release.yml` 的 **Beta Release** 手动入口，在 Actions 选择 `v4` 分支。默认新版本为 `4.0.0-beta.6`；发布前提交对应的 `docs/releases/<version>.md`，不能用默认值跳过版本核对。

`mode=release` 在同一私有 macOS Runner 冻结源码、版本和短说明，依次验证正式签名 ARM64 APK 与 App Store 签名 arm64 IPA。默认 `ios_delivery=testflight` 还要求上传成功、Apple processingState=VALID、内测说明更新成功；选择 `ipa` 时只归档已签名 IPA，不宣称 TestFlight 可用。

**两端全部成功后才创建 tag 和 draft prerelease；确认远端仅有一份 APK 和一份 IPA，且大小、摘要与回执一致后才公开 Release。** 任何构建、签名或 Apple 处理失败都不创建公开 Release、不上传失败候选到 Actions artifacts、不发送 TG。上传中断留下私有草稿及版本预留回执供核对，禁止覆盖 tag、资产或重复使用版本。已公开的历史 Beta 保持原内容。

从 Beta6 起，下载附件只有 APK、IPA。JSON 回执、版本预留、TestFlight 处理结果及通知意图／回执保存在 Release 正文的 `beecount-beta-metadata:v1` 隐藏记录中；本地 checksum 留在私有构建目录。旧 Beta 的 JSON 附件继续只读兼容，不迁移或删除。隐藏记录不是保密存储，只能包含公开构建身份，不得写入签名资料、凭据或用户数据。

### 版本与身份

- `source_ref` 只接受 `v4` 或其历史完整40位SHA，立即冻结；未提交文件不进入构建。
- `android_version_code_floor` 或仓库变量 `ANDROID_VERSION_CODE_FLOOR` 必须是全部渠道最高已交付 code。再取 Release/失败草稿机器回执的最大值；Beta5 已交付230，下一新包至少231。4.0.0 Beta只使用226..299，正式版从300起。
- `ANDROID_RELEASE_CERT_SHA256` 必须匹配已核生产证书。沿用四项 `ANDROID_KEYSTORE_*` / `ANDROID_KEY_*` secrets，以及 `APPLE_CERTIFICATE_*`、`APPLE_PROVISIONING_PROFILE*`、`APPLE_TEAM_ID`、`APPLE_API_*`。不打印或上传签名资料，Flutter/Pods子进程不继承凭据。
- Flutter3.27.3 / Xcode26.3 / CocoaPods1.16.2 / Ruby JSON2.7.2固定；依赖锁漂移拒绝。App与Widget的实际签名、权限、版本、架构均从IPA核验。
- iOS数字版本为4.0.0，默认build沿用Android code；上传前读取ASC最高build。显式更高 `ios_build_number` 仅用于Apple不能复用build的重试，不能替换已公开资产。正式流程历史run_number策略仍须在4.0.0前统一为300起严格递增。
- 与正式发布共用 `beecount-android-delivery` 串行锁，不取消运行中的发布；其他本地渠道交付仍须及时更新floor。GitHub机器回执不能替代全渠道核查。

App Store签名IPA不能直接侧载，安装走TestFlight。Apple处理成功、测试组、加密合规和外测审核是不同状态；可选 `TESTFLIGHT_PUBLIC_URL` 只能使用真实邀请地址。流程不上传Google Play、不提交正式App Store审核。

### 唯一通知与失败重试

只有完整双端Release可以通知。通知job重新读取并核对两端公开回执和资产身份；需要TestFlight时还要求真实处理完成回执。先在正文元数据保存不可覆盖的 `beta-notification-intent.json` 记录，发送一条TG，再追加包含真实message_id的 `beta-notification.json` 记录；这些记录不作为下载附件。成功回执存在时重跑直接跳过。

如果已留下通知意图却没有成功回执，自动重跑拒绝发送，避免网络超时造成重复消息。维护者先核对TG群，再显式选择 `mode=notify-only`、原版本和实际iOS build补发；已有成功回执时手动模式也不会重发。通知模式不构建、不分配code、不访问签名secrets、不改tag或二进制，只追加通知意图/回执。旧的按平台或部分成功通知入口已停用。

发布中断留下草稿时不能靠重跑整套流程覆盖，先核对是否已有任何对外交付，再处理版本预留。构建与签名失败时不会为了公告而创建Release。

### 每个 Beta 的说明

使用 `docs/releases/BETA_TEMPLATE.md`，每版独立文档。`## 更新摘要` 只列相对上一Beta的3–5项用户可见差异，不拼接全部commit。摘要缺失或无效时plan即拒绝。升级注意、待验收范围和反馈issue580另列。

Release禁用自动生成日志，`make_latest=false`，不替代正式Latest。TG沿用已发布正文的同一摘要，最多5项、每项80个Unicode码点，总长最多1400字符/15行，附双端状态、Release与反馈链接，不堆积历史提交。
