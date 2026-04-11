# Query Flow

> **status**: v0.9.0-alpha（new spec）
> **scope**: workflow — 流程定義
> **authority**: 本檔為 query skill 的權威流程定義
> **inspired by**: Karpathy LLM Wiki 教程的 QUERY 操作

## Summary

query skill 是「**讀知識庫並合成答案**」的核心操作。v0.9 版本相較於 v0.8 的主要新增：**outputs/queries/ 持久化**（答案不再消失於對話）+ **強制 Confidence Notes**（每個答案末尾必須列出引用來源的 confidence）+ **強制溯源到 source 頁**（不允許只引用 concept 頁）+ **多種輸出格式**（markdown / 表格 / Marp / matplotlib，依問題類型決定）。query 是知識庫「**讓累積產生回報**」的機制——每次 query 都讓知識更被利用。

## Core Concepts

1. **持久化**：每次 query 答案寫入 `outputs/queries/<date>-<slug>.md`
2. **強制溯源**：每個核心結論必須追溯到具體 source 頁，不允許只引用 concept
3. **Confidence Notes**：答案末尾必須列出 low / medium confidence 的引用，警示使用者
4. **多種輸出格式**：依問題類型自動選擇 markdown / 表格 / Marp slide / matplotlib chart
5. **回填機制**：高價值答案可由人類「升級」回填為 主題知識/總覽/ 的 synthesis 頁
6. **自動關閉 question**：query 後可選擇關閉對應的 open question

## Specification

### 1. query 觸發詞

| 觸發詞 | 動作 |
|-------|------|
| 直接提問（無前綴）| query |
| 「根據我的知識庫...」 | query |
| 「查一下...」 | query |
| 「比較 A 和 B」 | query（輸出格式: 表格）|
| 「整理 X 的觀點做成 slide」 | query（輸出格式: Marp）|
| `query --backfill <output-file>` | 回填 |
| `query --close <question-id>` | query 後關閉指定 question |

### 2. Query 流程主步驟

<!-- decision-id: query-flow-main-steps -->

```
Step Q0: 讀取 vault/CLAUDE.md（含 interaction_mode）
Step Q1: 解析使用者問題
  - 抽取主題關鍵字
  - 判斷問題類型 (一般 / 比較 / 演示 / 趨勢 / 清單)
  - 決定輸出格式
Step Q2: 識別相關頁面
  - 讀取 vault/index.md（v0.9 主要途徑）
  - 找到 top 3-5 相關 concept 頁
  - 對每個 concept 頁，讀取其 sources 列表的 top 3 source
Step Q3: 完整讀取 top 5-10 個 candidate 檔案
  - 包括 concept 頁與 source 頁
  - 不只讀 frontmatter，讀完整內容
Step Q4: 合成答案
  - 每個核心結論必須有 source 頁 wikilink (不允許只引用 concept)
  - 識別來源矛盾並顯式標註
  - 識別 staleness 警告 (引用 possibly_outdated 的 source)
Step Q5: 產出輸出
  - 依問題類型選擇格式 (見 Section 4)
  - 必須含 ⚠ Confidence Notes 段落
  - 必須含 sources_consulted 列表
Step Q6: 寫入 outputs/queries/<date>-<slug>.md
  - frontmatter 含完整 metadata (見 outputs-layer.md)
  - 主要內容
Step Q7: 顯示給使用者
Step Q8: 後處理 (mode 分流):
  - human: 詢問是否回填、是否關閉 question
  - agent: 不詢問，記錄事件
Step Q9: 更新 index.md (Recent Synthesis 段落) + 寫 log.md
```

### 3. Source 溯源規則

<!-- decision-id: query-source-traceability-rule -->

**規則**：每個核心結論**必須**追溯到具體 source 頁，**不允許只引用 concept 頁**。

❌ 違規：
```
RAG 是兩階段架構（[[主題知識/概念/RAG]]）
```

✅ 合法：
```
RAG 是「先 retrieval 再 generation」的兩階段架構
（[[歷史紀錄/文章/2026-04-10/01_RAG架構簡介]],
 [[歷史紀錄/文章/2026-04-15/03_RAG實戰]]）
```

理由：concept 頁是 LLM 的合成結果，可能含 LLM 自己的推論。**source 頁是事實**——使用者要能驗證「這個結論真的有原始材料支持嗎」。

實作細節：
- 答案中每個句子如果含具體 claim，必須跟一個 wikilink 到 source 頁
- 多個 source 支持同一 claim 時列出全部
- 若一個 claim 找不到 source 支持 → query skill 必須警告「此結論為合成推論，無直接 source」

### 4. 輸出格式（依問題類型）

<!-- decision-id: query-output-format-by-type -->

