# Full Lint：Wiki 健康檢查

掃描 `主題知識/` 下所有筆記，執行 6 項結構與內容檢查，輸出修補建議報告，並追加 `log.md`。

---

## Step 1：載入所有主題知識頁的 frontmatter

使用 Glob 工具取得所有主題頁清單：

```
Glob 工具：[vault_path]/主題知識/**/*.md
```

對每個找到的檔案：
1. 使用 Read 工具讀取前 25 行（取得 frontmatter）
2. 解析 frontmatter，提取以下欄位：
   - `title`（主題標題，若缺失則以檔名作為替代）
   - `date`（首次建立日期）
   - `updated`（最後 upsert 日期）
   - `tags`（標籤陣列）
   - `aliases`（別名陣列，可能不存在）
   - `sources`（來源陣列）
   - `wiki_category`（實體 / 概念 / 比較 / 總覽）
3. 記錄該檔案相對於 `vault_path` 的路徑（格式：`主題知識/[類別]/[檔名].md`）

將所有頁面資訊彙整為 `pages[]` 資料結構，於主對話內部記憶儲存。

**若 `pages[]` 為空**（Glob 找不到任何 `.md` 檔案）：

```
Wiki 為空，主題知識/ 下尚無任何頁面，無需 lint。
```

輸出以上訊息後終止。

---

## Step 2：執行 6 項檢查

對 `pages[]` 依序執行以下 6 項檢查。所有檢查**均由主對話執行**，不委派 sub-agent。

初始化以下儲存結構（主對話內部記憶）：
- `orphans[]`：孤兒頁面路徑清單
- `missing_xref[]`：缺失交叉引用，格式 `(page_path, mentioned_topic, suggested_wikilink)`
- `stale[]`：可能過期的頁面，格式 `(page_path, days_since_updated)`
- `conflicts[]`：含未解決矛盾的頁面路徑清單
- `missing_concepts[]`：建議新建概念頁，格式 `(source_page, suggested_new_topic)`
- `index_missing[]`：index 遺漏的頁面路徑
- `index_stale[]`：index 過期（檔案已刪除）的條目
- `index_mismatch[]`：index 分類不一致的條目，格式 `(index_entry, actual_directory, index_category)`

---

### 2a. 孤兒頁面檢測

**定義**：`主題知識/` 與 `歷史紀錄/` 下，完全沒有任何其他頁面以 wikilink 引用的主題頁。

**執行流程**：

對 `pages[]` 中的每個頁面（標題為 `T`）：

```
Grep 工具：
  pattern: \[\[.*T.*\]\]
  path: [vault_path]
  glob: **/*.md
  output_mode: files_with_matches
```

（採用正則搜尋，涵蓋 `[[T]]`、`[[主題知識/實體/T|T]]` 等各種形式）

從結果中排除本頁自身的路徑。若排除後結果為空 → 該頁為孤兒頁。

**注意事項**：
- 同時搜尋 `aliases` 中的別名（若存在），只要有任何形式的引用即不計為孤兒
- index.md 中的引用**不算**有效引用（index.md 是目錄，非語意連結）

**記錄**：將孤兒頁路徑存入 `orphans[]`。

---

### 2b. 缺失交叉引用檢測

**定義**：某頁正文提到另一個存在的主題標題（或其 aliases），但該位置並未包在 `[[...]]` 中。

**執行流程**：

1. 建立「所有主題標題 + aliases」完整清單（從 `pages[]` 取出）
2. 對 `pages[]` 中的每個頁面：
   a. 使用 Read 工具讀取完整內容（含正文）
   b. 去除 frontmatter 區塊（第一對 `---` 之間的內容）
   c. 對正文的每一行：
      - 若該行為 code block 圍欄（`` ``` `` 或 `~~~` 開始/結束）→ 追蹤進入/離開 code block 狀態，code block 內略過
      - 若該行以 `#` 開頭（標題行）→ 該行仍需檢查（標題也可提到主題）
      - 對清單中每個「其他主題標題 T」做字串比對（排除本頁自身標題與 aliases）：
        - 若 T 出現在該行某位置，且**該位置前後不在 `[[...]]` 內** → 標記為缺失交叉引用
   d. 建議 wikilink 格式：`[[主題知識/[wiki_category]/T|T]]`

