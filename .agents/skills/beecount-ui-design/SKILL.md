---
name: beecount-ui-design
description: 为 BeeCount 新页面、布局重组、入口移动及重要交互变化先制作可操作的 HTML 设计稿。也支持独立出稿或修改已有稿。
---

# BeeCount HTML 设计

1. 从当前任务的目标 checkout 读取对应页面、路由和已有组件。App 参考 lib/styles/tokens.dart、lib/dev/component_gallery 和真实页面；Cloud / Website 使用其各自的主题与组件。记录实际基线 SHA 和变更范围。
2. 把主要入口、操作路径和关键状态做成独立 HTML，使用合成数据及现有 UI 术语。按改动需要呈现小屏、深色、加载、完成和错误状态。使用当前主题、间距、导航与同类组件。
3. 将 HTML 放在项目的忽略目录中，例如 .docs/design/<feature>.html。通过 T3 的 HTML 预览和渲染交付，或在其他客户端交付可打开的本地文件。附上对应实现验收点。
4. 只出设计或先确认时到此交付。已授权连续实施时，交稿后继续。已有确定设计时使用给定稿。实现和 QA 引用同一稿和基线。
