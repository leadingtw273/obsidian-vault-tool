# Ask：Wiki 查詢與回填

從 Vault 的 Wiki 層（主題知識/）讀取相關主題頁，針對問題產出綜合回答，
**寫入 outputs/queries/ 持久化**，並可選擇將答案回填至 主題知識/總覽/。

> v0.9.0-beta 升級：
> - 每次 query 必寫入 `outputs/queries/<date>-<slug>.md`（不再消失於對話）
> - 答案末尾強制 `## ⚠ Confidence Notes` 段落
> - 強制溯源到 source 頁（不允許只引用 concept 頁）
> - 整合 QUESTIONS.md 自動關閉機制
> - interaction_mode 分流（agent mode 不詢問回填）
> 詳見 `references/workflow/query-flow.md`。

---

## Step 0：取得使用者問題 + 讀取 interaction_mode

### 0.1 讀取 interaction_mode（v0.9.0-beta 新增）

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md` 規範，從 vault CLAUDE.md 讀取 `interaction_mode` 欄位。若欄位缺失 → 預設 `human`。

### 0.2 取得使用者問題

從觸發本次 skill 的訊息中提取問題本體。

**問題明確**（包含明確主題或關鍵詞）：直接進入 Step 1。

**問題不明確**（如使用者僅說「查一下」、「wiki 裡有什麼」）：向使用者簡短確認：

```
您想查詢的主題是？（例：「LLM Wiki 的核心概念是什麼？」「Claude Code 的主要功能？」）
```

等待使用者回覆後，以使用者回覆的內容作為本次問題，繼續 Step 1。

**問題記錄**：將最終確認的問題保存為 `[問題本體]`，供後續步驟引用。

---

## Step 1：讀取 index.md 找候選頁

```
Read [vault_path]/index.md
```

從 index.md 的條目中找出與問題相關的候選主題頁：

- 掃描每個分類區塊（實體/概念/比較/總覽）內的條目
- 依條目的**標題**與**一行摘要**判斷相關性
- 判斷標準：標題或摘要包含問題的核心詞彙、同義詞、相關概念
- 取最相關的 5-10 個候選頁（依問題範圍適度調整數量）

**記錄**：將候選頁清單保存為 `[候選頁列表]`（含完整路徑）。

**Fallback**：若 index.md 不存在或為空，跳至 Step 2 的全文搜尋模式（不做 index 篩選，直接以關鍵詞搜尋）。

---

## Step 2：obsidian search 補齊漏網

使用 obsidian search 作為 index.md 的補強，捕捉摘要未能反映的頁面：

```bash
obsidian search vault=[vault_name] query="[問題關鍵詞]"
```

- 從問題中提取 1-3 個核心關鍵詞執行搜尋（若問題含多個概念，可分多次搜尋）
- 從搜尋結果中篩選 `主題知識/` 路徑下的頁面（排除 `歷史紀錄/` 與 `raw/`）
- 補充 Step 1 可能漏掉的頁面

**去重**：合併 Step 1 與 Step 2 的候選清單，去除重複路徑，更新 `[候選頁列表]`。

**總數上限**：候選頁數 ≤ 10。若超過，優先保留：
1. Step 1 中 index 摘要相關性高的頁面
2. Step 2 中搜尋排名靠前的頁面

---

## Step 3：讀取相關頁正文

對 `[候選頁列表]` 中的每個候選頁，使用 Read 工具讀取完整內容。

**讀取限制**：
- 只讀 `主題知識/` 下的檔案，不讀 `歷史紀錄/` 與 `raw/`
- 單次 skill 執行最多讀取 10 個頁面

**若頁面不存在**（路徑有效但檔案遺失）：略過該頁面，繼續讀取其他頁面；在 Step 9 完成通知中標記為遺失。

**記錄**：將成功讀取的頁面標題清單保存為 `[已讀頁面]`，供後續步驟引用。

---

## Step 4：綜合回答（含強制 Confidence Notes 與 source 溯源）

> **v0.9.0-beta 強化**（依 `references/workflow/query-flow.md`）：
> 1. **強制溯源到 source 頁**：每個核心結論必須有 `[[歷史紀錄/...]]` source wikilink
>    （不允許只引用 concept 頁，concept 是合成知識，source 才是事實）
> 2. **強制 Confidence Notes 段落**：答案末尾必須列出 low/medium confidence
>    的引用、possibly_outdated 來源、合成推論警告
> 3. **來源嚴格性**：所有事實主張必須源自 Step 3 讀取的頁面內容

基於讀取的頁面內容，產出針對 `[問題本體]` 的綜合回答。

**回答結構**：

1. **直接答案**（2-4 段）
   - 針對問題的具體回答
   - 整合多個來源頁面的重點
   - 每個事實後加上 source wikilink 引用（見下方溯源規則）

2. **Source 溯源規則**（v0.9.0-beta 強制）
   - ❌ 違規：`RAG 是兩階段架構（[[主題知識/概念/RAG]]）`
   - ✅ 合法：`RAG 是兩階段架構（[[歷史紀錄/文章/2026-04-10/01_RAG架構簡介]], [[歷史紀錄/文章/2026-04-15/03_RAG實戰]]）`
   - 多個 source 支持同一 claim 時列出全部
   - 若一個 claim 找不到 source 支持 → 必須在 Confidence Notes 標註「此結論為合成推論」

3. **延伸閱讀**（選填）
   - 若讀取的頁面中提到相關主題，列出 2-3 個建議延伸閱讀的 wikilink
   - 格式：`延伸閱讀：[[主題A]]、[[主題B]]`

4. **強制段落 `## ⚠ Confidence Notes`**（v0.9.0-beta 必填，依 query-flow.md）

   答案末尾必須有此段落，列出：
   - **Low / medium confidence 引用**：引用的 concept 頁的 confidence 等級
   - **Possibly outdated source**：source 頁有 `possibly_outdated: true` 標記時警告
   - **Stale concept**：引用的 concept 頁的 `last_reviewed` 已超過 staleness 閾值
   - **合成推論**：答案中含「具體數字」「精確比例」這類超出 source 直接陳述的內容
   - **回音室風險**：若 reflect Stage 0 曾標註此 concept，附註此事實

   範例：
   ```markdown
   ## ⚠ Confidence Notes

   - [[主題知識/概念/RAG]] 是 high confidence (5+ sources, 已人類確認)
   - [[主題知識/概念/FineTune]] 是 medium confidence (3 sources, 自動升級)
   - [[歷史紀錄/文章/2024-03-15/...]] 來源 > 2 年 (possibly_outdated: true)
   - 「FineTune 的成本是 RAG 的 100 倍」這個具體數字為合成推論，未在任何 source 中明確出現
   ```

