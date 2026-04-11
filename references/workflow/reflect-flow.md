# Reflect Flow (Lightweight Four Stages)

> **status**: v0.9.0-alpha（new spec）
> **scope**: workflow — 流程定義
> **authority**: 本檔為 reflect skill 的權威流程定義
> **inspired by**: Karpathy LLM Wiki 教程的 REFLECT 四階段機制

## Summary

reflect skill 是 obsidian-vault-tool v0.9 的新增認知層活動，對應 Karpathy LLM Wiki 教程的 REFLECT 操作。**v5 修正後採「輕量四階段」實作**：Stage 0（反向檢驗）+ Stage 1（輕量模式掃描，候選集 ≤ 10）+ Stage 3（Gap Analysis）在 v0.9.0-rc 實作為「Preview 版本」；Stage 2（深度合成）延 v1.0。設計初衷是讓 LLM / agent 能定期「審視自己的累積知識」並識別回音室風險、知識空白、孤立概念。

## Core Concepts

1. **二階認知**：reflect 不是「歸檔來源」也不是「回答問題」，而是「**檢查知識庫自身的健康**」
2. **四階段**：Stage 0 / 1 / 2 / 3 各有不同的認知任務
3. **輕量化**：v0.9 不做全庫掃描，只在「候選集 ≤ 10」時跑模式掃描，超過則樣本掃描
4. **Preview 標示**：v0.9 的 reflect 輸出必須明確標示為 Preview，讓使用者知道是輕量版
5. **mode 分流**：human 詢問是否新增為 question / 是否升級結論；agent 自動寫 outputs/reflect/，QUESTIONS.md 自動 append

## Specification

### 1. Reflect 觸發詞

| 觸發詞 | 動作 |
|-------|------|
| `reflect` | 完整四階段（v0.9 = Stage 0 + Stage 1 lightweight + Stage 3）|
| `reflect --stage 0` | 只跑 Stage 0 反向檢驗 |
| `reflect --stage 3` | 只跑 Stage 3 Gap Analysis |
| `reflect --topic <slug>` | 對特定 topic 跑反向檢驗（其他 stage 跳過）|
| 「二階分析」「綜合分析」「發現規律」 | 完整四階段 |
| 「找漏洞」「找空白」 | 跑 Stage 3 |

### 2. Stage 定義

<!-- decision-id: reflect-stages-definition -->

| Stage | 名稱 | 任務 | v0.9 實作 |
|-------|------|------|---------|
| **Stage 0** | 反向檢驗 | 對既有結論主動找反證 | ✅ 完整實作 |
| **Stage 1** | 模式掃描 | 跨來源找模式、隱性關聯、矛盾對 | ⚠ 輕量版（候選集 ≤ 10 才跑全掃，否則樣本掃描 + 標示「不完整」）|
| **Stage 2** | 深度合成 | 對有支撐的候選項寫 synthesis 草稿 | ❌ **延 v1.0**（不實作，但留 spec hook）|
| **Stage 3** | Gap Analysis | 找孤立概念、隱性盲區、覆蓋稀薄領域 | ✅ 完整實作 |

### 3. Stage 0 — 反向檢驗

**目的**：對既有 concept 頁的 Definition 與既有 synthesis 的結論，**主動在已有 sources 中找反證**。

**輸入**：reflect 範圍（預設全部 concept 頁，可用 `--topic <slug>` 限縮）

**流程**：

```
For each concept in 範圍:
  1. 讀取 concept 頁的 ## Definition 段落
  2. 抽取主要 claim（LLM 摘要為 1-3 個關鍵主張）
  3. For each claim:
     a. 從該 concept 的 sources 列表中遍歷
     b. 在每個 source 頁的 ## Key Points / ## My Notes 段落找與 claim 相反或矛盾的內容
     c. 若找到 → 記為「反證」
  4. 若全部找完仍無反證:
     → 標記為「⚠ 回音室風險」（無可辯論的反向證據）
  5. 若找到 ≥ 1 反證:
     → 寫入 outputs/reflect/warnings.md（append-only）

For each synthesis (主題知識/總覽/*.md):
  同上流程，對 synthesis 的 Thesis 段落
```

**輸出**：

