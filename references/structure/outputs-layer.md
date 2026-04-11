# Outputs Layer

> **status**: v0.9.0-alpha（new spec）
> **scope**: structure — 結構層
> **authority**: 本檔為 outputs/ 目錄結構與寫入規則的權威定義
> **inspired by**: Karpathy LLM Wiki 教程的 outputs/ 持久化機制

## Summary

vault 內新增 `outputs/` 層作為「**LLM / agent 產出的持久化區域**」——query 答案、reflect 報告、curator lint 結果都寫進這裡。outputs 與「歷史紀錄」「主題知識」是三個正交層：歷史紀錄是來源、主題知識是合成、outputs 是**產出的副本**。本機制讓 query / reflect 的成果不會消失在對話歷史裡，可被後續引用、可累積、可審計。

## Core Concepts

1. **outputs/ 目錄**：vault 內的新一級資料夾，與 `歷史紀錄/` `主題知識/` 平行
2. **三個子目錄**：`outputs/queries/` / `outputs/reflect/` / `outputs/lint/`
3. **graph-excluded**：outputs 內所有檔案的 frontmatter 必須含 `graph-excluded: true`，避免污染 Obsidian graph view
4. **append-only 原則**：outputs 內的檔案傾向只追加不修改（保留審計）
5. **回填機制**：outputs/queries/ 的高價值答案可由人類「升級」回填為 主題知識/總覽/ 的 synthesis 頁

## Specification

### 1. 目錄結構

```
vault/
├── 歷史紀錄/                    # 來源層（既有）
├── 主題知識/                    # 知識層（既有）
└── outputs/                    # ⭐ 產出層（v0.9.0-alpha 新增）
    ├── queries/               # query skill 的答案
    │   ├── 2026-04-15-rag-vs-finetune.md
    │   ├── 2026-04-16-attention-explained.md
    │   └── ...
    ├── reflect/               # reflect skill 的報告
    │   ├── gap-report-2026-04-15.md
    │   ├── synthesis-draft-attention.md
    │   ├── warnings.md         # agent mode 下的反向檢驗警告（append-only）
    │   └── ...
    └── lint/                  # curator skill 的健康檢查報告
        ├── 2026-04-15.md
        ├── 2026-04-22.md
        └── ...
```

### 2. 共通 frontmatter 規則

<!-- decision-id: outputs-frontmatter-rule -->

outputs/ 內所有檔案的 frontmatter 必須含：

```yaml
---
type: output
output_kind: query | reflect-gap | reflect-synthesis | reflect-warning | lint
date: 2026-04-15
graph-excluded: true        # 必填，避免污染 Obsidian graph view
generator: query | reflect | curator
interaction_mode: human | agent  # 產生時的 mode
---
```

| 欄位 | 必填 | 說明 |
|------|------|------|
| `type` | ✅ | 固定值 `output` |
| `output_kind` | ✅ | 細分類 |
| `date` | ✅ | 產生日期 |
| `graph-excluded` | ✅ | 必為 `true` |
| `generator` | ✅ | 哪個 skill 產生的 |
| `interaction_mode` | ✅ | human / agent，便於追溯 |

### 3. outputs/queries/ — query skill 的答案

#### 命名規則

```
outputs/queries/{YYYY-MM-DD}-{slug}.md
```

slug 為「使用者問題的英文 slug 化」（如 "RAG vs FineTune" → `rag-vs-finetune`）。

#### 內容結構

```markdown
---
type: output
output_kind: query
date: 2026-04-15
graph-excluded: true
generator: query
interaction_mode: human
question: "RAG 和 FineTune 哪個更適合我的場景？"
sources_consulted: 5         # 諮詢的 source 頁數
concept_pages_consulted: 3    # 諮詢的 concept 頁數
---

## Question

RAG 和 FineTune 哪個更適合我的場景？

## Answer

[實際答案，含 wikilinks 引用既有 source / concept]

根據 [[主題知識/概念/RAG]] 與 [[主題知識/概念/FineTune]] 的對比...

## Sources Consulted

- [[歷史紀錄/文章/2026-04-10/01_RAG架構簡介]] (confidence: high)
- [[歷史紀錄/文章/2026-04-12/03_FineTune實戰]] (confidence: medium)
- ... (5 個)

## Concept Pages Consulted

- [[主題知識/概念/RAG]] (confidence: high)
- [[主題知識/概念/FineTune]] (confidence: medium)
- [[主題知識/比較/RAG-vs-FineTune]] (confidence: low)

## ⚠ Confidence Notes

- [[主題知識/比較/RAG-vs-FineTune]] 是 low confidence，本回答的對比結論需要更多 source 驗證
- [[歷史紀錄/文章/2026-04-12/03_FineTune實戰]] 來源 > 1 年，部分技術細節可能過時
```