| 問題類型 | 偵測規則 | 輸出格式 |
|---------|---------|---------|
| 一般 | 預設 | Markdown 正文 + Confidence Notes |
| 比較 | 「比較」「vs」「和...哪個」「對比」 | Markdown **表格** + Confidence Notes |
| 演示 | 「整理成 slide」「做成幻燈片」 | **Marp** 格式（frontmatter 加 `marp: true`）|
| 趨勢 | 「變化」「演進」「歷史」+ 含時間 | Markdown + **matplotlib code block** |
| 清單 | 「列出」「有哪些」「清單」 | 結構化 **bullet list** |

#### 比較類範例

```markdown
## Comparison: RAG vs FineTune

| 維度 | RAG | FineTune |
|------|-----|----------|
| 架構 | retrieval + generation 兩階段 ([[歷史紀錄/.../1]]) | 直接訓練模型權重 ([[歷史紀錄/.../2]]) |
| 成本 | 低（無需訓練）([[歷史紀錄/.../1]]) | 高（GPU 訓練）([[歷史紀錄/.../3]]) |
| 適用場景 | 知識頻繁更新 ([[歷史紀錄/.../1]]) | 任務特化 ([[歷史紀錄/.../2]]) |

⚠ Confidence Notes:
- [[主題知識/比較/RAG-vs-FineTune]] 是 low confidence，本對比結論需要更多 source 驗證
```

#### 演示類範例

```markdown
---
marp: true
theme: default
---

# RAG 的核心思想

根據 [[歷史紀錄/.../1]]

---

## Stage 1: Retrieval

從向量資料庫檢索相關 chunks
([[歷史紀錄/.../2]])

---

## Stage 2: Generation

LLM 基於 retrieved context 生成答案
([[歷史紀錄/.../1]])

---

## ⚠ Confidence Notes

- 部分 source 為 medium confidence
- [[歷史紀錄/.../2]] 來源 > 1 年，技術細節可能過時
```

### 5. Confidence Notes 段落（強制）

<!-- decision-id: query-confidence-notes-required -->

每個 query 答案末尾**必須**有 `## ⚠ Confidence Notes` 段落，列出：

1. **Low / medium confidence 的引用**：明確警告使用者哪些結論的支持較弱
2. **Possibly outdated 的 source**：source 頁有 `possibly_outdated: true` 標記時警告
3. **Stale concept**：引用的 concept 頁的 `last_reviewed` 已超過 staleness 閾值
4. **回音室風險**：若 reflect Stage 0 曾標註此 concept 為 ⚠ 回音室，附註此事實
5. **無 source 支持的合成推論**：若答案含「合成推論」段落，明確標出

範例：

```markdown
## ⚠ Confidence Notes

- [[主題知識/概念/RAG]] 是 high confidence (5+ sources, 已人類確認)
- [[主題知識/概念/FineTune]] 是 medium confidence (3 sources, 自動升級)
- [[主題知識/比較/RAG-vs-FineTune]] 是 low confidence (1 source)
- [[歷史紀錄/文章/2024-03-15/...]] 來源 > 2 年 (possibly_outdated: true)
- 「FineTune 的成本是 RAG 的 100 倍」這個具體數字為合成推論，未在任何 source 中明確出現
```

### 6. outputs/queries/ 寫入規則

每次 query 必須寫入：

```
outputs/queries/{YYYY-MM-DD}-{slug}.md
```

slug 由 query 主題自動生成（英文小寫連字符，見 `references/taxonomy/aliases-and-wikilink.md` 的 slug 規則）。

frontmatter 範例見 `references/structure/outputs-layer.md` Section 3。

### 7. 自動關閉 question

若使用者執行 `query --close Q-005` 或 query 流程末尾使用者選擇「關閉這個問題」：

```
1. query 完成後，主對話寫入 outputs/queries/<date>-<slug>.md
2. 讀取 vault/QUESTIONS.md
3. 找到 Q-005
4. 從 ## Open 移到 ## Answered
5. 條目改為:
   - [x] Q-005: ... (opened ..., answered YYYY-MM-DD via [[outputs/queries/<date>-<slug>]])
6. log.md 記 query --close 事件
```

agent mode 下不可執行 close（見 `references/governance/agent-mode.md`）。

### 8. 回填機制

```
query --backfill outputs/queries/2026-04-22-rag-vs-finetune.md

流程:
1. 主對話讀取該 query 答案
2. 判斷主題與 wiki_category（依答案內容）
3. 建立 主題知識/{wiki_category}/{slug}.md
   - 通常是 主題知識/總覽/{slug}.md（query 答案多為 synthesis 性質）
4. frontmatter:
   - title: {從 query 提取}
   - wiki_category: 總覽 (通常)
   - confidence: medium (回填預設，不能 high)
   - sources: 從原 query 的 sources_consulted 複製
5. body: 從原 query 的 ## Answer 複製，調整為頁面格式
6. 在原 query 檔的 frontmatter 加 backfilled_to: [[主題知識/總覽/...]]
7. log.md 記 backfill 事件
8. 詢問使用者是否更新 index.md
```

