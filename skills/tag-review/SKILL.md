---
name: tag-review
description: >
  審查、補充、修正知識筆記的 tags，確保分類一致性。
  觸發：使用者提到 tag、標籤、分類、frontmatter tags 相關問題時使用。
allowed-tools: ["Read", "Glob", "Grep", "Bash"]
---

# Tag Review

審查知識筆記標籤，確保符合 Vault 標籤規範。

標籤規則與合法分類層級定義於 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/tag-topic-spec.md`，執行前必讀。

## 標籤格式摘要

- `tags[0]`：層級結構標籤（如 `技術/AI/LLM`）
- 接著展開各層為平坦標籤
- 再加 2-5 個描述標籤
- 總數 ≤ 10，英文用 PascalCase
- `category` = `tags[0]` 第一層

## 執行步驟

1. **收集既有標籤**：`obsidian tags vault=[vault_name] counts`（失敗則略過）
2. **分析筆記**：從標題、摘要、正文提取候選主題詞
3. **匹配建議**：優先用既有標籤，避免碎片化；新標籤需確認未來會重複出現
4. **輸出建議表格**：

| Tag | 類型 | 理由 | 新增/既有 |
|-----|------|------|----------|
| `技術/AI/LLM` | 層級結構 | 主題為 LLM | 既有 |

## 確認流程

輸出建議後等待使用者確認，確認後用 obsidian CLI 寫入。

CLI 安全規則見 `${CLAUDE_PLUGIN_ROOT}/references/cli-usage.md`。

寫入方法（使用 `eval + processFrontMatter`，同 wiki-writer Step 5B）：

```bash
obsidian eval vault=[vault_name] code="app.fileManager.processFrontMatter(app.vault.getAbstractFileByPath('[頁面路徑]'), fm => { fm.tags = ['技術/AI/LLM','技術','AI','LLM','RAG']; fm.category = '技術'; })"
```

寫入完成後用 Read 工具確認 frontmatter 已正確更新。