```markdown
（append 到 outputs/reflect/warnings.md）

## 2026-04-20 ⚠ 反向檢驗結果

### Concepts 檢驗
- ✓ [[主題知識/概念/RAG]] — 找到 2 個反證 source（已在 RAG.md 的 Contradictions 標註）
- ⚠ [[主題知識/概念/Transformer]] — 0 個反證，回音室風險
- ✓ [[主題知識/概念/Attention]] — 找到 1 個反證 source

### Synthesis 檢驗
- ⚠ [[主題知識/總覽/AI技術全景]] — 主結論「Transformer 是當代 AI 核心」未找到反證
  - 建議: 主動尋找質疑 Transformer 主導性的來源
```

### 4. Stage 1 — 模式掃描（輕量版）

**目的**：跨多個 concept / source 找隱性關聯、模式、矛盾對。

**輸入**：候選集（候選集篩選見下）

**候選集篩選規則（v0.9 輕量化關鍵）**：

```
Step S1.1: 列出所有 concept 頁
Step S1.2: 過濾條件:
  - confidence ≥ medium（過濾掉 low confidence 的不穩定頁）
  - last_reviewed > 30 天前 OR 從未檢驗過
  - 不在「最近 reflect 已掃描過」清單中（避免重複）
Step S1.3: 取結果集
Step S1.4: 若結果集 ≤ 10:
  → 執行完整模式掃描（讀完所有候選的全文）
  → output_kind: reflect-pattern-full
Step S1.5: 若結果集 > 10:
  → 執行樣本掃描（隨機選 10 個）
  → output_kind: reflect-pattern-sample
  → 在輸出頂端標示「⚠ 樣本掃描，未涵蓋所有候選」
Step S1.6: 寫入 outputs/reflect/pattern-{date}.md
```

**Pattern 偵測類型**：

| Pattern | 偵測方式 | 範例 |
|---------|---------|------|
| 隱性關聯 | 兩個 concept 在多個 source 中共現但無 wikilink | RAG 與 Vector DB 在 5 個 source 共現但 RAG.md 未連結 Vector-DB.md |
| 矛盾對 | 兩個 concept 的 Definition 互斥但無交叉引用 | Concept A 主張 X，Concept B 主張 not X |
| 概念合併候選 | 兩個 concept 的 aliases 高度重疊 | A.aliases 與 B.aliases 有 ≥ 2 個重疊 |
| 缺失中介概念 | 多個 source 都提到某個術語但無 concept 頁 | "Chain-of-Thought" 出現在 4 個 source 但無頁 |

**輸出**：

```markdown
---
type: output
output_kind: reflect-pattern-full | reflect-pattern-sample
date: 2026-04-20
graph-excluded: true
generator: reflect
candidates_total: 8
candidates_scanned: 8       # full → 全部，sample → 10
---

## Pattern Scan Report — 2026-04-20

### 隱性關聯
- [[主題知識/概念/RAG]] 與 [[主題知識/概念/Vector-DB]] 在 5 個 source 中共現但 RAG.md 未連結 Vector-DB.md
  - 建議: 在 RAG.md 加入 [[主題知識/概念/Vector-DB]] 連結

### 缺失中介概念
- "Chain-of-Thought" 出現在 4 個 source（[[歷史紀錄/.../1]], [[.../2]], [[.../3]], [[.../4]]）但無 concept 頁
  - 建議: 建立 主題知識/概念/chain-of-thought.md
```

### 5. Stage 2 — 深度合成（**v1.0 延後**）

**v0.9 不實作**，但 spec 預留：

- output_kind: `reflect-synthesis`
- 寫入路徑: `outputs/reflect/synthesis-draft-{topic-slug}.md`
- 流程: 對 Stage 1 找到的「隱性關聯」候選，由 synthesis-writer agent 寫合成草稿
- 預期實作時機: v1.0（需要 20+ sources 的累積，且需要正式索引層支援）

**v0.9 的暫代行為**：
- reflect skill 跳過 Stage 2
- 在 outputs 中加註 `## Stage 2 — Skipped (v1.0 will implement)`

### 6. Stage 3 — Gap Analysis

**目的**：找出知識庫的「**沒有被覆蓋到的領域**」。

**三個子任務**：

#### 6.1 Isolated Concepts

```
過濾條件:
  - source_count == 1
  - 建立日期 > 30 天前
  - 沒有從其他 concept 頁的 wikilink 指向

動作:
  - 列入 gap-report 的 "Isolated Concepts" 段落
  - 建議: 尋找補充 source 或考慮降級為 low confidence
```

