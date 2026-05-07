# Aliases and Wikilink Format

> **status**: v0.9.0 — 2026-04-27 對齊實踐（從「英文 slug 鐵律」改為「禁用解析地雷」）
> **scope**: taxonomy — 分類層
> **authority**: 本檔為 aliases 欄位與 Wikilink 格式規範的權威定義
> **history**:
> - v0.9.0-alpha（初版）：沿用 Karpathy LLM Wiki 教程的英文小寫 slug 鐵律
> - v0.9.0（2026-04-27）：經 curator 健康檢查發現實作早已偏離（73 頁全部用中文/大寫專有名詞），規格與實踐對齊，改為「允許中文 + 大寫英文 + 有意義空格，僅禁止解析地雷字元」

## Summary

知識筆記必須支援**中英雙語別名**（`aliases` 欄位），讓「Attention Mechanism」與「注意力機制」指向同一頁。檔名與 wikilink 目標**遵循領域慣例**：中文主題用中文（`圖像編輯模型`）、英文專有名詞保留原大小寫（`Claude Code`、`Stable Diffusion`、`SDXL`）、中英混合也允許（`GGUF 格式`、`MCP（Model Context Protocol）`）。**禁止三類解析地雷**：底線（`value_investing`）、駝峰式（`valueInvesting`）、無意義單獨空格作為分隔（如把 `RAG模型` 寫成 `RAG 模型` 純為 SEO）。本機制的目的是讓知識庫能跨語言累積，且讀起來符合自然慣例。

## Core Concepts

1. **aliases**：concept / entity 頁的 frontmatter 陣列欄位，列出該主題的所有別名（含中英雙語、縮寫、替代名稱）
2. **Wikilink 命名原則**：跟隨領域慣例，禁用解析地雷
3. **正文標題格式**：`「中文主名稱（English Name）」`（仍保留，幫助跨語言檢索）
4. **alias 匹配**：wiki-writer 在建立新 concept 前必須檢查既有 aliases 防重複建立
5. **alias 不可隨意改**：alias 列表是審計資料，**只增不減**（除非確認誤建立）

## Specification

### 1. aliases frontmatter 欄位

每個概念類筆記（`主題知識/{概念|實體|比較|總覽}/*.md`）的 frontmatter 必須有 `aliases` 陣列：

```yaml
---
title: "RAG"
aliases:
  - "Retrieval-Augmented Generation"
  - "檢索增強生成"
  - "檢索增強"
  - "RAG 模型"
---
```

| 欄位特性 | 說明 |
|---------|------|
| 類型 | array of strings |
| 必填 | ✅（v0.9.0-alpha 起，舊筆記允許空陣列）|
| 內容 | 該主題的所有可能稱呼，含中英雙語 + 縮寫 + 替代名稱 |
| 排序 | 按使用頻率（最常用的別名放前面）|
| 大小寫 | 保留原樣（"GPT" 不寫成 "gpt"）|

### 2. Wikilink 命名原則

<!-- decision-id: aliases-wikilink-format-rule -->
<!-- updated: 2026-04-27 — 從英文 slug 鐵律改為「跟隨領域慣例 + 禁用解析地雷」 -->

**核心原則**：wikilink 目標跟隨**領域慣例**命名，僅禁止確實會引發解析或可讀性問題的字元。

✅ 合法：
```
[[RAG]]                          # 縮寫保留大寫
[[Claude Code]]                  # 英文專有名詞含空格
[[Stable Diffusion]]             # 英文產品名
[[ComfyUI]]                      # 英文產品名（PascalCase 是該產品官方寫法）
[[圖像編輯模型]]                  # 純中文主題
[[GGUF 格式]]                    # 中英混合
[[MCP（Model Context Protocol）]] # 中文（英文補述）格式
[[模型量化|Quantization]]         # alias 顯示英文，目標中文
```

