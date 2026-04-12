# Reflect：二階認知活動

定期審視知識庫，找出回音室風險、知識空白、隱性關聯。
本命令直接由主對話執行（不委派 sub-agent），依序跑 Stage 0 → Stage 1 → Stage 3。

> **v0.9.0-rc Preview**：Stage 2（深度合成）延 v1.0。
> 詳細 spec 見 `${CLAUDE_PLUGIN_ROOT}/references/workflow/reflect-flow.md`。

---

## Step 0：前置準備

### 0.1 讀取 interaction_mode

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md`，從 vault CLAUDE.md 讀取 `interaction_mode`。缺失 → 預設 `human`。

### 0.2 解析參數

從使用者指令中提取：
- `--stage N`（選填）：只跑特定 Stage
- `--topic <slug>`（選填）：對特定 concept 跑 Stage 0

無參數 → 跑完整三階段。

### 0.3 載入知識頁清單

```
Glob 工具：[vault_path]/主題知識/**/*.md
```

對每個頁面用 Read 讀取前 30 行（frontmatter），解析：
- `title`、`confidence`、`source_count`、`domain_volatility`、`last_reviewed`、`aliases`、`sources`
- 缺失 v0.9 欄位的 v0.8 舊頁 → 視為預設值：`confidence=low`、`source_count=sources 陣列長度`、`domain_volatility=medium`、`last_reviewed=updated 或 date`

存為 `wiki_pages[]`。

### 0.4 取得時間戳記

```bash
date '+%Y-%m-%d'
```

---

## Stage 0：反向檢驗

> **目的**：對既有 concept 頁的 Definition 與 synthesis 的結論，主動在已有 sources 中找反證。
> 若完全找不到反證 → 標記為「⚠ 回音室風險」。

### S0.1 決定檢驗範圍

- 有 `--topic <slug>` → 只檢驗該 concept
- 無 → 檢驗所有 `wiki_pages[]` 中 `confidence ≥ medium` 的 concept + 所有 `主題知識/總覽/*.md`

### S0.2 對每個 concept 執行兩段式反證偵測

**第一段：抽取可驗證主張**

用 Read 讀取 concept 頁完整內容，提取 `## Definition`（或正文首段）的核心主張。

> **Prompt 範本**（主對話內部自我指令）：
>
> ```
> 從以下 Definition 中抽取 1-3 個「可被反駁的具體事實主張」。
> 每個主張用一句話表述，格式為「[主題] [動詞] [具體斷言]」。
> 排除不可反駁的一般性陳述（如「X 是一種技術」）。
>
> Definition:
> [concept 頁的 Definition 段落]
>
> 輸出格式：
> 1. [主張 1]
> 2. [主張 2]
> 3. [主張 3]（若有）
> ```

**第二段：逐條找衝突證據**

對每個抽取的主張，讀取該 concept 的 `sources` 列表中每個 source 頁的 `## 總結` 段落，搜尋衝突。

> **Prompt 範本**（主對話內部自我指令）：
>
> ```
> 對以下主張，在提供的 source 摘要中尋找矛盾或不一致的證據。
>
> 主張：「[主張文字]」
>
> Source 摘要：
> === Source 1: [[歷史紀錄/.../01_xxx]] ===
> [source 頁的 ## 總結 段落]
>
> === Source 2: [[歷史紀錄/.../02_yyy]] ===
> [source 頁的 ## 總結 段落]
>
> ...
>
> 搜尋指引：
> - 找直接矛盾：source 明確主張與上述主張相反的內容
> - 找條件差異：source 認為此主張只在特定條件下成立，但 Definition 未限定條件
> - 找時間差異：source 的資訊時間點不同，可能造成結論差異
>
> 輸出格式：
> - 若找到矛盾：「⚠ 反證：[[source wikilink]] — [具體矛盾描述]」
> - 若未找到：「✓ 未找到反證」
>
> 重要：只報告有明確證據支持的矛盾，不報告「可能的」矛盾。
> 若不確定是否矛盾 → 不報告。
> ```

### S0.3 對 synthesis 頁執行同樣流程

對 `主題知識/總覽/*.md` 的 `## Thesis`（或正文首段）執行同樣的兩段式反證偵測。

### S0.4 彙整結果 + 寫入 outputs

```markdown
（append 到 outputs/reflect/warnings.md）

## [YYYY-MM-DD] ⚠ 反向檢驗結果

### Concepts 檢驗
- ✓ [[主題知識/概念/RAG]] — 找到 2 個反證 source
- ⚠ [[主題知識/概念/Transformer]] — 0 個反證，回音室風險
- ✓ [[主題知識/概念/Attention]] — 找到 1 個反證 source

### Synthesis 檢驗
- ⚠ [[主題知識/總覽/AI技術全景]] — 主結論未找到反證
  - 建議: 主動尋找質疑 Transformer 主導性的來源
```

使用 Write 工具 append（若 warnings.md 不存在則建立）。

### S0.5 Mode 分流

| Mode | 行為 |
|------|------|
| human | 在對話中顯示結果，詢問「是否要對回音室風險的 concept 主動找 source？」|
| agent | 寫入 outputs/reflect/warnings.md，不阻塞 |

---

## Stage 1：輕量模式掃描

> **目的**：跨 concept 找隱性關聯、缺失中介概念。
> v0.9 只在候選集 ≤ 10 時跑全掃描，> 10 時樣本掃描。

### S1.1 篩選候選集

從 `wiki_pages[]` 過濾：
- `confidence ≥ medium`
- `last_reviewed > 30 天前` OR 從未被 reflect 掃描過
- 結果集 ≤ 10 → 全掃描；> 10 → 隨機選 10 個（加標示「樣本掃描」）

### S1.2 隱性關聯偵測

對候選集中每對 concept（C(N,2) 對），讀取兩邊的 sources 列表，檢查是否有共現的 source 但雙方正文無 wikilink 引用。

> **Prompt 範本**（主對話內部自我指令）：
>
> ```
> 對以下兩個概念，判斷是否存在「尚未被明確記錄」的關聯。
>
> Concept A: [[主題知識/概念/RAG]]
> Definition A: [A 的 Definition 段落]
> Sources A: [[s1]], [[s2]], [[s3]]
>
> Concept B: [[主題知識/概念/向量資料庫]]
> Definition B: [B 的 Definition 段落]
> Sources B: [[s2]], [[s4]], [[s5]]
>
> 共現 source: [[s2]]
>
> 判斷標準：
> 1. A 和 B 是否在共現 source 中被一起討論？
> 2. A 的正文是否已有 [[B]] 的 wikilink？（若有 → 關聯已記錄，跳過）
> 3. A 和 B 之間是否有「技術依賴」「互補」「對立」等實質關聯？
>
> 輸出格式：
> - 若有隱性關聯：「⚠ 隱性關聯：[A] 與 [B] — [關聯描述]（建議在 A.md 加 [[B]] 連結）」
> - 若無明確關聯：「✓ 無需記錄」
>
> 重要：只報告**高信心**的關聯。如果不確定 → 不報告。
> 不報告「顯而易見」的關聯（如 LLM 與 AI 都是 AI 領域不需要特別連結）。
> ```

### S1.3 缺失中介概念偵測

掃描候選 source 頁正文，用 Grep 找出「在 ≥ 3 個 source 中出現但無對應 concept 頁且不在任何 aliases 中」的術語。

> **Prompt 範本**：
>
> ```
> 以下術語在多個 source 中被提及但尚無 concept 頁：
>
> - "Chain-of-Thought"：出現在 [[s1]], [[s3]], [[s5]]（3 個 source）
> - "RLHF"：出現在 [[s2]], [[s4]], [[s6]], [[s7]]（4 個 source）
>
> 對每個術語判斷：是否值得建立獨立的 concept 頁？
>
> 判斷標準：
> - 是否有足夠獨立性（不只是某個大概念的子步驟）
> - 是否在多個不同領域的 source 中被提及
> - 是否有自己的 Definition 可寫
>
> 輸出格式：
> - 建議建立：「⭐ 建議建立：[術語] — [理由]」
> - 不需要：跳過
> ```

### S1.4 aliases 重疊偵測

對候選集中的 concept 頁，比對 aliases 陣列。若兩個 concept 的 aliases 有 ≥ 2 個重疊 → 標記為「概念合併候選」。

此步驟為純統計比對，不需 LLM prompt。

### S1.5 彙整結果 + 寫入 outputs

```bash
# 建立 pattern report（Write 工具）
# 路徑：outputs/reflect/pattern-[YYYY-MM-DD].md
```

frontmatter：
```yaml
---
type: output
output_kind: reflect-pattern-full | reflect-pattern-sample
date: [YYYY-MM-DD]
graph-excluded: true
generator: reflect
interaction_mode: [human|agent]
candidates_total: [N]
candidates_scanned: [M]
---
```

### S1.6 Mode 分流

| Mode | 行為 |
|------|------|
| human | 顯示結果，詢問「是否要對隱性關聯建立 wikilink？缺失概念是否新增為 question？」|
| agent | 寫入 outputs/reflect/pattern-{date}.md。缺失中介概念自動新增為 QUESTIONS.md 開放問題（標記 `by agent, source: reflect Stage 1`）|

---

## Stage 2：深度合成（v1.0 延後）

```markdown
## Stage 2 — Skipped (v1.0 will implement)

> v0.9.0-rc 不實作 Stage 2 深度合成。
> 預定由 synthesis-writer agent 在 v1.0 實作。
> 詳見 agents/synthesis-writer.md（v1.0 預留骨架）。
```

---

## Stage 3：Gap Analysis

> **目的**：找出知識庫的「沒有被覆蓋到的領域」。
> 三個子任務均為純統計/比對，不需要複雜 LLM prompt。

### S3.1 Isolated Concepts

從 `wiki_pages[]` 過濾：
- `source_count == 1`（或缺 v0.9 欄位時 `sources 陣列長度 == 1`）
- `date`（建立日期）> 30 天前
- 用 Grep 確認沒有從其他 concept 頁的 wikilink 指向此頁

列入 gap-report。

### S3.2 Implicit Concepts

從 `wiki_pages[]` 中所有 concept 的 sources 列表，讀取每個 source 頁的正文。
用 LLM 或 Grep 找出「在 ≥ 3 個 source 中提及但無對應 concept 頁」的術語。

> 注意：此步驟與 Stage 1 的「缺失中介概念」重疊。若 Stage 1 已執行，直接使用 S1.3 的結果，不重複掃描。

### S3.3 Coverage Gaps

讀取 `主題知識/總覽/*.md`（若有），提取子領域清單。
比對 `主題知識/概念/` 下的實際 concept 頁數。
子領域對應的 concept 頁數 < 2 → 列入 gap-report。

若 `主題知識/總覽/` 為空 → 跳過此步驟（無基準可比對）。

### S3.4 彙整結果 + 寫入 outputs

```bash
# 建立 gap report（Write 工具）
# 路徑：outputs/reflect/gap-report-[YYYY-MM-DD].md
```

frontmatter：
```yaml
---
type: output
output_kind: reflect-gap
date: [YYYY-MM-DD]
graph-excluded: true
generator: reflect
interaction_mode: [human|agent]
total_concepts_scanned: [N]
isolated_concepts: [M]
implicit_concepts: [K]
---
```

### S3.5 Mode 分流

| Mode | 行為 |
|------|------|
| human | 顯示結果，詢問「是否要將 gap 新增為 question？」|
| agent | 自動將 coverage gaps 新增為 QUESTIONS.md 開放問題（標記 `by agent, source: reflect Stage 3`）|

---

## Step 後處理

### 追加 log.md

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] reflect [agent]? | manual\nmode: reflect\ninteraction_mode: [human|agent]\ntouched_specs: [reflect-flow, contradictions, staleness]\nfail_reason: none\nmanual_fix: no\n- Stage 0: [N] concepts 檢驗，[M] 回音室風險\n- Stage 1: [N] candidates 掃描，[M] 隱性關聯，[K] 缺失概念\n- Stage 2: Skipped (v1.0)\n- Stage 3: [N] isolated，[M] implicit，[K] coverage gaps\n- outputs: [[outputs/reflect/warnings]], [[outputs/reflect/pattern-{date}]], [[outputs/reflect/gap-report-{date}]]"
```

### 完成通知

```
┌──────────────────────────────────────────┐
│ Reflect Preview 完成                     │
│                                          │
│ Stage 0: [N] 回音室風險, [M] 反證找到    │
│ Stage 1: [N] 隱性關聯, [M] 缺失概念     │
│ Stage 2: 跳過 (v1.0)                     │
│ Stage 3: [N] isolated, [M] implicit      │
│                                          │
│ 詳見:                                    │
│   outputs/reflect/warnings.md            │
│   outputs/reflect/pattern-{date}.md      │
│   outputs/reflect/gap-report-{date}.md   │
│                                          │
│ > ⚠ v0.9 Preview                        │
│ > Stage 0/1/3 實作，Stage 2 延 v1.0     │
└──────────────────────────────────────────┘
```

### Preview 標示

所有 outputs/reflect/ 檔案頂端必須加：

```markdown
> **⚠ v0.9 Preview**
> 本報告為 v0.9.0-rc 輕量版：Stage 0 + Stage 1（候選集 ≤ 10）+ Stage 3。
> Stage 2 深度合成延 v1.0。Stage 1 若為樣本掃描則未涵蓋全部候選。
```
