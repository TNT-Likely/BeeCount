# UI 维护与回归工具

本目录保留持续维护所需的组件覆盖、图标生成、性能 fixture 和设计渲染工具。

| 工具 | 用途 |
| --- | --- |
| `verify_component_coverage.py` 与组件 inventory | 校验真实 Flutter 样例、基础组件及 HTML 设计契约的对应关系 |
| `generate_category_line_icons.cjs`、`sync_line_icon_assets.cjs` | 从固定图标源生成并校验生产 SVG 资源 |
| `generate_large_import_fixture.py` | 在独立目录生成合成导入数据，不读取或覆盖用户账本 |
| `build_original_skin_renderer.py`、`build_skin_integration_renderer.py` | 为独立设计仓生成可复现的 Flutter 皮肤预览 |

```sh
python3 tool/v4/verify_component_coverage.py
python3 -m unittest discover -s tool/v4 -p 'test_*.py'
```

一次性的页面迁移进度、历史快照比较和本机评审报告不作为长期发布依赖。
组件职责见 [展示层架构](../../docs/architecture/presentation-packages.md)，跨仓设计维护见 [设计契约](../design/README.md)。