❌ 違規（會引發解析問題或可讀性問題）：
```
[[value_investing]]      # 底線：與駝峰一樣造成 grep 困難
[[valueInvesting]]       # 駝峰：tokenize 不穩定，case-sensitive 易誤
[[ConcatRAG架構]]         # 連續英文+中文無分隔：可讀性差
```

⚠ 灰色地帶（不視為違規，但建議盡量避免）：
- 名稱含全形標點（`、`、`：`）— Obsidian 處理沒問題，但跨平台可能有編碼風險
- 名稱含 emoji — 同上

**檔名與 wikilink 目標一致**：因 Obsidian 用「最短路徑解析」，檔名 = wikilink leaf。範例：`主題知識/實體/Claude Code/Claude Code.md` 對應 `[[主題知識/實體/Claude Code/Claude Code]]` 或最短形式 `[[Claude Code]]`。

### 3. 命名選擇指引

<!-- decision-id: aliases-slug-naming-rule -->
<!-- updated: 2026-04-27 — 從「英文 slug 強制」改為「依主題本質選擇」 -->

| 主題本質 | 推薦命名 | 範例 |
|---------|---------|------|
| 純英文專有名詞 | 保留官方寫法 | `Claude Code`、`ComfyUI`、`SDXL` |
| 純中文概念 | 用中文 | `個人知識管理`、`圖像編輯模型`、`上下文管理` |
| 中英混合（中為主）| 中（英）格式 | `MCP（Model Context Protocol）` |
| 中英混合（英為主）| 英 中格式或保留英 | `GGUF 格式`、`Gemma 4` |
| 縮寫 | 保留大寫 | `RAG`、`MCP`、`PKM` |
| 多義詞 | 加限定詞 | `提示詞反推（Image Captioning）` 而非 `提示詞反推` |

**多義詞處理**（重要）：當不同主題有相同名稱（如 "Transformer" 既是 AI 模型也是電器），仍**用限定詞區分檔名**，不是用 alias 處理。範例：`Transformer 架構` vs `Transformer 變壓器`。詳見第 7 節。

**避免無意義差異**：同一主題不要在不同頁面寫成 `RAG` 和 `RAG 模型` 與 `Retrieval-Augmented Generation` 並行存在。選一個作為檔名，其餘進 aliases。

### 4. 中文名稱的處理

中文名稱**不直接**作為檔名或 wikilink，而是透過 aliases 對應：

```yaml
---
title: "注意力機制"          # title 可以是中文（圖譜節點顯示）
aliases:
  - "Attention Mechanism"   # 英文全稱
  - "Attention"             # 英文縮寫
  - "Self-Attention"        # 變體
---
```

```markdown
## Definition

注意力機制（Attention Mechanism）是一種讓神經網路能夠...
```

正文第一段必須用 `中文（English）` 格式 introduce：

```markdown
注意力機制（Attention Mechanism）是...
```

這個格式讓 LLM 在閱讀時能同時建立中英對應，並讓 query 的全文搜尋同時匹配兩種語言。

### 5. wiki-writer 的 alias 匹配流程

<!-- decision-id: aliases-matching-flow -->

wiki-writer 在 archive Step 2 處理 concept 時，**建立新 concept 前必須執行**：

```
Sub-step 1: 從 raw 摘要抽取主題候選名稱（含原文與翻譯）
Sub-step 2: 為每個候選名稱生成 slug
Sub-step 3: 在 主題知識/{wiki_category}/ 下查找該 slug 是否存在
  - 存在 → 找到既有頁，跳到 Sub-step 6
  - 不存在 → Sub-step 4
Sub-step 4: 遍歷 主題知識/ 下所有 concept 頁的 frontmatter aliases
  - 任一 alias 字串等於候選名稱（大小寫不敏感）→ 找到既有頁，跳到 Sub-step 6
  - 全部不匹配 → Sub-step 5
Sub-step 5: 建立新 concept 頁
  - 檔名: {主slug}.md
  - frontmatter aliases: 含主名稱的所有變體（中英文）
  - 正文 Definition 第一行: 「{中文主名稱}（{English Name}）」
Sub-step 6: 更新 concept（追加 source、更新 confidence、追加 Evolution Log）
```