#### 寫入時機

query skill 的執行流程末尾：寫入 `outputs/queries/<date>-<slug>.md`，**不阻塞**地呈現給使用者。

### 4. outputs/reflect/ — reflect skill 的報告

#### 三種 output_kind

| output_kind | 來源 | 命名 |
|------------|------|------|
| `reflect-gap` | reflect Stage 3 Gap Analysis | `gap-report-{YYYY-MM-DD}.md` |
| `reflect-synthesis` | reflect Stage 2 深度合成（v1.0 才完整實作）| `synthesis-draft-{topic-slug}.md` |
| `reflect-warning` | reflect Stage 0 反向檢驗警告 | `warnings.md`（**單一 append-only 檔**）|

#### gap-report 範例

```markdown
---
type: output
output_kind: reflect-gap
date: 2026-04-15
graph-excluded: true
generator: reflect
interaction_mode: human
total_concepts_scanned: 47
isolated_concepts: 5
implicit_concepts: 3
---

## Gap Analysis Report — 2026-04-15

### Isolated Concepts (source_count = 1, > 30 days old)

這些 concept 只有單一來源支持，可能缺乏佐證：

- [[主題知識/概念/Mixture-of-Experts]] - 1 source, 建立 45 天前
- [[主題知識/概念/Speculative-Decoding]] - 1 source, 建立 38 天前
- ...

**建議**：尋找補充 source 或考慮降級為 low confidence。

### Implicit Concepts (多個 source 提及但無獨立頁面)

這些概念在多個 source 中被提及但尚未有獨立 concept 頁：

- "Chain-of-Thought" - 在 4 個 source 中提及
- "ReAct" - 在 3 個 source 中提及
- ...

**建議**：考慮為這些概念建立 concept 頁。

### Coverage Gaps (主題覆蓋稀薄的領域)

對比 主題知識/總覽/AI技術全景.md 列出的 12 個子領域：
- "RLHF" 子領域只有 1 個 concept 頁
- "Multimodal" 子領域沒有 concept 頁
```

#### warnings.md 範例（agent mode 累積）

```markdown
---
type: output
output_kind: reflect-warning
graph-excluded: true
generator: reflect
created: 2026-04-01
last_updated: 2026-04-20
note: "本檔 append-only，記錄 agent mode 下 reflect Stage 0 偵測到的潛在矛盾"
---

# Reflect Warnings (append-only)

## 2026-04-15 ⚠ 潛在矛盾

- concept: [[主題知識/概念/RAG]]
- 反證 source: [[歷史紀錄/文章/2026-04-15/03_RAG新論文]]
- 描述: 該 source 主張 RAG 是 single-pass，與當前 Definition 不一致
- agent 動作: 已在 RAG.md 的 Contradictions 段落標註 ⚠ 條目
- 待人類: 評估是否降級 confidence

## 2026-04-20 ⚠ 回音室風險

- concept: [[主題知識/總覽/AI技術全景]]
- 描述: synthesis-writer 嘗試合成「Transformer 是當代 AI 的核心」結論時，未在 sources 中找到任何反對立場
- agent 動作: 在 synthesis 草稿的 Limitations 段落加註「⚠ 回音室風險」
- 待人類: 主動尋找質疑 Transformer 主導性的來源
```

### 5. outputs/lint/ — curator 的健康檢查報告

#### 命名規則

```
outputs/lint/{YYYY-MM-DD}.md
```

每天最多一個檔案；若一天執行多次 curator，後續 append 到同一檔的新段落。

#### 內容結構

```markdown
---
type: output
output_kind: lint
date: 2026-04-15
graph-excluded: true
generator: curator
interaction_mode: human
checks_run: 9
violations_found: 7
---

## Lint Report — 2026-04-15

### Summary
- 9 項檢查
- 7 個違規（5 warnings, 2 errors）

### ⚠ Wikilink Format Violations
- ...

### ⚠ Stale Concepts
- [[主題知識/概念/RAG]] - 92 天未審視 (high volatility)
- ...

### ⚠ Contradiction Detected (待人類處理)
- concept: [[主題知識/概念/RAG]]
- ...

### ⚠ Orphan Pages
- [[主題知識/實體/old-entity]] - 無入鏈
- ...

### ⚠ Confidence high candidate (agent mode 標記)
- [[主題知識/概念/Transformer]] - 5 sources, agent 標記日期 2026-04-15
- ...

### ✓ 通過項目
- index.md 一致性
- log.md 格式
- 所有 source 頁有 raw_sha256 欄位
- ...
```