#### 6.2 Implicit Concepts

```
過濾條件:
  - 在 ≥ 3 個 source 頁的 ## Concepts Extracted 段落中被提及
  - 沒有對應的 concept 頁
  - 對應的 slug 也未在任何既有 concept 頁的 aliases 中

動作:
  - 列入 gap-report 的 "Implicit Concepts" 段落
  - 建議: 為這些概念建立 concept 頁
```

#### 6.3 Coverage Gaps

```
比對對象:
  - 主題知識/總覽/*.md 列出的「子領域清單」
  - vs 主題知識/概念/ 下實際存在的 concept 頁

過濾條件:
  - 子領域對應的 concept 頁數 < 2

動作:
  - 列入 gap-report 的 "Coverage Gaps" 段落
  - 建議: 該子領域知識稀薄，考慮主動擴充
```

**輸出**：見 `references/structure/outputs-layer.md` 的 gap-report 範例。

### 7. Mode 分流

| 動作 | Human Mode | Agent Mode |
|------|-----------|-----------|
| Stage 0 ⚠ 回音室風險 | 顯示警告，詢問是否要主動補 source | 寫 outputs/reflect/warnings.md (append)，不阻塞 |
| Stage 1 找到隱性關聯 | 顯示，詢問是否要建立連結 | 寫 outputs/reflect/pattern-{date}.md，**不修改** concept 頁 |
| Stage 1 找到缺失中介概念 | 顯示，詢問是否新增為 QUESTIONS.md 開放問題 | **自動**新增為 QUESTIONS.md 開放問題（標記 `by agent`）|
| Stage 3 isolated concepts | 顯示，詢問是否降級 confidence | 列入 gap-report，**不降級**（confidence-gating 規則）|
| Stage 3 implicit concepts | 詢問是否建立 concept 頁 | **不建立**（agent 不主動建立 concept），列入 gap-report |
| Stage 3 coverage gaps | 詢問是否新增為 question | **自動**新增為 QUESTIONS.md（標記 `by agent`）|

### 8. Preview 標示規則

v0.9 的 reflect 輸出必須在頂部加 Preview 標示：

```markdown
> **⚠ v0.9 Preview**
> 本 reflect 報告為輕量版實作：
> - Stage 0 反向檢驗：完整實作
> - Stage 1 模式掃描：候選集 ≤ 10 才跑全掃，否則樣本掃描
> - Stage 2 深度合成：v0.9 未實作（v1.0 預定）
> - Stage 3 Gap Analysis：完整實作
>
> 完整 REFLECT 將於 v1.0 發布。
```

這個標示確保：
- agent 讀取時知道實作邊界
- 人類使用者不會誤把 Preview 結論當成最終答案
- 防止 Gemini 在 Brain Trust v3+v4 R2 提出的「虛假安全性感」風險

### 9. 互動範例（完整 reflect 流程）

#### Human Mode 範例

```
1. 使用者: reflect
2. reflect skill 啟動
3. 顯示: 「準備執行 reflect 四階段（Preview 版）...」
4. Stage 0 (反向檢驗):
   掃描 47 個 concept + 5 個 synthesis
   找到 3 個 ⚠ 回音室風險、5 個 ⚠ 矛盾標註
   寫入 outputs/reflect/warnings.md (append)
5. Stage 1 (輕量模式掃描):
   候選集篩選: 12 個 concept (confidence ≥ medium 且 > 30 天未審視)
   12 > 10 → 樣本掃描 10 個
   找到 2 個隱性關聯、1 個缺失中介概念
   寫入 outputs/reflect/pattern-2026-04-20.md
6. Stage 2: 跳過 (v1.0)
7. Stage 3 (Gap Analysis):
   找到 5 個 isolated, 3 個 implicit, 1 個 coverage gap
   寫入 outputs/reflect/gap-report-2026-04-20.md
8. 顯示總結:
   ┌──────────────────────────────────────────┐
   │ Reflect Preview 完成                     │
   │                                          │
   │ Stage 0: 3 回音室風險, 5 矛盾標註        │
   │ Stage 1: 2 隱性關聯, 1 缺失中介概念      │
   │ Stage 2: 跳過 (v1.0)                     │
   │ Stage 3: 5 isolated, 3 implicit, 1 gap   │
   │                                          │
   │ 詳見:                                    │
   │   outputs/reflect/warnings.md            │
   │   outputs/reflect/pattern-2026-04-20.md  │
   │   outputs/reflect/gap-report-2026-04-20  │
   │                                          │
   │ 是否要逐項處理？                         │
   │ [是] [否] [只看 gap]                     │
   └──────────────────────────────────────────┘
9. 使用者: 「只看 gap」
10. 主對話顯示 gap-report，逐項詢問是否新增 question
```