### 6. alias 的修改規則

<!-- decision-id: aliases-modification-rule -->

| 動作 | 允許? | 說明 |
|------|------|------|
| **新增** alias | ✅ | wiki-writer / curator / 人類都可新增 |
| **刪除** alias | ⚠ 限制 | 只有人類可在「確認誤建立」時刪除，agent 不可刪 |
| **修改** alias 的拼字 | ⚠ 限制 | 修改拼字 = 刪舊增新，需 git log 留痕 |
| **重排序** alias | ✅ | 任何人可調整使用頻率排序 |

理由：alias 列表是「我們認得這個概念的哪些稱呼」的審計資料。隨意刪除可能讓未來的 alias 匹配失敗（因為 raw 摘要可能仍用舊名）。

### 7. 同名異物的處理

<!-- decision-id: aliases-homograph-handling -->

當不同主題有相同名稱時（例如 "Transformer" 既是 AI 模型也是電器），**不要**用 alias 處理：

❌ 錯誤：
```yaml
# 主題知識/概念/transformer.md
aliases:
  - "Transformer"
  - "Transformer (AI)"
  - "Transformer (電器)"  # 不要把兩個概念塞進同一個 alias 列表
```

✅ 正確：
```
主題知識/概念/transformer-architecture.md   # AI 模型
  aliases: ["Transformer", "Transformer Model", "Self-Attention Architecture"]

主題知識/實體/transformer-electrical.md     # 電器
  aliases: ["Transformer", "Power Transformer", "電器變壓器"]
```

兩個檔案都可以有 alias `"Transformer"`。wiki-writer 偵測到衝突時必須走「**同名異物處理流程**」（見 `references/taxonomy/topic-matching-spec.md` 的 Level 2/5 判定），詢問使用者或在 agent mode 下分別建立兩個檔案並寫入待 review 清單。

### 8. Wikilink 違規的處理

curator 只偵測**真正的解析地雷**（底線、駝峰、連續中英無分隔）並列入 lint 報告：

```
outputs/lint/2026-04-20.md:
  ## ⚠ Wikilink Format Violations
  - `[[value_investing]]` in 主題知識/概念/investment.md (Line 23)
    建議: 底線形式造成 grep 困難，改為 `[[價值投資]]` 或 `[[Value Investing]]`
  - `[[valueInvesting]]` in 主題知識/總覽/2026-investment.md (Line 8)
    建議: 駝峰形式 tokenize 不穩定，改為 `[[Value Investing]]` 或 `[[價值投資]]`
```

**不再視為違規**：含中文、含大寫英文、含空格的 wikilink — 這些是領域慣例命名，與規格 v0.9.0 對齊。

curator 不會自動修補（因為改錯可能 break 其他連結），但會列入待人類處理清單。

## Examples

### Example 1：建立新 concept 並設定 aliases

```
情境: archive raw/articles/attention-explained.md

wiki-writer 處理流程:
1. 從 raw 抽取主題: "Attention Mechanism" / "注意力機制"
2. 生成 slug: "attention-mechanism"
3. 查 主題知識/概念/attention-mechanism.md → 不存在
4. 遍歷 aliases → 不匹配
5. 建立新檔:
   主題知識/概念/attention-mechanism.md
   ---
   title: "注意力機制"
   wiki_category: 概念
   aliases:
     - "Attention Mechanism"
     - "Attention"
     - "Self-Attention"
     - "注意力"
   ---

   ## Definition

   注意力機制（Attention Mechanism）是 Transformer 架構的核心組件...
6. log: ingest | attention-explained, touched_specs: [aliases-and-wikilink, ...]
```

### Example 2：alias 匹配成功避免重複建立

