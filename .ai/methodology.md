# 方法论

## 架构：Block-Based 渲染

### 为什么换架构
NSAttributedString 流式渲染的天花板太低：
- 代码块无法有独立的圆角容器、语言标签、复制按钮、行号
- 表格受限于 NSTextTable，无法做表头背景、hover 高亮、精细边框
- 所有内容挤在一条富文本流里，块元素没有独立的视觉控制权

Notion 和 Craft 都是 block-based — 每个 markdown block 是独立的 View。

### 新架构

```
MarkdownParser → [MarkdownNode] → BlockRenderer → NSView 树
                                                    │
                                    NSScrollView > NSStackView
                                        ├── ParagraphBlockView (NSTextField/NSTextView)
                                        ├── HeadingBlockView
                                        ├── CodeBlockView (自定义 NSView)
                                        ├── TableBlockView (自定义 NSView)
                                        ├── BlockquoteBlockView
                                        ├── ListBlockView
                                        ├── ImageBlockView
                                        └── HorizontalRuleView
```

### 核心原则
1. **每个 block 是独立 NSView** — 有自己的背景、圆角、阴影、交互
2. **MarkdownParser 不变** — AST 解析层复用
3. **BlockRenderer 是新的中间层** — 把 MarkdownNode 映射成 NSView
4. **文本 block 内部仍用 NSAttributedString** — 段落、标题的 inline 样式（加粗、斜体、链接）还是富文本
5. **复杂 block 用自定义绘制** — 代码块、表格各自画自己的

### 迁移策略
1. 先搭 NSScrollView + NSStackView 容器
2. 把现有的段落/标题渲染迁移到 ParagraphBlockView/HeadingBlockView（最小改动）
3. 重写 CodeBlockView（重点）
4. 重写 TableBlockView（重点）
5. 迁移其余 block 类型
6. 删除 MarkdownTextStorage 和 BlockBackgroundLayoutManager

## 排版方法论

### 认知基础：格式塔原则
1. **接近性** — 间距决定归属。标题贴近它的内容，远离上一段。组内紧、组间松。
2. **相似性** — 同级元素必须视觉一致。所有 H2 一样，所有代码块一样。
3. **图底关系** — 代码块/引用块用背景色做图底分离，但不能抢正文注意力。
4. **连续性** — 阅读是一条连续路径，间距突变会打断节奏。间距必须系统化。

### 排版原则：TheType 孔雀计划
- 中文排版从字格出发，行长 = 字号整数倍
- 字距:行距:段距 = 1:1.5:2 的节奏感
- 标点悬挂、避头尾

### 视觉层次：Refactoring UI
- 层次靠弱化次要信息，而非放大主要信息
- 先给太多留白再减少
- 间距系统化：只用预定义比例尺（4/8/12/16/24/32）
- 字重 + 颜色深浅 > 字号差异

### 标杆分析法
改任何视觉元素前，先截图对比 Craft/Bear/Notion 的同类元素，找到差距再动手。

## 开发方法论

### MVP 原则
每轮只做最小可用改进。先自行车再汽车。

### 自验证
改完代码 → build → 运行 → 视觉检查 → 对照 taste.md 验收 → 再发给用户。

### 增量推进
架构迁移分步走，每步都能 build 和运行。不做大爆炸重写。