#### Agent Mode 範例

```
1. agent: reflect
2. reflect skill 啟動，self-check 通過
3. Stage 0:
   掃描 47 concepts
   找到 ⚠ 回音室風險 → append outputs/reflect/warnings.md
4. Stage 1:
   候選集 12 個 → 樣本掃描 10 個
   寫入 outputs/reflect/pattern-2026-04-20.md (含 reflect-pattern-sample 標記)
5. Stage 2: 跳過
6. Stage 3:
   找到 5 isolated, 3 implicit, 1 gap
   寫入 outputs/reflect/gap-report-2026-04-20.md
   **自動**將 1 coverage gap 加入 QUESTIONS.md:
     - [ ] 子領域 X 的 concept 數 < 2，是否需要主動擴充？(opened 2026-04-20, by agent)
   **自動**將 3 implicit concepts 加入 QUESTIONS.md:
     - [ ] 是否建立 chain-of-thought concept 頁？(opened 2026-04-20, by agent)
     - ...
7. log.md 記錄: reflect [agent] | found 12 issues
8. 完成，不阻塞
```

## Examples

### Example 1：reflect --topic 限縮範圍

```
使用者: reflect --topic rag

只對 主題知識/概念/rag.md 跑 reflect:
- Stage 0: 對 RAG 的 Definition 找反證
- Stage 1, 3: 跳過（範圍限縮太小）
- 輸出: outputs/reflect/warnings.md append 1 個 RAG-specific 條目
```

### Example 2：reflect 找到回音室風險

```
情境: synthesis 主題知識/總覽/AI技術全景.md 主結論「Transformer 是當代 AI 核心」

reflect Stage 0:
1. 抽取 claim: "Transformer 是當代 AI 核心"
2. 遍歷該 synthesis 引用的 8 個 source
3. 在每個 source 找反向證據
4. 結果: 0 個反證
5. 標記為 ⚠ 回音室風險
6. 寫入 outputs/reflect/warnings.md:
   ## 2026-04-20 ⚠ 回音室風險
   - synthesis: [[主題知識/總覽/AI技術全景]]
   - claim: "Transformer 是當代 AI 核心"
   - 反證 source 數: 0
   - 建議: 主動尋找質疑 Transformer 主導性的來源（例如 RWKV, Mamba 的支持者觀點）
```

### Example 3：候選集太大觸發樣本掃描

```
情境: vault 已有 30 個 confidence ≥ medium 的 concept

reflect Stage 1:
1. 候選集篩選: 30 個 (全部 medium+)
2. 30 > 10 → 樣本掃描
3. 隨機選 10 個
4. 對 10 個跑模式掃描
5. 寫入 outputs/reflect/pattern-2026-04-20.md:
   ---
   output_kind: reflect-pattern-sample
   candidates_total: 30
   candidates_scanned: 10
   ---

   > ⚠ 樣本掃描: 候選集 30 > 10，僅掃描 10 個樣本
   > 完整掃描需 v1.0 索引層支援

   ## 隱性關聯
   - ...
```

## Rationale

### 為什麼 v0.9 做 Stage 0 + 1 + 3 但不做 Stage 2

Brain Trust v3+v4 三方在 R2 對 reflect 深度有分歧。Claude 修正後的 v5 plan 是「輕量四階段」：

- **Stage 0**：成本極低（只比對 Definition 與 sources），價值極高（防回音室）→ 必做
- **Stage 1**：候選集小時成本可控，價值在「找連結漏洞」→ 輕量做
- **Stage 2**：深度合成需要 LLM 對 ≥ 20 個 source 做整合，且需要索引層支援，**v0.9 規模不夠**→ 延後
- **Stage 3**：純統計分析（過濾 source_count、找實體 vs aliases），成本最低 → 必做