**資訊不足的處理**：

若 Wiki 中的資訊不足以回答問題，明確說明：

```
Wiki 中未涵蓋 [X 面向]。以下內容為一般知識補充（非 Vault 歸檔內容）：
[補充說明]
```

並在 Confidence Notes 中標註「本回答含 Wiki 外的一般知識補充」。

**記錄**：將完整回答（含 Confidence Notes 段落）暫存為 `[綜合回答]`，供 Step 4.5 寫入 outputs/ 與 Step 6 的回填使用。

---

## Step 4.5：寫入 outputs/queries/（v0.9.0-beta 必執行）

> 依 `references/structure/outputs-layer.md` 與 `references/workflow/query-flow.md`，
> **每次 query 都必須寫入 outputs/queries/**，不論後續是否回填為主題頁。
> outputs/queries/ 是答案的副本（永久），主題知識/總覽/ 是升級為主題的合成
> （需人類認可後才寫，由 Step 6 處理）。

### 4.5.1 生成 slug

從問題萃取英文小寫連字符 slug（依 `references/taxonomy/aliases-and-wikilink.md`）：
- 「RAG 和 FineTune 哪個更適合？」 → `rag-vs-finetune`
- 「什麼是 Transformer？」 → `what-is-transformer`
- 「比較 Claude 和 GPT」 → `claude-vs-gpt`

### 4.5.2 寫入 outputs/queries/

```bash
obsidian create vault=[vault_name] path="outputs/queries/[YYYY-MM-DD]-[slug].md" content="---\ntype: output\noutput_kind: query\ndate: [YYYY-MM-DD]\ngraph-excluded: true\ngenerator: query\ninteraction_mode: [human|agent]\nquestion: \"[問題本體]\"\nsources_consulted: [N]\nconcept_pages_consulted: [M]\n---\n\n## Question\n\n[問題本體]\n\n## Answer\n\n[Step 4 的綜合回答正文，含 source wikilinks]\n\n## Sources Consulted\n\n- [[歷史紀錄/.../...]] (confidence: ...)\n...\n\n## Concept Pages Consulted\n\n- [[主題知識/.../...]] (confidence: ...)\n...\n\n## ⚠ Confidence Notes\n\n[Step 4 的 Confidence Notes 段落內容]"
```

若答案超長（> 16KB），先 create 含 frontmatter + Question + Answer 前段，再分段 append。

### 4.5.3 暫存 outputs 路徑

將寫入的 outputs 路徑存為 `[outputs_query_path]`，供後續 Step 6.5（關閉 question）與 Step 7（log）使用。

---

## Step 5：詢問使用者是否回填 Wiki + 是否關閉 question

### 5.1 Mode 分流

| Mode | 行為 |
|------|------|
| `human` | 執行 5.2 詢問 |
| `agent` | **不詢問**，跳至 Step 7（agent 不可決定回填或關閉 question）|

### 5.2 詢問回填與 question 關閉（僅 human mode）

在回答末尾主動詢問：

```
---
✓ 答案已寫入 outputs/queries/[YYYY-MM-DD]-[slug].md

接下來：

1. 是否將此答案回填為主題頁？
   1a. 是 → 寫入 主題知識/總覽/[標題].md（新建或 upsert）
   1b. 否 → 只保留 outputs/queries/，不升級為主題

2. 此答案是否回應了某個開放問題（QUESTIONS.md）？
   2a. 是 → 請輸入 question ID（如 Q-005），將標記為 answered 並連結到 outputs
   2b. 否 → 跳過

請依次回覆。
```

等待使用者回覆：
- 第 1 題: 1a → 繼續 Step 6 回填; 1b → 跳過 Step 6（`[回填狀態]` 設為「未回填」）
- 第 2 題: 2a → 繼續 Step 6.5 關閉 question; 2b → 跳過 Step 6.5

---

## Step 6：若回填，呼叫 wiki-writer

> **注意**：本步驟由主對話以 Agent tool 委派，`subagent_type: "obsidian-vault-tool:wiki-writer"`。

從問題萃取總覽標題（簡潔、描述性，20 字以內），例：
- 問題「LLM Wiki 的核心概念是什麼？」→ 標題「LLM Wiki 核心概念」
- 問題「Claude Code 有哪些主要功能？」→ 標題「Claude Code 功能總覽」

**Prompt**：

```
**主題**：[從問題萃取的總覽標題]
**來源記錄路徑**：（無，query 模式）
**來源記錄檔名**：（無，query 模式）
**原文內容**：
[Step 4 綜合產出的完整回答，含 wikilink 引用]

**來源類型**：query
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]

**額外指示**：
- 本次為 query 模式回填，wiki_category 強制為「總覽」
- 路徑：主題知識/總覽/[標題].md
- sources 陣列填入本次參考的主題頁 wikilink：[[主題A]], [[主題B]], ...（注意：需以雙引號包覆，如 "[[主題A]]"）
- Step 1 取得原文時：使用傳入的「原文內容」（無來源記錄路徑，即 knowledge-only 模式）
```

等待 agent 輸出並解析寫入結果，取得：
- `[回填路徑]`：寫入的完整路徑（如 `主題知識/總覽/LLM Wiki 核心概念.md`）
- `[寫入模式]`：新建 / merge

**驗證**：Read `[vault_path]/[回填路徑]` 前 20 行，確認：
1. 第 1 行為 `---`
2. 存在第二個 `---`
3. `wiki_category:` 值為 `總覽`
4. `sources:` 陣列中每個 wikilink 被雙引號包覆

若驗證失敗，重新呼叫 wiki-writer（最多 1 次重試），重試前宣告：
```
[回填驗證重試 1/1] 失敗項目：[具體項目]
```

**記錄**：將 `[回填狀態]` 設為 `已寫入 [[主題知識/總覽/[標題]]]`。

回填完成後，在原 `[outputs_query_path]` 的 frontmatter 加入 `backfilled_to: "[[主題知識/總覽/[標題]]]"` 欄位（用 eval + processFrontMatter）：

```bash
obsidian eval vault=[vault_name] code="app.fileManager.processFrontMatter(app.vault.getAbstractFileByPath('[outputs_query_path]'), fm => { fm.backfilled_to = '[[主題知識/總覽/[標題]]]'; })"
```

---

## Step 6.5：若使用者選擇關閉 question（v0.9.0-beta 新增）

> 依 `references/workflow/ask-flow.md` 的「關閉 question」流程。
> **只有 human mode 可執行**（agent 不可關閉問題）。

### 6.5.1 讀取 QUESTIONS.md

用 Read 工具讀取 `[vault_path]/QUESTIONS.md`，解析 ## Open 段落找到目標 Q-NNN。

若 question ID 不存在 → 提示使用者並跳過：
```
⚠ Q-005 不在 QUESTIONS.md 的 Open 段落中（可能已被關閉或 ID 錯誤）
跳過關閉動作。
```

### 6.5.2 移到 ## Answered 段落

由於 obsidian CLI 沒有「移動段落」命令，這個操作需要：
1. Read 整檔
2. 用 Edit 工具刪除 ## Open 段落中的 Q-NNN 條目
3. 用 Edit 工具在 ## Answered 段落 append 新條目，格式：
   ```
   - [x] Q-005: [問題文字] (opened YYYY-MM-DD, answered YYYY-MM-DD via [[outputs/queries/[date]-[slug]]])
   ```
4. 更新 frontmatter 的 `last_updated` 為今日

### 6.5.3 記錄

`[question_closed]` 設為 `Q-005 → [[outputs/queries/...]]`，供 Step 7 log 使用。

---

## Step 7：追加 log.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/log-spec.md` 了解格式。

**取得時間戳記**：

```bash
date '+%Y-%m-%d %H:%M'
```

**v0.9.0-beta 條目格式**：依 `interaction_mode` 決定標題後綴 + 加入結構化欄位。

```
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] query [agent]? | [問題摘要]\nmode: query\ninteraction_mode: [human|agent]\ntouched_specs: [confidence-gating, query-flow]\nfail_reason: none\nmanual_fix: no\n- 讀取頁面：[[主題A]], [[主題B]], ...\n- outputs: [[outputs/queries/[date]-[slug]]]\n- backfilled: [未回填 / [[主題知識/總覽/[標題]]]]\n- question_closed: [無 / Q-005]"
```

> v0.9.0-beta 結構化條目範例：
>
> ```markdown
> ## [2026-04-15 14:32] query | RAG 和 FineTune 哪個更適合？
> mode: query
> interaction_mode: human
> touched_specs: [confidence-gating, query-flow]
> fail_reason: none
> manual_fix: no
> - 讀取頁面：[[主題知識/概念/RAG]], [[主題知識/概念/FineTune]], [[主題知識/比較/RAG-vs-FineTune]]
> - outputs: [[outputs/queries/2026-04-15-rag-vs-finetune]]
> - backfilled: [[主題知識/總覽/RAG-vs-FineTune-綜論]]
> - question_closed: Q-005
> ```

> 注意：`content=` 中的 `[[` 和 `]]` 無需跳脫，但 `"` 需以 `\"` 跳脫。實際執行時將佔位符替換為真實內容。

---

## Step 8：若回填，更新 index.md

> **觸發條件**：`[回填狀態]` 為已寫入，且 Step 6 有實際寫入（新建或 merge）總覽頁。

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/index-spec.md` 了解條目格式。

使用 obsidian CLI append 追加一行條目（index.md 為 append-only，由 curator 定期清理去重）：

- **新建頁**：
  ```
  obsidian append vault=[vault_name] path="index.md" content="\n[YYYY-MM-DD] [[主題知識/總覽/[標題]|[標題]]] — [一行摘要（50 字以內）]（sources: N）[new]"
  ```
  摘要從 `[綜合回答]` 首段萃取；`N` 為本次參考頁面數量。

- **upsert 既有頁**：
  ```
  obsidian append vault=[vault_name] path="index.md" content="\n[YYYY-MM-DD] [[主題知識/總覽/[標題]|[標題]]] — [一行摘要（50 字以內）]（sources: N）[updated]"
  ```

> 注意：index.md 採 append-only 語意，同主題可能出現多條記錄，由 curator skill 定期清理去重。index.md 由主對話串行更新，不委派 sub-agent，避免並行寫入衝突。

---

## Step 9：完成通知

```
查詢完成。

問題：[問題本體]
讀取頁面：[N] 個
- [[主題A]]
- [[主題B]]
...（依實際讀取頁面列出）

---
[Step 4 的綜合回答再呈現一次，供使用者複製或檢閱]
---

回填狀態：
- [未回填 / 已寫入 [[主題知識/總覽/[標題]]]（[新建/merge]）]

log.md：已追加 1 個 query 條目
index.md：[未更新 / 已更新（新增 1 個總覽條目 / 更新既有條目）]
```

**若有遺失頁面**（Step 3 中路徑有效但檔案不存在）：在通知末尾附加：

```
⚠️ 以下 index 條目指向不存在的頁面（建議執行 curator 修補）：
- [[遺失頁面路徑]]
```

---

## 注意事項

1. Step 4 的「來源嚴格性」不是在 LLM 推斷時完全禁止使用訓練知識，而是要求**所有事實主張都有 wiki 頁面作為引用依據**。當 wiki 資訊不足時，須明確標記「以下為一般知識補充」，不允許隱性混入訓練知識。
2. Step 6 傳入 wiki-writer 的 prompt 中，需明確指出「Step 1 取得原文時：使用傳入的原文內容」，因為 wiki-writer 的 Step 1 有兩個分支，此為 knowledge-only 模式（無來源記錄路徑）。
3. Step 7 與 Step 8 使用 `obsidian append`（管道 1）。content= 超過 16KB 需分段 append，詳見 `references/cli-usage.md`。
4. 主對話負責 Step 0-5、7、8、9；只有 Step 6 委派 wiki-writer agent。
