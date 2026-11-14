# App 设计契约

完整设计源位于独立公开仓 [BeeCount-Design](https://github.com/TNT-Likely/BeeCount-Design)。`design.lock.json` 固定经审阅的设计 commit 与 App 小型契约 hash；App 构建与普通回归不需要相邻设计仓。

- `contracts/`：设计令牌、AI模板/执行档位、几何与组件映射等小型输入。它们是需要review的合同，不是第二份完整HTML设计源。
- `../../test/fixtures/design/`：App 自身回归所需合成图片。
- `../vendor/lucide/`：App 图标生成所需固定 vendor、许可证和原始 hash。

常规检查：

```sh
python3 tool/v4/verify_component_coverage.py
python3 tool/design/check_contracts.py
```

明确跨仓检查：

```sh
python3 tool/design/check_contracts.py --design-root ../BeeCount-Design
python3 tool/v4/verify_component_coverage.py --design-root ../BeeCount-Design/card-refresh
```

跨仓检查要求锁文件指向的设计 commit、源文件与契约一致；缺仓或版本不符应失败，不能输出完整通过。设计修改经确认后同时更新源与App契约，先推设计 commit 再更新App锁。设计仓 `app-source.lock.json` 记录构建输入的App基线与逐文件hash，锁文件自身不作为App输入，避免循环固定点。

几何输出默认写设计仓 `qa/contract-candidates`，不能静默覆写App测试fixture。确认变化后再把候选作为App PR中的明确合同改动。