**判定「不在 wikilink 內」的方法**：
- 對該行做字串掃描，逐字判斷 T 出現時是否被 `[[` ... `]]` 包圍
- 若該行已有 `[[T]]` 或 `[[路徑/T|T]]` 等形式，不重複標記

**忽略範圍**：
- frontmatter 區塊內
- code block 圍欄內（`` ``` `` 或 `~~~` 之間）
- HTML 注釋 `<!-- ... -->` 內

**記錄**：將命中結果存入 `missing_xref[]`，格式 `(page_path, mentioned_topic, suggested_wikilink)`。每個 (page, topic) 組合只記錄一次（不重複計算同頁多次提到）。

---

### 2c. 過期 updated 檢測

**定義**：`updated` 欄位距今超過 90 天的頁面（lint 只標記，不自動判斷是否真的「過期」，由使用者決定）。

**執行流程**：

對 `pages[]` 中的每個頁面：
1. 取出 `updated` 欄位（若缺失，改用 `date` 欄位；若兩者皆缺失，標記距今為「未知」）
2. 計算距今天數：

```bash
# 計算天數差（以今日日期為基準）
today=$(date '+%Y-%m-%d')
# 對每個頁面的 updated 值計算差值
```

3. 若距今 > 90 天（或日期欄位缺失）→ 標記為「可能過期」

**記錄**：將命中頁面存入 `stale[]`，格式 `(page_path, days_since_updated)`。日期缺失者記為 `(page_path, "日期未知")`。

---

### 2d. 未解決矛盾檢測

**定義**：頁面正文中含有 `> [!warning]` callout，且內容包含「矛盾」相關關鍵字（由 wiki-writer 在偵測矛盾時寫入）。

**執行流程**：

```
Grep 工具：
  pattern: > \[!warning\]
  path: [vault_path]/主題知識
  glob: **/*.md
  output_mode: files_with_matches
```

對每個命中的頁面，再用 Grep 確認 `[!warning]` 區塊的數量：

```
Grep 工具：
  pattern: > \[!warning\]
  path: [命中頁面路徑]
  output_mode: count
```

**記錄**：將命中頁面存入 `conflicts[]`，格式 `(page_path, warning_count)`。

---

### 2e. 缺漏的概念頁檢測

**定義**：某頁正文中提到的專有名詞（術語、工具名、框架名），在 `主題知識/` 下找不到對應的主題頁，且該概念值得建頁。

**執行流程**：

1. 建立「所有主題標題 + aliases」完整清單（從 `pages[]` 取出，同 2b）
2. 對 `pages[]` 中的每個頁面，使用 LLM 判斷力萃取正文中出現的**重要專有名詞**：
   - 符合以下特徵者納入候選：技術術語、工具名稱、框架名稱、人名（對 AI/技術領域有意義者）、組織名稱
   - 排除：一般性詞彙（如「方法」、「概念」、「系統」）、已在 wikilink 中的詞彙
3. 對每個候選專有名詞 N：
   - 檢查 `pages[]` 中是否有精確標題匹配（含 aliases）
   - 若無 → 進一步由 LLM 判斷「該概念是否值得建立專屬主題頁」：
     - **值得建頁的條件**：概念具體且可解釋、預期會在多個來源中出現、非過度細粒度的子概念
     - **不建頁的情況**：過於泛用的詞彙、僅在單一頁面偶爾提及的邊緣概念

4. 值得建頁者記錄入 `missing_concepts[]`

**注意**：本項為**建議性質**，由 LLM 主觀判斷，可能有誤報。報告中明確標注「建議」而非「必須」。

**記錄**：存入 `missing_concepts[]`，格式 `(source_page, suggested_new_topic)`。同一個缺漏概念若在多頁出現，合併為一筆，但記錄所有來源頁面。

---

### 2f. index.md 與實際檔案對照

**執行流程**：

1. 使用 Read 工具讀取 `[vault_path]/index.md` 完整內容
2. 解析 index.md 中的所有條目：
   - 以 `[` 開頭且包含 `[[主題知識/` 的行為條目行
   - 條目格式：`[YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [摘要]（sources: N）[new|updated]`
   - 從 wikilink 中提取完整路徑（如 `主題知識/實體/Claude Code`）
   - 從路徑的第二層提取 wiki_category（如 `實體`）
   - 將所有條目收集為 `index_entries[]`

3. 比對 `pages[]` 與 `index_entries[]`：

   **a. index 遺漏**（頁面存在但 index 未列出）：
   - 對 `pages[]` 中每個頁面路徑，檢查是否出現在 `index_entries[]` 中
   - 若無 → 存入 `index_missing[]`

   **b. index 過期**（index 有條目但檔案已刪除）：
   - 對 `index_entries[]` 中每個路徑，使用 Glob 確認檔案是否存在：
     ```
     Glob 工具：[vault_path]/[條目路徑].md
     ```
   - 若找不到 → 存入 `index_stale[]`

   **c. index 分類錯誤**（index 中的 wiki_category 與實際目錄不一致）：
   - 對 `index_entries[]` 中每個條目，比對：
     - 從 wikilink 路徑萃取的目錄分類（`主題知識/[目錄]/...` 的第二層）
     - 對應 `pages[]` 中該頁面的 `wiki_category` 欄位
   - 若兩者不一致 → 存入 `index_mismatch[]`

---

## Step 3：tag-review 整合（選擇性）

> **前置說明**：tag-review 是獨立 skill，非 agent，無法透過 `subagent_type` 參數直接委派 Agent tool 呼叫。因此本 Step 採用「提示使用者」的方式整合，而非自動執行。

對以下頁面，在 Step 4 報告末尾提示使用者可進一步執行 tag-review：

- `orphans[]` 中的所有頁面（孤兒頁可能標籤分類有誤，導致未被連結）
- `stale[]` 中距今超過 180 天的頁面（長期未更新的頁面標籤可能已過時）

在報告末尾輸出：

```
---

## 建議後續執行 tag-review 的頁面

以下頁面可能標籤分類有誤或過時，建議另行觸發 tag-review skill 檢查：

- [[主題知識/實體/XXX]]（原因：孤兒頁）
- [[主題知識/概念/YYY]]（原因：已 200 天未更新）
...
```

---

## Step 4：輸出報告

產出以下結構化 lint 報告，輸出至主對話（不寫入 Vault 檔案，僅顯示於對話中）：

````markdown
# Wiki Lint 報告

**執行日期**：YYYY-MM-DD
**掃描頁面數**：N

---

## 1. 孤兒頁面（N 個）

以下頁面沒有任何其他頁面以 wikilink 引用：

- [[主題知識/實體/XXX]]
- [[主題知識/概念/YYY]]
...

**建議**：檢查這些頁面是否應被其他主題引用，或考慮是否為應刪除的廢頁。

---

## 2. 缺失交叉引用（N 處）

以下頁面的正文提到既有主題，但未變為 wikilink：

- [[主題知識/實體/XXX]]：正文提到「RAG」，建議置換為 [[主題知識/概念/RAG]]
- [[主題知識/概念/YYY]]：正文提到「Claude Code」，建議置換為 [[主題知識/實體/Claude Code]]
...

**建議**：手動在對應位置加上 wikilink，或重新觸發 wiki-writer 的交叉連結步驟。若選擇自動修補，請見 Step 6。

---

## 3. 可能過期（N 個）

以下頁面的 `updated` 距今超過 90 天：

- [[主題知識/實體/XXX]]（已 120 天未更新）
- [[主題知識/概念/YYY]]（已 95 天未更新）
- [[主題知識/比較/ZZZ]]（日期未知）
...

**建議**：若有新來源可補充，重新 archive 相關 raw 檔觸發 upsert；否則可忽略。

---

## 4. 未解決矛盾（N 個）

以下頁面含有未處理的矛盾註記（`[!warning]`）：

- [[主題知識/概念/XXX]]：2 處矛盾
- [[主題知識/實體/YYY]]：1 處矛盾
...

**建議**：檢視矛盾內容，確認正確版本後移除 `[!warning]` 區塊。此項無法自動修補，需手動處理。

---

## 5. 建議新建的概念頁（N 個）

以下專有名詞在多個頁面被提及但尚未有對應主題頁（建議性質，可能有誤報）：

- `Transformer 架構`（在 [[主題知識/概念/LLM]]、[[主題知識/概念/RAG]] 提及）
- `attention 機制`（在 [[主題知識/概念/Transformer 架構]] 提及）
...

**建議**：若需要建頁，手動建立 raw 檔並歸檔，或透過 query skill 探索後回填總覽。

---

## 6. index.md 一致性問題

**遺漏（N 個）**：index 未列出的實際頁面

- [[主題知識/實體/XXX]]

**過期（N 個）**：index 列出但檔案已刪除

- [[主題知識/概念/YYY]]

**分類錯誤（N 個）**：index 中的目錄分類與 wiki_category 欄位不一致

- [[主題知識/概念/ZZZ]]（目錄為「概念/」，但 wiki_category 欄位為「實體」）

**建議**：執行任意 archive 操作會自動更新 index.md，或選擇 Step 6 的自動修補。

---

## 總結

| 類別 | 數量 |
|------|------|
| 孤兒頁面 | N |
| 缺失交叉引用 | N |
| 可能過期 | N |
| 未解決矛盾 | N |
| 建議新建概念頁 | N |
| index 問題（遺漏 + 過期 + 錯誤） | N |

**整體健康度**：[評級]

> 評級標準：
> - **優秀**：各類問題總計 ≤ 3
> - **良好**：各類問題總計 4–10
> - **需改善**：各類問題總計 11–25
> - **需大修**：各類問題總計 > 25，或有未解決矛盾 ≥ 3

---

## 建議優先處理

1. **未解決矛盾**（影響知識準確性，優先手動修復）
2. **index 過期條目**（可自動修補，低風險）
3. **缺失交叉引用**（可部分自動修補，改善可導覽性）
4. **孤兒頁面**（需人工判斷是否刪除或補充引用）
5. **可能過期頁面**（視使用者是否有新來源而定）
6. **建議新建概念頁**（建議性質，視需求決定）
````

> 注意：若某類別問題為 0，在報告中保留標題但寫「無問題。」，不省略整個區塊，確保報告結構完整。

---

## Step 5：追加 log.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/log-spec.md` 了解格式（若尚未讀取）。

**時間戳記**：執行以下命令取得當前本地時間：

```bash
date '+%Y-%m-%d %H:%M'
```

**省略規則**（與 log-spec.md 一致）：若某項目無問題（數量為 0），省略該行。

**Append 方法**：使用 obsidian CLI append 直接追加至 log.md：

```
obsidian append path="log.md" content="\n## [YYYY-MM-DD HH:mm] lint | manual\n- 掃描頁面：N\n- 孤兒頁面：[[主題知識/實體/XXX]], [[主題知識/概念/YYY]]\n- 矛盾：[[主題知識/概念/AAA]] 2 處\n- 缺失交叉引用：N 處\n- index 問題：N 個（遺漏 M + 過期 K + 錯誤 L）\n- 整體健康度：[評級]" vault=[vault_name]
```

> 注意：實際執行時將佔位符替換為真實數值；若某項目為 0 則省略該行，直接拼接其他行。`\"` 跳脫雙引號，若 content= 超過 4KB 則分多次 append。

若 `log.md` 不存在，先建立再追加：
```
obsidian create path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- 格式：## [YYYY-MM-DD HH:mm] [ingest|query|lint] | [標題] -->\n" vault=[vault_name]
```
建立後再執行上方的 append 命令。

---

## Step 6：詢問是否自動修補（選填）

> **以下操作使用管道 2（Claude Code Read/Edit/Write），見 `references/cli-usage.md`。**
> 管道 2 僅限 lint skill 的自動修補操作使用；obsidian CLI 不支援正文中間的字串置換或整檔重寫。

**可自動修補的項目**：

1. **index.md 一致性問題**（遺漏 + 過期）→ 重新生成 index.md（使用管道 2 Write 工具整檔重建）
2. **缺失交叉引用**（精確字串置換，限正文中出現的純文字主題標題）→ 使用管道 2 Edit 工具做字串置換
3. **未解決矛盾的搬移**（將尾端矛盾註記搬移至正文對應段落旁）→ 使用管道 2 Read/Edit 工具

**不可自動修補的項目**（只列出建議，需使用者手動處理）：
- 孤兒頁面（需判斷是否刪除或補充引用語意）
- 可能過期頁面（需新來源，非技術問題）
- 未解決矛盾（需人工確認正確版本後才能移除 `[!warning]`）
- 建議新建概念頁（需使用者決策）

若上述可修補項目有任何一項數量 > 0，輸出以下詢問：

```
---

以下問題可自動修補：

1. index.md 一致性（[遺漏 M 個] + [過期 K 個]）→ 使用 Write 工具整檔重建 index.md
2. 缺失交叉引用（N 處）→ 對符合安全條件的位置使用 Edit 工具自動置換為 wikilink

是否執行自動修補？
  - 輸入「全部」執行所有項目
  - 輸入「1」或「2」執行特定項目
  - 輸入「n」或「否」跳過
```

等待使用者回覆後執行。

### 自動修補：index.md（管道 2：Write 工具）

1. 讀取 `${CLAUDE_PLUGIN_ROOT}/references/index-spec.md` 了解條目格式
2. 依 `pages[]` 在主對話內部組合完整 index.md 內容：
   - 開頭固定為 `# Wiki Index\n`
   - 對所有主題頁產出最新條目，每個主題只保留一筆
   - 按**主題標題字母排序**輸出平坦清單（不引入分類區塊結構）
   - 每個條目格式：`[YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [摘要]（sources: N）`（重建後都是既有條目，不加 `[new/updated]` 後綴）
   - 每個條目的摘要從對應頁面 `## 摘要` 區塊首句讀取，或正文首句（≤ 50 字）
   - sources 計數從 frontmatter `sources` 陣列長度取得
3. 移除 `index_stale[]` 中的過期條目（不加入新 index）
4. 將 `index_missing[]` 中的頁面補入清單（依字母排序插入正確位置）
5. **使用 Write 工具整檔重建**（管道 2）：
   ```
   Write 工具：[vault_path]/index.md
   內容：[組合好的完整 index.md 內容]
   ```

### 自動修補：缺失交叉引用（管道 2：Edit 工具）

對 `missing_xref[]` 中的每個 `(page_path, mentioned_topic, suggested_wikilink)` tuple：

**安全條件**（必須同時符合才執行自動修補）：
1. `mentioned_topic` 在該行中是**獨立詞彙**（前後為空白、標點、行首/行尾），不是某個更長詞彙的一部分
2. 該頁面的 `page_path` 在 `pages[]` 中存在（確保目標檔案仍在）
3. 置換目標行**不在** code block、frontmatter、HTML 注釋範圍內（對應 2b 的忽略規則）

**置換流程**（管道 2）：
1. 使用 Read 工具讀取完整頁面內容
2. 對正文逐行掃描，找到符合安全條件的目標行
3. 僅將該行中**第一次出現**的純文字主題標題替換為 `suggested_wikilink`（避免同行重複置換）
4. 若同一頁面有多個不同主題需置換，在同一次 Read → 多次 Edit 流程中一併處理（減少 API 呼叫）
5. **使用 Edit 工具做字串置換**（管道 2）：
   ```
   Edit 工具：[vault_path]/[page_path]
   old_string: [目標行原始文字中的純文字主題名稱]
   new_string: [suggested_wikilink]
   ```

**不符合安全條件的項目**：在修補完成後列出，提示使用者手動確認。

### 修補完成通知

```
自動修補完成（使用管道 2 工具）：

- index.md：已使用 Write 工具整檔重建（新增 M 筆、移除 K 筆過期條目）
- 交叉引用：已使用 Edit 工具修補 N 處（略過 K 處不符安全條件）

以下交叉引用需手動確認：
- [[主題知識/實體/XXX]] 第 12 行：「Claude」可能指 Anthropic 的 Claude，也可能是其他用法，請手動確認
```
