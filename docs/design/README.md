# 设计资源

完整页面、交互 HTML、组件规范与里程碑图已迁入独立公开仓 [BeeCount-Design](https://github.com/TNT-Likely/BeeCount-Design)。App 对应设计版本固定在 [design.lock.json](../../tool/design/design.lock.json)。

App 普通构建和回归仅依赖本仓 `tool/design/contracts`、测试 fixture 与图标 vendor。设计维护和跨仓校验见 [设计契约说明](../../tool/design/README.md)；组件职责见 [展示层架构](../architecture/presentation-packages.md)。

本机预览仍使用 `http://127.0.0.1:8374/`，静态根是相邻设计仓的 `card-refresh`，已有 `/prototype/demo.html`、`/components/ui-components.html` 与 `/boards/...` 地址保持。

临时进度、评审、执行计划与 QA 原始材料保存在忽略的 `.docs`；长期架构与已确认行为保留在 `docs/architecture` 和 `docs/decisions`。App 原历史提交中的设计树仍可追溯，不重写历史。