```
情境: archive raw/articles/self-attention-deep-dive.md

wiki-writer 處理:
1. 從 raw 抽取主題: "Self-Attention"
2. 生成 slug: "self-attention"
3. 查 主題知識/概念/self-attention.md → 不存在
4. 遍歷 aliases:
   - 主題知識/概念/attention-mechanism.md 的 aliases 含 "Self-Attention" ✓
5. 找到既有頁: 主題知識/概念/attention-mechanism.md
6. 不建立新頁，直接更新既有頁
7. Evolution Log 追加: 「2026-04-20（4 sources）：強化，新增 [[歷史紀錄/.../self-attention-deep-dive]]」
```

### Example 3：中文 raw 觸發中文 alias 匹配

```
情境: archive raw/clippings/2026-04-rag檢索增強.md（中文文章）

wiki-writer 處理:
1. 從 raw 抽取主題: "檢索增強生成" / "RAG"
2. 第一個候選 "檢索增強生成":
   - 翻譯為英文 "Retrieval-Augmented Generation"
   - slug: "retrieval-augmented-generation"
   - 查 主題知識/概念/retrieval-augmented-generation.md → 不存在
   - 查 aliases → 不匹配
3. 第二個候選 "RAG":
   - slug: "rag"
   - 查 主題知識/概念/rag.md → 存在 ✓
4. 找到既有頁: 主題知識/概念/rag.md
5. 確認該頁的 aliases 含 "檢索增強生成" → 是 → 證實匹配正確
6. 更新 rag.md，追加 source
```

### Example 4：違規 wikilink 被 curator 偵測

```
場景: 使用者手動編輯 主題知識/概念/value-investing.md，正文寫了:
  「相關概念見 [[價值投資]]」

curator 掃描:
1. 偵測到 [[價值投資]] 不符合英文 slug 格式
2. 寫入 outputs/lint/<date>.md:
   ## ⚠ Wikilink Format Violations
   - File: 主題知識/概念/value-investing.md (Line 12)
   - Wikilink: `[[價值投資]]`
   - 建議: 改為 `[[value-investing]]`
   - 注意: 這指向同一個檔案（自我引用），可能可直接刪除

3. 不自動修補
4. 待人類處理
```

### Example 5：同名異物分別建立

```
情境: 既有 主題知識/概念/transformer-architecture.md（AI 模型）
     ingest raw/articles/electrical-transformer.md（電器變壓器）

wiki-writer 處理:
1. 抽取主題: "Transformer"
2. slug: "transformer"
3. 查 transformer.md → 不存在
4. 遍歷 aliases:
   - transformer-architecture.md 的 aliases 含 "Transformer" ✓
5. 找到 candidate: transformer-architecture.md
6. **同名異物判定**: LLM 比對新 source 的 claims 與既有 concept
   - 新 source 提的 "Transformer" 是電器
   - 既有 concept 是 AI
   - **不匹配** → 觸發同名異物流程
7. agent mode:
   - 建立新檔 主題知識/實體/transformer-electrical.md
   - aliases: ["Transformer", "Power Transformer", "電器變壓器"]
   - 在 outputs/lint/<date>.md 標註「⚠ Homograph: Transformer 同時存在於 concept 與 entity」
   - overview.md 待 review 清單追加: 「Transformer 同名異物，待人類裁決命名策略」
```

## Rationale

### 為什麼 v0.9.0 從「英文 slug 鐵律」改為「跟隨領域慣例」

**v0.9.0-alpha 的設計**：沿用 Karpathy LLM Wiki 教程的英文小寫 slug 規則，理由是跨平台 / URL safe / grep 效率 / agent 友善。

**v0.9.0 的修正**（基於 leadingtw_vault 累積實踐）：

1. **wiki-writer 從未實作 slug 生成**：73 頁全部用中文/大寫英文檔名，從沒有「翻譯為英文 slug」這一步發生過。規格與實作從第一天就分叉。
2. **強制英化會破壞領域慣例**：`Claude Code` 不是 `claude-code`、`ComfyUI` 不是 `comfy-ui`、`SDXL` 不是 `sdxl` — 這些是業界官方寫法，強改 slug 反而違反讀者直覺。
3. **中文檔名實測沒問題**：Obsidian、Windows / WSL / macOS / Linux、git、grep 都能處理 UTF-8 中文檔名。Obsidian 的 wikilink 解析也支援。原本擔心的跨平台問題在 2026 年實際上已不存在。
4. **真正的解析地雷只有三類**：底線（grep 區分困難）、駝峰（tokenize 不穩定）、連續無分隔（可讀性差）。其餘都是審美問題不是技術問題。