Stage 2 是「**錦上添花**」而非「雪中送炭」——v0.9 沒有它使用者也能用 reflect，有它要等 v1.0 累積足夠規模。

### 為什麼候選集 ≤ 10 是 Stage 1 的閾值

10 是一個經驗值，理由：
- LLM 一次完整讀 10 個 concept 頁的 context 仍在合理範圍（~10K tokens）
- 超過 10 後 LLM 容易混淆細節，pattern 偵測準確率下降
- 10 是 vault 早期常見規模（v0.9 剛起步時很可能 ≤ 10）

10 不是硬性閾值，而是 v0.9 的初始值。v1.0 升級正式索引層後，可改為「依索引動態決定」。

### 為什麼 reflect 不修改 concept 頁

reflect 的所有發現（Stage 0 反證、Stage 1 隱性關聯、Stage 3 gap）**都不直接寫進 concept 頁**，而是寫入 outputs/reflect/。

理由：
- concept 頁是「經過 ingest + curator 認可的整合知識」
- reflect 是「**探索性發現**」，未經人類確認
- 直接寫進 concept 頁會污染 ingest 階段的乾淨輸入
- outputs/reflect/ 是中介層，等人類審視後才升級回 concept 頁

例外：Stage 0 的反證若被 wiki-writer 在 ingest 階段就偵測到（不是 reflect 階段），會直接寫進 concept 頁的 ## Contradictions（見 `references/quality/contradictions.md`）。reflect 的反證是探索性質的「**潛在矛盾**」，與 ingest 階段的「**明確矛盾**」屬於不同類別。

### 為什麼 agent mode 自動加 QUESTIONS 而 human mode 詢問

agent mode 下無法詢問，必須有預設動作。reflect Stage 3 找到的 gap 是「**值得追問**」的訊號，自動加為 QUESTIONS.md 開放問題是合理的預設——後續人類可以審視這些 question 並決定關閉或處理。

human mode 下詢問是因為人類有更精確的判斷能力（「這個 gap 我其實不在意」「這個 implicit concept 不重要」），不該讓 reflect 自動產生使用者不想處理的 question。

### 為什麼 reflect 不更新 last_reviewed

`last_reviewed` 是「人類或 LLM **明確確認過內容仍然準確**」的訊號。reflect 是「掃描」而非「審視」——它讀 concept 頁但不確認內容對錯。

如果 reflect 自動更新 last_reviewed，會出現「跑一次 reflect → 所有 stale 都被重置 → 看似新鮮但實際沒人 review 過」的假象，破壞 staleness 機制（見 `references/quality/staleness.md`）。

### 與 Karpathy 教程的差異

Karpathy 教程的 REFLECT 是完整四階段：
- Stage 0: 反向檢驗（同 obsidian-vault-tool）
- Stage 1: 模式掃描（同，但 Karpathy 用 qmd 索引輔助，能掃全庫）
- Stage 2: 深度合成（同，但 Karpathy 直接寫 wiki/synthesis/）
- Stage 3: Gap Analysis（同）

obsidian-vault-tool v0.9 的差異：
- **沒有 qmd 索引** → Stage 1 限制候選集 ≤ 10
- **沒有 synthesis-writer 完整實作** → Stage 2 延 v1.0
- **加入「Preview 標示」** → 防虛假安全感（v5 修正）
- **mode 分流** → agent 自動加 QUESTIONS / 不修改 concept

v1.0 升級到正式索引層後，Stage 1 與 Stage 2 將完整對齊 Karpathy 教程。

## Cross References

- `references/governance/agent-mode.md` — reflect 在 agent mode 下的 fallback
- `references/governance/confidence-gating.md` — reflect 不變更 confidence
- `references/quality/contradictions.md` — Stage 0 反證 vs ingest 矛盾的區分
- `references/quality/staleness.md` — reflect 不更新 last_reviewed
- `references/structure/outputs-layer.md` — outputs/reflect/ 的目錄與檔案規範
- `references/workflow/ask-flow.md`（同 commit 新增）— reflect 自動加 QUESTIONS 的格式
- v0.9.0-rc 將新增 `skills/reflect/SKILL.md` 與 `commands/reflect.md`
- v0.9.0-rc 將新增 `agents/synthesis-writer.md`（Stage 2 的骨架）
- v1.0 將更新本 spec 加入 Stage 2 完整實作
