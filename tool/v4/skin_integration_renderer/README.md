# 原版皮肤元素的透明合成评审器

入口：[皮肤与内容共景](../../../../BeeCount-Design/card-refresh/boards/skins-content-integration-review.md)。此目录只为 HTML 评审服务，不构建 APK，也不修改 App。

`build_skin_integration_renderer.py` 从固定官方 3.9.0 提取并校验四个原 part，使用新的 `header_skins.dart.in` 组合原私有绘制方法。新增模板只调整位置、等比尺寸、承载与淡出；不修改原 part，不重画原形状，不覆盖旧渲染器。

```sh
python3 tool/v4/build_skin_integration_renderer.py --check-only
python3 tool/v4/build_skin_integration_renderer.py
```

输出与独立临时工程都在被 Git 忽略的 `build/` 下。页面使用同源消息切换浅深色、承载、页面和动画状态。原生几何与 CanvasKit 输出的差异、确认范围及验证记录见评审说明。

设计仓默认与 App 相邻；其他位置设置 `BEECOUNT_DESIGN_ROOT` 为其 `card-refresh` 绝对路径。仅构建评审 renderer 时需要设计仓，App 与 `--check-only` 无此依赖。