**結論**：規格應該描述實踐能做到的事，而不是強加抽象的「乾淨」標準。中文資訊不只進 aliases，也直接進檔名與 wikilink。

### 為什麼 aliases 不可隨意刪除

aliases 是「**我們曾經認得這個概念的哪些稱呼**」的歷史記錄。如果刪除：
- 未來 raw 摘要用舊名 → 匹配失敗 → 重複建立
- git diff 才能找回 → 增加查詢成本

刪除只在「確認該 alias 是誤加」時允許，且應該是人類動作（不是 agent 自動）。

### 為什麼正文第一段強制 `中文（English）` 格式

LLM 在閱讀知識筆記時是「線性掃描」模式。第一段的格式決定了 LLM 對「這個概念的中英對應」的學習。固定格式讓：
- LLM 在建立關聯時更穩定
- query 跨語言時匹配率更高
- 人類讀者一眼就知道對應的英文術語

替代設計（把對應放 frontmatter 的 alias_pairs 之類）會讓人類讀者看不到。

### 為什麼同名異物不用 alias 處理

如果允許「兩個不同概念共用同一個 alias 列表」，wiki-writer 在 alias 匹配時會找到「錯誤的既有頁」並更新，造成內容混亂（電器變壓器的描述被寫進 AI Transformer 頁）。

正確做法是**分別建立兩個檔案**，各自有自己的 aliases 列表，但允許 alias 字串重疊（"Transformer" 可在兩個檔案的 aliases 列表中）。wiki-writer 在 alias 匹配時會找到兩個 candidate，必須走同名異物判定流程。

### 為什麼禁止底線與駝峰，但允許空格

- **底線**：grep 時 `value_investing` 會被當成單一 token，無法快速找到單字邊界。連字符也有類似問題但連字符在中文檔名中極少混用，分歧較小，所以也不視為違規。
- **駝峰**：`ValueInvesting` 與 `valueInvesting` 在 case-sensitive 系統中是兩個不同連結，容易造成「兩個檔案指同一概念」的命名分叉。tokenize 也較不穩定。
- **空格不再禁止**：Obsidian wikilink 完全支援空格（`[[Claude Code]]`），且這正是 wiki-writer 在 archive 流程中累積的慣例（73 頁中超過 30 個檔名含空格）。Markdown 規範也允許。實測沒有相容性問題。

### 與 Karpathy 教程的差異

Karpathy 教程的 Wikilink 格式鐵律是「英文小寫連字符」，但那個教程針對的是**英文母語社群**的純英文 vault。對中文使用者而言，強制中文 → 英文翻譯 → slug 化會丟失原始語境（「個人知識管理」翻成 `personal-knowledge-management` 後反而不利於中文 grep）。本 plugin 的規格在 v0.9.0 起與 Karpathy 教程**主動分流**：保留 aliases 跨語言設計，但 wikilink 命名跟隨使用者實際語言慣例。

## Cross References

- `references/taxonomy/topic-matching-spec.md` — 主題匹配演算法（含同名異物判定）
- `references/taxonomy/wiki-category-spec.md` — wiki_category 4 分類
- `references/taxonomy/tag-topic-spec.md` — tags 規範（與 aliases 是兩個不同欄位）
- `references/governance/agent-mode.md` — agent 不可刪除 aliases
- `references/structure/templates-spec.md` — 知識筆記 frontmatter 範本（v0.9.0-beta 將補 aliases 必填）
- v0.9.0-beta 將更新 `agents/wiki-writer.md` 加入 alias 匹配 sub-steps
- v0.9.0-rc 將更新 `skills/curator/SKILL.md` 加入 wikilink 格式違規檢查