回填**只能由人類執行**（agent 不可宣告答案值得回填）。

### 9. Mode 分流

| 動作 | Human Mode | Agent Mode |
|------|-----------|-----------|
| query 主流程 | 同 | 同 |
| Confidence Notes | 必加 | 必加 |
| 寫入 outputs/queries/ | 必寫 | 必寫 |
| 詢問是否回填 | ✅ | ❌ 不詢問 |
| 詢問是否關閉 question | ✅ | ❌ 不詢問 |
| 自動執行回填 | 等使用者確認 | **禁止**（agent 不可回填）|
| 自動執行 close | 等使用者確認 | **禁止**（agent 不可關閉問題）|

## Examples

### Example 1：典型一般問題（human mode）

```
1. 使用者: "RAG 是什麼？"
2. query Step Q0-Q1: 解析為一般問題
3. Step Q2: index.md 找到 [[主題知識/概念/RAG]]
4. Step Q3: 讀取 RAG.md 完整內容 + top 3 source 頁
5. Step Q4: 合成答案，每個結論附 source wikilink
6. Step Q5: 產出 markdown 正文 + Confidence Notes
7. Step Q6: 寫入 outputs/queries/2026-04-22-what-is-rag.md
8. Step Q7: 顯示給使用者
9. Step Q8 (human): 詢問:
   - 是否回填為 synthesis？
   - 是否關閉某個 open question？
10. 使用者: "都不用"
11. Step Q9: 更新 index.md Recent Synthesis + log.md
```

### Example 2：比較類問題輸出表格

```
1. 使用者: "比較 RAG 和 FineTune"
2. query 偵測「比較」關鍵字 → 輸出格式: 表格
3. 讀取 [[主題知識/概念/RAG]] + [[主題知識/概念/FineTune]] + [[主題知識/比較/RAG-vs-FineTune]]
4. 讀取對應 source 頁
5. 合成表格答案 (見 Section 4 範例)
6. 必須含 Confidence Notes
7. 寫入 outputs/queries/2026-04-22-rag-vs-finetune.md
8. 顯示使用者
```

### Example 3：演示類問題輸出 Marp

```
1. 使用者: "把 RAG 的核心思想整理成 slide"
2. query 偵測「slide」 → 輸出格式: Marp
3. 讀取相關頁
4. 合成 Marp 格式 (frontmatter marp: true)
5. 寫入 outputs/queries/2026-04-22-rag-slides.md
6. 使用者可在 Obsidian 用 Marp plugin 預覽
```

### Example 4：query 後關閉 question

```
情境: QUESTIONS.md 有 Q-005 "RAG 和 FineTune 在我的場景下哪個更適合？"

1. 使用者: "比較 RAG 和 FineTune 在 SaaS 場景"
2. query 流程跑完，產出 outputs/queries/2026-04-22-rag-vs-finetune-saas.md
3. Step Q8: query skill 偵測到答案直接回應 Q-005
   詢問使用者: "此答案似乎回應了 Q-005，是否關閉？"
4. 使用者: "是"
5. Q-005 移到 ## Answered，附 outputs 連結
6. log.md 記 query + ask --close
```

### Example 5：agent mode 下的 query

```
1. agent: query "什麼是 Transformer？"
2. Step Q0-Q7 同 human mode
3. Step Q8 (agent): 不詢問
4. 自動寫入 outputs/queries/2026-04-22-what-is-transformer.md
5. **不執行**回填、**不關閉** question
6. log.md: query [agent] | what is transformer
7. 完成，agent 繼續下一個工作
```

### Example 6：合成推論的警告

```
情境: 使用者問 "FineTune 的成本是 RAG 的多少倍？"

query 處理:
1. 在 sources 找到 RAG 與 FineTune 的成本資訊（分別來自不同 source）
2. RAG 成本資訊: $X (來源 [[歷史紀錄/.../1]])
3. FineTune 成本資訊: $Y (來源 [[歷史紀錄/.../2]])
4. **比例 Y/X 不在任何 source 中明確出現**
5. 答案:
   "根據 [[歷史紀錄/.../1]] 與 [[歷史紀錄/.../2]] 的成本資訊推算，
    FineTune 的成本約為 RAG 的 100 倍。"
6. Confidence Notes 中必須加:
   - 「100 倍」這個比例為合成推論，未在任何 source 中明確出現
```

## Rationale

### 為什麼必須溯源到 source 而非只引用 concept

