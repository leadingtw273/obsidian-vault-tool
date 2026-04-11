# Confidence Gating

> **status**: v0.9.0-alpha（new spec）
> **scope**: governance — 治理層
> **authority**: 本檔為 confidence 升級規則的權威定義
> **inspired by**: Karpathy LLM Wiki 模式的 confidence 三級制

## Summary

知識筆記的 `confidence` 欄位表示「**對此概念的認知把握度**」，分為 `low / medium / high` 三級。低/中級可由 LLM 自動依 source 數量升級，但 **`high` 必須由人類明確確認**——這是防止「錯誤複利」（錯誤概念被自動標記為高信心後在後續 query 中持續被引用強化）的核心機制。Agent mode 下無人類確認時降級為 `high_candidate` 寫入待 review 清單，主流程不阻塞。

## Core Concepts

1. **三級制**：`low` / `medium` / `high`，預設 `low`
2. **source_count**：引用此概念的**外部來源**數量（personal-writing 不計入）
3. **自動升級門檻**：`low → medium` 在 3 sources、`medium → high_candidate` 在 5 sources
4. **人類門控**：`high_candidate → high` 必須由人類明確確認，禁止自動升級
5. **降級**：發現重大矛盾時必須降級並在 Contradictions 段落記錄
6. **agent fallback**：agent mode 下自動止步於 `high_candidate`，寫入 `overview.md` 待 review 清單

## Specification

### 1. 欄位定義

知識筆記（`主題知識/{概念|實體|比較|總覽}/*.md`）的 frontmatter 必須含以下欄位：

```yaml
---
title: "RAG"
wiki_category: 概念
confidence: low                # low / medium / high
source_count: 0                # 引用此概念的外部來源數
domain_volatility: medium      # high / medium / low（驅動 staleness）
last_reviewed: 2026-04-15      # 最近一次被人類或 agent 更新的日期
high_candidate: false          # 僅 agent mode 下可能為 true
aliases:                       # 中英雙語別名（v0.9.0-beta 新增 spec）
  - "Retrieval-Augmented Generation"
  - "檢索增強生成"
---
```

### 2. source_count 計數規則

<!-- decision-id: confidence-source-count-rules -->

| 來源類型 | 計入 source_count? | 理由 |
|---------|-------------------|------|
| `raw/articles/` | ✅ | 標準外部來源 |
| `raw/clippings/` | ✅ | Web Clipper 來源 |
| `raw/pdfs/` | ✅ | PDF 參考 |
| `raw/notes/` | ✅ | 隨手記錄（仍算外部觀察）|
| `raw/personal/` | ❌ | 個人寫作不可給自己背書 |
| 其他知識筆記引用此概念 | ❌ | 內部交叉引用不算「來源」 |
| 同一個 raw 檔多次 ingest（例如 re-ingest）| ❌ 只算一次 | 用 source 頁的 wikilink 去重 |

### 3. 自動升級規則

<!-- decision-id: confidence-auto-promotion-rules -->

| 當前 confidence | 條件 | 動作 |
|----------------|------|------|
| `low` | source_count < 3 | 維持 `low` |
| `low` | source_count ≥ 3 且無重大矛盾 | **自動升級** `medium` |
| `medium` | source_count < 5 | 維持 `medium` |
| `medium` | source_count ≥ 5 且無重大矛盾 | **進入 gate 流程**（見下） |
| `high_candidate` | — | 等待人類確認或降級 |
| `high` | — | 不會自動升級（已是頂層） |

「重大矛盾」定義：concept 頁的 `## Contradictions` 段落含「⚠ 矛盾」標記的條目。

### 4. Gate 流程（medium → high）

#### Human Mode

```
1. wiki-writer 偵測 source_count ≥ 5 且無矛盾
2. 暫停 archive 流程
3. 顯示給使用者：
   ┌─────────────────────────────────────────────┐
   │ 概念「RAG」現在有 5+ 來源且無重大矛盾       │
   │ 是否確認 confidence: high？                 │
   │                                             │
   │ Definition:                                 │
   │   [當前 concept 頁的 Definition 段落]       │
   │                                             │
   │ Sources:                                    │
   │   - [[wiki/sources/rag-paper-2024]]         │
   │   - [[wiki/sources/transformer-blog]]       │
   │   - ... (5 個)                              │
   │                                             │
   │ [確認] [跳過] [維持 medium]                 │
   └─────────────────────────────────────────────┘
4. 使用者明確回覆 "確認" / "ok" / "yes"
5. wiki-writer 寫入 confidence: high，updated 與 last_reviewed
6. 在 Evolution Log 追加：
   - YYYY-MM-DD（5 sources）：人類確認 confidence 升級為 high
7. 繼續 archive 流程
```

#### Agent Mode