### 6. graph-excluded 的作用

Obsidian 的 graph view 預設會把 vault 內所有 markdown 檔案都當成節點。outputs/ 內的檔案如果不排除，會嚴重污染 graph：
- 每天的 lint 報告都成為新節點
- query 答案的 wikilink 引用會讓既有 concept 頁多出大量背向連結

`graph-excluded: true` 是 Obsidian 社群慣例（部分主題與外掛支援），讓 graph view 過濾這些檔案。即使 Obsidian 本體未來不支援，這個欄位也是文件的「**自我宣告我是 output 不是 knowledge**」的訊號，給人類與 LLM 區分用。

### 7. 寫入規則：mode 分流

| Skill | Human Mode | Agent Mode |
|-------|-----------|-----------|
| `query` 寫入 outputs/queries/ | ✅ 寫入 + 詢問是否回填為 synthesis | ✅ 寫入但**不詢問回填**（agent 不可決定回填）|
| `reflect` Stage 0 | 顯示警告給使用者 | ✅ 寫入 outputs/reflect/warnings.md（append-only）|
| `reflect` Stage 3 | 寫入 + 詢問是否新增為 question | ✅ 寫入 outputs/reflect/gap-report-{date}.md，自動將 gap 加為 QUESTIONS.md 開放問題 |
| `curator` 寫入 outputs/lint/ | ✅ 寫入 + 詢問是否修補 | ✅ 寫入但**不修補**（agent 不可自動修補）|

### 8. 回填機制（output → 主題知識）

當人類審視 `outputs/queries/<file>.md` 並認為這個答案有累積價值時，可以「**回填**」為 `主題知識/總覽/<topic>.md` 的 synthesis 頁：

```
1. 人類執行: query --backfill outputs/queries/2026-04-15-rag-vs-finetune.md
2. 主對話讀取該 query 答案
3. 建立 主題知識/總覽/RAG-vs-FineTune-綜論.md
   wiki_category: 總覽
   sources: 從原 query 的 sources_consulted 複製
   confidence: medium (回填預設)
4. 在 outputs/queries/<original>.md 的 frontmatter 加 backfilled_to: [[主題知識/總覽/...]]
5. log.md 記錄 backfill 事件
```

回填**只能由人類執行**（agent 不可宣告「這個答案值得回填」，這是認知判斷）。

## Examples

### Example 1：典型 query 流程含 outputs

```
1. 使用者: query "RAG 和 FineTune 哪個更適合我的場景？"
2. query skill 讀取 主題知識/概念/RAG.md, FineTune.md, 比較/RAG-vs-FineTune.md
3. query skill 讀取相關 source 頁
4. 合成答案
5. 寫入 outputs/queries/2026-04-15-rag-vs-finetune.md
   含 frontmatter, Question, Answer, Sources, Concept Pages, Confidence Notes
6. 顯示給使用者
7. 詢問: 「此答案的對比視角是否有累積價值？是否回填為 主題知識/總覽/RAG-vs-FineTune-綜論.md？」
8. 使用者: 「回填」
9. 主對話建立 總覽 頁
10. log.md 記 query + backfill 事件
```

### Example 2：agent mode 下的 reflect

```
1. agent: reflect
2. reflect skill 執行 Stage 0 (反向檢驗)
   發現: 主題知識/總覽/AI技術全景.md 的「Transformer 主導」結論無反證
3. agent mode → 寫入 outputs/reflect/warnings.md (append):
   ## 2026-04-20 ⚠ 回音室風險
   - concept: [[主題知識/總覽/AI技術全景]]
   - ...
4. reflect skill 執行 Stage 3 (Gap Analysis)
   發現: 5 個 isolated concept
5. 寫入 outputs/reflect/gap-report-2026-04-20.md
6. agent mode → 自動將 5 個 isolated concept 名稱加為 QUESTIONS.md 開放問題:
   - [ ] 是否需要為「Mixture-of-Experts」尋找更多 source？(opened 2026-04-20, by agent)
   - ...
7. 完成，不阻塞，agent 繼續下一個工作
```

### Example 3：curator lint 報告