concept 頁是「合成知識」——LLM 整合多個 source 後寫的版本。它可能：
- 含 LLM 自己的推論（無 source 直接支持）
- 反映過時的 source（concept 頁的 last_reviewed 落後）
- 受某個強勢 source 主導（其他相反證據被略寫）

source 頁是「**事實記錄**」——是真的有人寫過的內容。query 答案如果只引用 concept，使用者無法驗證「這個結論真的有原始材料支持嗎」。

強制 source 溯源讓 query 變成「**從事實出發的合成**」而非「從概念出發的循環引用」。

### 為什麼必須有 Confidence Notes

知識庫的 confidence 機制設計了，但如果 query 不告訴使用者「我引用的是 high 還是 low」，confidence 等於白設計。

Confidence Notes 是「**讓 confidence 機制真的影響使用者決策**」的關鍵——使用者看到「這個對比結論基於 low confidence」會自動降低信心，不會把 query 答案當絕對真理。

### 為什麼 query 答案必須持久化到 outputs/queries/

替代設計：query 答案只顯示在對話，不寫檔。

不採用的理由：
- 對話歷史會被壓縮、會被清除
- 同一個問題下次查時，前一次的成果消失
- 無法累積「我問過什麼」的軌跡
- 無法回填為 synthesis（沒有檔案怎麼回填）

持久化讓 query 變成「**累積式探索**」而非「即時諮詢」，這是 LLM Wiki 模式相對於 ChatGPT 的核心差異化。

### 為什麼 agent 不可關閉 question / 不可回填

關閉 question = 「我認為答案夠了」是認知判斷
回填 synthesis = 「這個答案值得長期保存」是價值判斷

兩者都是人類專屬。詳細理由見 `references/governance/agent-mode.md` 的「為什麼 agent 不能關閉 QUESTIONS.md 的問題」與「為什麼 agent 不能宣告答案值得回填」段落。

### 為什麼合成推論必須警告

LLM 的 query 答案常常包含「具體數字」「精確比例」「比較結論」這類超出 source 直接陳述的內容。這些是 LLM 的合成推論，但對使用者來說很難區分「source 真的這樣說」與「LLM 自己算出來的」。

強制警告合成推論（在 Confidence Notes 段落明確標註「此結論為合成推論」）讓使用者保持警覺。否則「100 倍」這種具體數字會被當成事實引用，造成「虛假精確度」（false precision）。

### 為什麼依問題類型自動選擇輸出格式

不同問題的最佳呈現形式不同：
- 「什麼是 X」適合段落散文
- 「比較 A 和 B」適合表格
- 「整理成簡報」適合 slide
- 「趨勢」適合時間軸 chart

如果一律用 markdown 段落，比較類問題的答案會難讀。自動選擇格式讓答案一次到位，不需使用者再要求 reformat。

### 為什麼回填預設 confidence: medium

回填的 query 答案是「LLM 合成 + 人類認可」的結果，但**沒有經過 ingest 階段的 source_count 累積**。直接設 high 違反 confidence-gating 規則（high 必須由 source_count 驅動）。

設 medium 是合理的折衷：
- 高於 low（這不是空檔）
- 低於 high（需要後續 ingest 補充來達到 high）
- 反映「這是回填來的，未經完整驗證」的事實

### 與 Karpathy 教程的對齊

Karpathy 教程的 QUERY 操作：
- 同樣有 outputs/queries/ 持久化（同）
- 同樣強制 Confidence Notes（同）
- 同樣強制溯源到 source（同）
- 同樣有多種輸出格式（同）
- 同樣支援回填（同）

obsidian-vault-tool 的差異：
- 加入 mode 分流（agent 不可關閉、不可回填）
- 加入「合成推論警告」（Karpathy 沒明確要求）
- index.md 為主搜尋途徑（Karpathy 用 qmd，但本 plugin v0.9 沒有）
- 自動關閉對應 question 的整合（Karpathy 是手動）

## Cross References

- `references/governance/agent-mode.md` — query 在 agent mode 下的 fallback
- `references/governance/confidence-gating.md` — Confidence Notes 對應的 confidence 三級
- `references/quality/staleness.md` — possibly_outdated 警告
- `references/quality/contradictions.md` — query 引用矛盾 source 時的標註
- `references/structure/outputs-layer.md` — outputs/queries/ 結構與 frontmatter
- `references/structure/index-spec.md` — query 透過 index.md 找到相關頁
- `references/workflow/ask-flow.md`（同 commit 新增）— query 後關閉 question 的整合
- `references/workflow/archive-flow.md`（v0.9.0-beta 新增）— archive 後的 question 自動匹配，是 query 的補充機制
- v0.9.0-rc 將更新 `skills/query/commands/ask.md` 加入 outputs/queries/ 寫入 step