```
1. wiki-writer 偵測 source_count ≥ 5 且無矛盾
2. 不暫停，直接執行 fallback：
   - 維持 confidence: medium
   - 寫入 frontmatter: high_candidate: true
   - 寫入 frontmatter: high_candidate_since: YYYY-MM-DD
3. 在 vault/overview.md 的「待 Review 清單」追加：
   ### high_candidate confidence（待人類確認升級為 high）
   - [ ] [[主題知識/概念/RAG]] — 5 sources，agent 標記日期 YYYY-MM-DD
4. log.md 條目：
   ## [YYYY-MM-DD HH:MM] ingest [agent] | RAG 架構簡介
   touched_specs: [confidence-gating, agent-mode]
   high_candidate_promoted: 主題知識/概念/RAG.md
5. 繼續 archive 流程
```

詳細 mode 機制見 `references/governance/agent-mode.md`。

### 5. 降級規則

<!-- decision-id: confidence-demotion-rules -->

| 觸發條件 | 動作 |
|---------|------|
| 新 source 與既有 Definition 矛盾，且 wiki-writer 無法調和 | 在 `## Contradictions` 標註 ⚠ 矛盾，confidence 降一級（high → medium、medium → low、low 維持並 flag）|
| `domain_volatility: high` 且 `last_reviewed` > 90 天 | 標 `possibly_outdated: true`，confidence 不變但 query 時必須警告 |
| `domain_volatility: medium` 且 `last_reviewed` > 180 天 | 同上 |
| `domain_volatility: low` 且 `last_reviewed` > 365 天 | 同上 |
| 人類明確要求降級 | 直接降，記在 Evolution Log |
| Agent 偵測到矛盾 | **不降級**，僅在 Contradictions 標 ⚠，並在 `outputs/lint/<date>.md` 記「待人類處理」|

理由：降級是不可逆的認知判斷，agent 不能單方面執行（避免抹除歷史）。但「標記矛盾」是事實記錄，agent 可以做。

### 6. 與 wiki-writer 的整合點

wiki-writer agent 在 archive Step 2 處理 concept 頁時，必須執行以下子流程：

```
Sub-step 1: 讀取既有 concept 頁（若存在）
Sub-step 2: 計算新 source_count = 既有 + 1（去重後）
Sub-step 3: 檢查 Contradictions 段落是否有「⚠ 矛盾」標記
Sub-step 4: 依「自動升級規則表」判定動作
Sub-step 5: 若觸發 gate：
  - 讀取 vault/CLAUDE.md 的 interaction_mode
  - human → 進入 human gate 流程
  - agent → 進入 agent fallback 流程
Sub-step 6: 寫入 frontmatter 並更新 Evolution Log
```

詳細實作見 v0.9.0-beta 的 `agents/wiki-writer.md` 更新（本 commit 不動 wiki-writer，只定義 spec）。

### 7. Evolution Log 與 confidence 變化的關聯

每次 confidence 變化必須在 concept 頁的 `## Evolution Log` 段落追加一條：

```markdown
## Evolution Log

- 2026-04-10（1 source）：建立，confidence: low
- 2026-04-12（3 sources）：強化：自動升級為 medium，新增 [[wiki/sources/transformer-blog]]
- 2026-04-15（5 sources）：human 確認升級為 high，無矛盾
- 2026-04-18（5 sources）：發現新矛盾，降級為 medium，見 Contradictions
```

格式：`- YYYY-MM-DD（N sources）：[動作描述]`

注意：Evolution Log 的**自動判定**（強化/修正/分歧）留到 v1.0，v0.9 只記錄事實（升級/降級/維持 + sources 數量）。

## Examples

### Example 1：典型升級路徑（human mode）

```
Day 1: ingest 第 1 篇 RAG 文章
  → 建立 主題知識/概念/RAG.md
  → confidence: low, source_count: 1
  → Evolution Log: 「2026-04-10（1 source）：建立」

Day 5: ingest 第 3 篇 RAG 文章
  → 自動升級 medium
  → confidence: medium, source_count: 3
  → Evolution Log: 「2026-04-14（3 sources）：自動升級為 medium」

Day 10: ingest 第 5 篇 RAG 文章
  → 觸發 gate
  → 顯示給人類，人類回覆「確認」
  → confidence: high, source_count: 5
  → Evolution Log: 「2026-04-19（5 sources）：human 確認升級為 high」
```

### Example 2：agent mode 下的 high_candidate