```
1. 使用者: lint
2. curator 執行 9 項檢查
3. 寫入 outputs/lint/2026-04-15.md
4. 顯示摘要給使用者:
   ┌──────────────────────────────────┐
   │ Lint Report 2026-04-15           │
   │ 9 項檢查，發現 7 個違規           │
   │                                  │
   │ ⚠ 5 個 wikilink 格式違規         │
   │ ⚠ 2 個 stale concepts            │
   │                                  │
   │ 詳見 outputs/lint/2026-04-15.md  │
   │                                  │
   │ 自動修補? [是] [否]              │
   └──────────────────────────────────┘
5. 使用者: 「是」
6. curator 執行可自動修補的項目
7. 修補後再次 lint，更新報告（同一檔 append 第二段）
```

## Rationale

### 為什麼需要獨立的 outputs/ 層而非寫進 主題知識/

主題知識/ 的內容是「**累積的合成結果**」——這些是長期存活、會被多次更新的知識。outputs/ 的內容是「**單次產出**」——大多只看一次就過了，或作為審計記錄。

混在一起的問題：
- query 答案會污染 主題知識 的 graph view
- 主題知識 的 frontmatter schema 與 outputs 不同（後者有 `graph-excluded` 等欄位）
- 累積式 vs 單次式的 git diff 模式不同（前者頻繁修改，後者只 append）

獨立 outputs/ 層讓兩者各自有清楚的生命週期。

### 為什麼 outputs 內必須有 graph-excluded

實際使用 Obsidian 一段時間後，graph view 是判斷知識庫健康的重要視覺工具。如果每天的 lint 報告、每次 query 答案都成為節點，graph 會被噪音淹沒，「哪些 concept 是核心」的視覺訊號完全被破壞。

`graph-excluded: true` 是廉價的解法（一行 frontmatter）解決一個極大的痛點。

### 為什麼 reflect/warnings.md 是單一 append-only 檔

替代設計：每次 reflect 警告寫一個獨立檔（`warning-2026-04-15-001.md`）。

不採用的理由：
- 警告是低密度資訊，每次只有 1-3 條
- 多個小檔讓搜尋與 review 更繁瑣
- append-only 單檔的時間軸更容易掃描
- 與 log.md 的設計思路一致（時間軸連續累積）

### 為什麼回填只能由人類執行

回填 = 「**這個答案有長期累積價值**」的判斷。這是**認知判斷**，不是統計事實。agent 沒有「我覺得有價值」的能力，只能識別「source_count 高」「引用了多少 concept」這類事實。

如果 agent 自動回填，會造成 主題知識/總覽/ 被低品質的 query 答案污染。**人類審視是品質閘門**。

### 為什麼 lint 報告每天最多一個檔（而非每次一個）

每天一個檔的好處：
- 命名簡單（日期）
- git history 直觀（每天一個 commit）
- review 時不需翻多檔
- 與 Obsidian 的 daily note 慣例吻合

如果使用者一天執行 curator 多次，後續 lint 結果 append 到同一檔的新段落（用 `## Run 2 - 14:30` 之類的子標題）。

### 與 Karpathy 教程的對齊

Karpathy 教程的 outputs/ 設計：
- 同樣有 outputs/lint/ 子目錄
- 同樣使用 graph-excluded: true
- 同樣推薦 query 答案持久化

obsidian-vault-tool 的差異：
- 加入 `outputs/reflect/warnings.md` 這個 append-only 檔（為 agent mode 設計，Karpathy 教程沒有）
- 三個子目錄結構與 Karpathy 一致（queries / reflect / lint）
- 命名規則更嚴格（強制日期前綴）

## Cross References

- `references/governance/agent-mode.md` — agent mode 下的 outputs 寫入規則
- `references/governance/confidence-gating.md` — query 回填時的 confidence 預設值
- `references/quality/contradictions.md` — outputs/reflect/warnings.md 與 concept 頁 ## Contradictions 的區分
- `references/quality/staleness.md` — outputs/lint/<date>.md 的 staleness 區段格式
- `references/structure/index-spec.md` — outputs/ 內的檔案不寫入 index.md
- `references/structure/log-spec.md` — outputs 寫入時 log.md 應記錄事件
- v0.9.0-rc 將更新 `skills/query/commands/ask.md`、`skills/curator/SKILL.md` 加入 outputs 寫入 step
- v0.9.0-rc 將新增 `skills/reflect/commands/reflect.md` 直接寫 outputs/reflect/
