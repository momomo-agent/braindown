# 生长日志

## Round 1 — 基础功能（2026-02-14）
- 目标：能打开文件夹、渲染 markdown、切换主题
- 方法：SwiftUI + NSTextView + 自定义 MarkdownTextStorage
- 结果：核心功能完成，但排版粗糙
- 教训：直接调数字不行，需要先建立排版认知

## Round 2 — 排版初步打磨（2026-02-14 ~ 02-15）
- 目标：排版对标 Craft/Bear
- 方法：学了 TheType、Refactoring UI、格式塔，看了 Craft/Notion 截图
- 改动：
  - 正文颜色从纯黑改为深灰
  - H1/H2 改用 Georgia 衬线体
  - 代码块加上下 padding
  - 间距多次调整（太松→太紧→中间值）
- 结果：比 Round 1 好很多，但间距不够系统化，品味标准不够明确
- 教训：应该先定好 taste.md 再动手，而不是边改边定标准

## Round 3 — 框架重建（2026-02-15）
- 目标：用 WHY→HOW→TASTE→AUTO→QA→DO 框架重新审视项目
- 建立了 .ai/ 目录：vision.md, methodology.md, taste.md, features.json, dbb/scenarios.md
- 下一步：按 features.json 中 passes=false 的项逐个修复，每改一项跑一次 DBB