```
Day 1-9: 同上（low → medium）

Day 10: agent ingest 第 5 篇 RAG 文章
  → 觸發 gate
  → agent mode → fallback
  → confidence: medium（維持）, high_candidate: true
  → high_candidate_since: 2026-04-19
  → 在 overview.md 待 review 清單追加一行
  → log.md: ingest [agent] | high_candidate_promoted: 主題知識/概念/RAG.md

Day 15: 人類使用者切回 human mode
  → 看到 overview.md 待 review 清單有 RAG
  → 人類審視 concept 頁，確認 Definition 與 Sources
  → 手動或透過 ask skill 確認升級
  → wiki-writer 寫入 confidence: high, high_candidate: false
  → 從待 review 清單標記 [x]（不刪除）
  → Evolution Log: 「2026-04-24（5 sources）：human 確認升級為 high（agent 標記候選日期 2026-04-19）」
```

### Example 3：矛盾觸發降級

```
當前狀態:
  confidence: high, source_count: 6
  Definition: "RAG 是 retrieval + generation 的兩階段架構"

新 source ingest（第 7 篇）:
  該文章主張 "RAG 是 single-pass joint training，不是兩階段"
  與現有 Definition 矛盾

human mode:
  → wiki-writer 偵測矛盾
  → 在 ## Contradictions 追加 ⚠ 條目
  → 詢問使用者：「新 source 與現有 Definition 矛盾，是否降級為 medium？」
  → 使用者「是」
  → confidence: medium, source_count: 7
  → Evolution Log: 「2026-04-20（7 sources）：發現矛盾降級為 medium」

agent mode:
  → wiki-writer 偵測矛盾
  → 在 ## Contradictions 追加 ⚠ 條目
  → 不降級
  → 在 outputs/lint/2026-04-20.md 記「[[主題知識/概念/RAG]] 出現矛盾，待人類審視」
  → confidence: high（維持）, source_count: 7
  → Evolution Log: 「2026-04-20（7 sources）：agent 標記矛盾，待人類審視降級」
```

## Rationale

### 為什麼 high 必須人類確認

Karpathy LLM Wiki 教程的原始設計哲學：「**錯誤複利**」是知識庫最大的隱性風險。一旦錯誤概念被自動標記為 high confidence，後續所有 query 都會優先引用它，形成自我強化迴圈。當使用者後來發現錯誤，往往已經有大量衍生筆記基於這個錯誤概念，修復成本極高。

人類確認 = 防止錯誤複利的最後一道閘門。**5 個來源夠多了不代表我認可這個 Definition**——人類的「我認可」是 high confidence 的真實意義。

### 為什麼 agent 不能自我確認 high

agent 的自我確認在邏輯上是循環的：「我（agent）認為這 5 個來源足夠 → 我（agent）就升級它」。這跟「沒有 confidence gate」沒區別。`high_candidate` 是 agent 給人類的「提示」而非「結論」。

### 為什麼降級規則對 agent 比較保守（只標記不降級）

降級是**對既有結論的反向修正**，會丟失歷史脈絡。如果 agent 自動降級錯了（例如新 source 其實是補充而非矛盾），會誤刪有效資訊。標記矛盾比降級更可逆——人類稍後可以看到「agent 標的矛盾」並做最終裁決。

### 為什麼 personal-writing 不計入 source_count

leadi 自己寫的 raw/personal/ 文章如果計入 source_count，會出現「我寫一篇支持 X 的文章 → confidence 升級 → query 時 plugin 告訴我 X 有高信心 → 我以為這是客觀證據但其實只是我自己的話」的自我背書迴圈。

排除 personal-writing 是維護「source_count 反映外部認可度」這個語意的關鍵。

### 為什麼自動升級門檻是 3 與 5

這兩個數字繼承自 Karpathy 教程，沒有實證依據，是經驗值：
- 3 sources：足以排除「單一來源偏見」（最低多元化門檻）
- 5 sources：足以建立「跨來源共識」的初步證據

未來若實際使用發現門檻不對，可在 v1.0 調整。alpha 階段使用這兩個數字保持與 Karpathy 教程相容。

### 與 obsidian-vault-tool 既有 wiki_category 的關係

`wiki_category`（概念/實體/比較/總覽）描述「**這頁是什麼類型**」，`confidence` 描述「**對這頁內容的把握度**」。兩者正交：
- 一個 `wiki_category: 比較` 的頁面也可以有 `confidence: low`（剛開始整理）
- 一個 `wiki_category: 概念` 的頁面也可以有 `confidence: high`（多源確認）

confidence-gating 不影響 wiki_category 的判定流程，後者見 `references/taxonomy/wiki-category-spec.md`。

## Cross References

- `references/governance/agent-mode.md` — agent mode 機制總覽與 fallback 表
- `references/taxonomy/wiki-category-spec.md` — wiki_category 4 分類定義
- `references/quality/contradictions.md`（v0.9.0-beta 新增）— Contradictions 段落格式與矛盾偵測規則
- `references/quality/staleness.md`（v0.9.0-beta 新增）— domain_volatility 與時效檢查
- v0.9.0-beta 將更新 `agents/wiki-writer.md` 加入 confidence gate sub-steps
