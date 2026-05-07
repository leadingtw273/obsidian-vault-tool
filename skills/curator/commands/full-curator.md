# Full Curator：Wiki 健康檢查與結構演進

掃描 `主題知識/` 下所有筆記，執行 8 項既有檢查 + **v0.9.0-beta 新增 4 項檢查**（confidence violations / staleness / contradictions / wikilink format），輸出修補建議報告至 `outputs/lint/<date>.md`，並追加 `log.md`。

> v0.9.0-beta 升級：
> - 報告寫入 `outputs/lint/<date>.md`（依 `references/structure/outputs-layer.md`）
> - 新增 4 項 v0.9 檢查（依 `references/quality/{sha-integrity,staleness,contradictions}.md` 與 `references/taxonomy/aliases-and-wikilink.md`）
> - frontmatter 解析含 v0.9 新欄位（confidence / domain_volatility / last_reviewed / high_candidate）
> - interaction_mode 分流（agent mode 不執行 Step 6 自動修補）

---

## Step 0：讀取 interaction_mode（v0.9.0-beta 新增）

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md` 規範，從 vault CLAUDE.md 讀取 `interaction_mode` 欄位。若欄位缺失 → 預設 `human`。

agent mode 下：
- Step 6（自動修補）**不執行**（agent 不可自動修補）
- Step 4 報告寫入 outputs/lint/，**不寫入 overview.md 待 review 清單**
  （staleness 不是 high 優先級，依 `references/quality/staleness.md`）

---

## Step 1：載入所有主題知識頁的 frontmatter

使用 Glob 工具取得所有主題頁清單：

```
Glob 工具：[vault_path]/主題知識/**/*.md
```

對每個找到的檔案：
1. 使用 Read 工具讀取前 30 行（取得 frontmatter，v0.9 擴充後）
2. 解析 frontmatter，提取以下欄位：
   - `title`（主題標題，若缺失則以檔名作為替代）
   - `date`（首次建立日期）
   - `updated`（最後 upsert 日期）
   - `tags`（標籤陣列）
   - `aliases`（別名陣列，可能不存在）
   - `sources`（來源陣列）
   - `wiki_category`（實體 / 概念 / 比較 / 總覽）
   - **v0.9.0-beta 新增**：
     - `confidence`（low / medium / high，缺失視為 low）
     - `source_count`（整數，缺失視為 sources 陣列長度）
     - `domain_volatility`（high / medium / low，缺失視為 medium）
     - `last_reviewed`（YYYY-MM-DD，缺失視為 updated 或 date）
     - `high_candidate`（true / false，缺失視為 false）
3. 記錄該檔案相對於 `vault_path` 的路徑（格式：`主題知識/[類別]/[檔名].md`）

將所有頁面資訊彙整為 `pages[]` 資料結構，於主對話內部記憶儲存。

**若 `pages[]` 為空**（Glob 找不到任何 `.md` 檔案）：

```
Wiki 為空，主題知識/ 下尚無任何頁面，無需檢查。
```

輸出以上訊息後終止。

---

## Step 2：執行 14 項檢查

對 `pages[]` 依序執行以下 14 項檢查。所有檢查**均由主對話執行**，不委派 sub-agent。

分組：
- **2a~2f**：基礎健康檢查（孤兒 / 交叉引用 / 過期 / 矛盾 / 缺漏概念 / index 一致性）
- **2g~2h**：結構偵測（升級候選 / 父子關係）
- **2i~2m**：v0.9.0-beta 新增（confidence / contradictions pending / staleness / wikilink 格式 / high_candidate pending）
- **2n**：v0.9.0-rc 新增（tag 品質檢查，原 tag-review skill 併入）

> **效能提示**：多項檢查（2b、2e、2g）需要讀取頁面完整內容。建議在 Step 1 掃描後，對每個頁面用 Read 工具讀取一次完整內容並快取於記憶體中，避免同一頁面跨檢查重複讀取。

初始化以下儲存結構（主對話內部記憶）：
- `orphans[]`：孤兒頁面路徑清單
- `missing_xref[]`：缺失交叉引用，格式 `(page_path, mentioned_topic, suggested_wikilink)`
- `stale[]`：可能過期的頁面，格式 `(page_path, days_since_updated)`（**v0.9 升級為 staleness 檢查 2k**）
- `conflicts[]`：含未解決矛盾的頁面路徑清單（**v0.9 升級為 contradictions 檢查 2j**）
- `missing_concepts[]`：建議新建概念頁，格式 `(source_page, suggested_new_topic)`
- `index_missing[]`：index 遺漏的頁面路徑
- `index_stale[]`：index 過期（檔案已刪除）的條目
- `index_mismatch[]`：index 分類不一致的條目，格式 `(index_entry, actual_directory, index_category)`
- `upgrade_candidates[]`：符合升級條件的頁面，格式 `(page_path, section_name, trigger_reason)`
- `hierarchy_candidates[]`：父子關係候選，格式 `(parent_path, child_path, relationship_type, reason)`
- **v0.9.0-beta 新增**：
  - `confidence_violations[]`：違反 confidence 規則的頁面，格式 `(page_path, violation_type, detail)`
  - `staleness_warnings[]`：依 v0.9 staleness 閾值偵測過期，格式 `(page_path, volatility, days_since_reviewed, threshold)`
  - `contradictions_pending[]`：含 ⚠ 條目（未標 [已解決]）的頁面，格式 `(page_path, contradiction_count)`
  - `wikilink_violations[]`：違反 wikilink 格式鐵律，格式 `(page_path, line, raw_wikilink, suggested_slug)`
  - `high_candidates_pending[]`：含 high_candidate: true 的頁面，格式 `(page_path, source_count, since_date)`
- **v0.9.0-rc 新增**：
  - `tag_violations[]`：違反 tag 規範的頁面（原 tag-review skill 併入 curator），格式 `(page_path, violation_type, detail, suggestion)`
    - violation_type 枚舉：`missing-hierarchy` / `incomplete-hierarchy` / `category-mismatch` / `over-limit` / `fragment-tag` / `english-format`

---

### 2a. 孤兒頁面檢測

**定義**：`主題知識/` 與 `歷史紀錄/` 下，完全沒有任何其他頁面以 wikilink 引用的主題頁。

**執行流程**：

使用原生 CLI 命令一次取得所有孤兒頁：

```bash
obsidian orphans vault=[vault_name]
```

從結果中篩選 `主題知識/` 路徑下的頁面（CLI 結果可能包含 vault 全部無反向連結的檔案）。

若需要更精細的篩選（例如排除 index.md 中的引用不算有效引用），可對候選孤兒頁逐一補充 Grep 驗證：

```
Grep 工具：
  pattern: \[\[.*{主題標題}.*\]\]（將 {主題標題} 替換為實際的主題標題）
  path: [vault_path]
  glob: **/*.md（排除 index.md）
  output_mode: files_with_matches
```

**注意事項**：
- 同時確認 `aliases` 中的別名是否有引用（若 CLI 結果已納入 aliases 引用則無需額外 Grep）
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

**補充交叉驗證**（選用）：掃描完成後，可用 CLI 命令取得所有未解決 wikilink，與 `missing_xref[]` 對比：

```bash
obsidian unresolved vault=[vault_name]
```

若 `unresolved` 回報的 wikilink 目標在 `pages[]` 中存在對應頁面，表示該連結格式有誤（路徑拼錯或分類有誤），需人工修正。

---

### 2c. 過期 updated 檢測

**定義**：`updated` 欄位距今超過 90 天的頁面（curator 只標記，不自動判斷是否真的「過期」，由使用者決定）。

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

   > 取得實際檔案列表的替代方法：`obsidian files vault=[vault_name] folder="主題知識"` 可直接列出 `主題知識/` 下所有檔案，與 `index_entries[]` 比對效率更高。

   **c. index 分類錯誤**（index 中的 wiki_category 與實際目錄不一致）：
   - 對 `index_entries[]` 中每個條目，比對：
     - 從 wikilink 路徑萃取的目錄分類（`主題知識/[目錄]/...` 的第二層）
     - 對應 `pages[]` 中該頁面的 `wiki_category` 欄位
   - 若兩者不一致 → 存入 `index_mismatch[]`

---

### 2g. 結構升級偵測（v0.9.0 升級 — 2026-04-27）

> 規格詳見 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/topic-hierarchy-spec.md`。
> v0.9.0 升級：原 v0.8 規則「≥3 個 ### 子標題」過於寬鬆（73 頁 vault 實測產生 66 個假候選），新增**字數門檻 + 排除類型**。

**定義**：單頁主題（不含 `type: topic-hub`）中的 `##` 章節已累積足夠內容、且不屬於排除類型，符合升級為目錄結構的條件。

**執行流程**：

對 `pages[]` 中所有**非目錄型主題**（frontmatter 不含 `type: topic-hub`）：

1. 使用 Read 工具讀取完整內容
2. 解析所有 `##` 章節，對每個章節統計：
   - `###` 子標題數量
   - 章節**正文字數**（去除子標題本身的純段落字數）
   - 該章節在 `pages[]` 中被多少不同 `sources` 引用（比對該章節標題是否出現在其他頁面的 sources 相關內容中）
3. **排除規則**（任一命中即跳過該章節）：
   - **archive 補充章節**：標題符合任一模式：
     - `re.match(r'^補充（', section_name)` — 顯式補充章節
     - `re.search(r'（\d{4}-\d{2}-\d{2}\s*來自', section_name)` — 含日期 + 「來自 [[...]]」格式（archive 流程的時間戳記）
   - **核心定義章節**：標題為「核心參數」/「核心能力」/「核心概念」/「Definition」/「定義」/「摘要」/「References」
   - **步驟性章節**：標題以「一、」/「二、」/「三、」/「Step 1」/「步驟 1」等序號開頭（這類章節是線性流程，拆開反而難導航）
   - **目錄已存在的同名子主題**：父主題已是 topic-hub 且 wikilink 中已含同名 `[[子主題]]`
4. 對通過排除規則的章節，判斷是否符合升級條件：
   - **量化條件**（A AND B 同時滿足）：
     - A: ≥3 個 `###` 子標題
     - B: 正文字數 ≥ 2000
   - **替代量化條件**（C 單獨滿足）：
     - C: 被 ≥3 個不同來源引用
   - **質化條件**：record-writer 曾識別為獨立主題（從 sources 註記推斷）
5. 符合任一條件者記錄入 `upgrade_candidates[]`

**記錄**：格式 `(page_path, section_name, trigger_reason, char_count, sub_count)`。

範例：
```
(主題知識/概念/RAG.md, "Chunk 策略", "4 個 ### 子標題 + 3500 字", 3500, 4)
(主題知識/概念/RAG.md, "Embedding", "被 3 個來源引用", 1200, 2)
```

**v0.8 → v0.9 兼容**：若使用者期望舊規則（不過濾），可在主對話中傳遞 `--legacy-upgrade-detection` 旗標跳過排除規則（但預設啟用 v0.9 規則）。

---

### 2h. 父子關係偵測（跨頁面）

> 規格詳見 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/topic-hierarchy-spec.md`「父子關係判準」段落。

**定義**：兩個獨立頁面之間存在明顯的父子從屬關係，但目前以扁平結構並存，建議重組為目錄結構。

**執行流程**：

1. 從 `pages[]` 中篩選所有**非目錄型頁面**（frontmatter 不含 `type: topic-hub`），建立標題 + aliases 清單
2. 對每對頁面 (A, B)，依「父子關係判準」的歸併條件評估：
   - 工具屬性：A 是 B 的插件/擴充/CLI/SDK？
   - 組成關係：A 是 B 的核心組件或子系統？
   - 實例關係：A 是 B 的具體實作？
3. 符合條件者，判定父子方向（較廣泛者為父）
4. 排除條件過濾：
   - 多重父節點 → 跳過
   - 子大於父 → 跳過
   - 方向不明確 → 跳過
   - 深度超限（歸併後超過 3 層）→ 跳過
5. **已在目錄中的子頁面不重複偵測**：若 A 已在 B 的目錄下（路徑包含 B 的資料夾），跳過

**記錄**：將候選組存入 `hierarchy_candidates[]`，格式 `(parent_path, child_path, relationship_type, reason)`。

**輔助信號**（提高判定信心，非必要條件）：
- 子頁面的正文中引用了父頁面的 wikilink（表示從屬意識已存在）
- 子頁面的標題包含父頁面的標題作為前綴或後綴
- 子頁面的 `tags` 包含父頁面的標題作為標籤

---

### 2i. Confidence 違規檢查（v0.9.0-beta 新增）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/governance/confidence-gating.md`。

**檢查項目**：

1. **`high` 但未經人類確認**：concept 頁 `confidence: high` 但 Evolution Log 中沒有任何「human 確認升級為 high」的條目 → 違規（可能是 v0.8 vault 升級時誤帶值）
2. **`high` 但 Contradictions 段落含 ⚠ 條目**：違規（升級應被矛盾阻斷）
3. **source_count 與 sources 陣列長度不符**：除非 `personal_writing` 來源造成的差異，否則違規
4. **`confidence` 值非合法**：不在 `low / medium / high` 之內 → 違規

**執行流程**：

對 `pages[]` 中每個頁面：
- 讀取 frontmatter 的 `confidence`、`source_count`、`high_candidate`
- 讀取 body 的 `## Contradictions` 段落
- 讀取 body 的 `## Evolution Log` 段落
- 依上述 4 條規則檢查
- 違規時加入 `confidence_violations[]`，格式 `(page_path, violation_type, detail)`

**對應到 Step 4 報告段落**：`### ⚠ Confidence Violations`

---

### 2j. Contradictions 待裁決檢查（v0.9.0-beta 新增）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/quality/contradictions.md`。

**檢查項目**：

對 `pages[]` 中每個頁面，找 `## Contradictions` 段落內所有 `⚠` 條目（不包括 `[已解決] ⚠` 條目）：

- 計算未解決矛盾數量
- 大於 0 → 加入 `contradictions_pending[]`，格式 `(page_path, count)`

**v0.9 注意事項**：
- 此檢查取代舊的「2c 矛盾偵測」中的部分功能（舊的 `> [!warning] 矛盾註記` callout 也應該被偵測，但 v0.9 wiki-writer 已停用該格式）
- 偵測 `<!-- ⚠ Contradiction appended by wiki-writer -->` 註解：這是 wiki-writer 在 archive 時 append 的條目，curator 應該幫忙搬到 `## Contradictions` 段落內（v0.9 接受的折衷）

**對應到 Step 4 報告段落**：`### ⚠ Contradictions Pending`

---

### 2k. Staleness 檢查（v0.9.0-beta 新增）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/quality/staleness.md`。

**檢查項目**：

對 `pages[]` 中每個頁面，依 `domain_volatility` 對應的閾值計算是否過期：

| domain_volatility | 閾值 |
|------------------|------|
| `high` | > 90 天 |
| `medium` | > 180 天 |
| `low` | > 365 天 |

計算 `今日 - last_reviewed > 閾值`：
- 是 → 加入 `staleness_warnings[]`，格式 `(page_path, volatility, days_since_reviewed, threshold)`

**取代既有 2c 「過期條目」檢查**：v0.8 的 2c 是固定 180 天閾值，v0.9 升級為依 volatility 動態閾值。`stale[]` 不再使用，由 `staleness_warnings[]` 取代。

**對應到 Step 4 報告段落**：`### ⚠ Stale Concepts`

---

### 2l. Wikilink 格式違規檢查（v0.9.0 對齊 — 2026-04-27）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/aliases-and-wikilink.md` 的「禁用解析地雷」原則。
> v0.9.0-alpha 的「英文 slug 鐵律」已廢止（與實作分叉、強迫中文使用者翻譯不合理），改為只偵測真正會引發解析問題的字元。

**檢查項目**：

對 `pages[]` 中每個頁面（讀取完整內容），用 regex 偵測 `[[...]]` 模式，**只標記三類解析地雷**：

- 違規 1：**含底線**（`[[value_investing]]`、`[[claude_code]]`）— grep 困難
- 違規 2：**駝峰式**（`[[valueInvesting]]`、`[[claudeCode]]`）— tokenize 不穩定 + case-sensitive 易誤
- 違規 3：**連續中英無分隔**（`[[ConcatRAG架構]]`、`[[本地LLM]]`）— 可讀性差，建議用空格分開

**不再視為違規**（v0.9.0 對齊實踐）：
- 含中文字元（`[[圖像編輯模型]]`）— 領域慣例命名
- 含大寫英文（`[[Claude Code]]`、`[[Stable Diffusion]]`、`[[SDXL]]`）— 業界官方寫法
- 含空格（`[[Claude Code]]`、`[[GGUF 格式]]`）— Obsidian 完全支援

**例外**：
- 來源頁的 wikilink（`[[歷史紀錄/...]]`）允許含日期格式與底線，不視為違規（來源檔名格式 `01_主題名稱` 是 archive 流程慣例）
- **`[序號]_[概述]` 格式的純檔名 wikilink**（即使省略 `歷史紀錄/` 路徑，如 `[[01_RAG架構簡介]]`、`[[09_IP-Adapter工作流程實務教學]]`）也是來源頁，放行 — 偵測規則：leaf 以 `^\d+_` 開頭即視為來源頁引用

**駝峰判定**：
- 純英文且開頭小寫 + 內含大寫（`valueInvesting`）→ 駝峰
- 純英文且開頭大寫 + 內含大寫（`ValueInvesting`）→ PascalCase，**不視為違規**（業界專有名詞如 `ComfyUI` 是 PascalCase）
- 中英混合不視為駝峰（`Z-Image` 是連字符不是駝峰）

**執行流程**：

對每個違規 wikilink：
- 加入 `wikilink_violations[]`，格式 `(page_path, line, raw_wikilink, violation_type, suggestion)`
- `violation_type` 枚舉：`underscore` / `camel-case` / `no-separator`
- `suggestion`：空格分開的建議形式（如 `value_investing` → 建議 `Value Investing` 或 `價值投資`）

**對應到 Step 4 報告段落**：`### ⚠ Wikilink Format Violations`

---

### 2m. high_candidate 待 review 收集（v0.9.0-beta 新增）

對 `pages[]` 中每個頁面，若 `high_candidate: true` → 加入 `high_candidates_pending[]`，格式 `(page_path, source_count, high_candidate_since)`。

這個清單會在 Step 4 報告中提示使用者「有 N 個 high_candidate 待你確認」，並指引去 overview.md 處理。

**對應到 Step 4 報告段落**：`### high_candidate Confidence (待人類確認升級為 high)`

---

### 2n. Tag 品質檢查（v0.9.0-rc 新增，原 tag-review skill 併入）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/tag-topic-spec.md` 的標籤規範。
> v0.9.0-rc 起 tag-review 不再是獨立 skill，標籤品質檢查由 curator 自動執行。

**檢查項目**：對 `pages[]` 中每個知識筆記的 `tags` 欄位執行以下檢查，違規寫入 `tag_violations[]`：

1. **`tags[0]` 格式**：必須為層級結構路徑（含 `/`，如 `技術/AI/LLM`）。若 `tags[0]` 無 `/` → 違規類型 `missing-hierarchy`
2. **層級拆解完整性**：`tags[0]` 拆開的每一層（如 `技術`、`AI`、`LLM`）是否都存在於 `tags` 陣列中。若缺任何一層 → 違規類型 `incomplete-hierarchy`
3. **`category` 一致性**：`category` 欄位是否等於 `tags[0]` 的第一層。若不等 → 違規類型 `category-mismatch`
4. **總數上限**：`tags` 總數是否 ≤ 10。若 > 10 → 違規類型 `over-limit`
5. **碎片化偵測**：**跨 `pages[]` 統計**每個描述標籤的出現次數。只在單一頁面出現一次的標籤（非層級結構 / 非層級拆解）→ 違規類型 `fragment-tag`（提示合併或移除）
6. **PascalCase 檢查**（英文描述標籤）：英文 tag 應為 `PascalCase`（如 `RAG`、`PromptEngineering`），非 PascalCase（含連字符、底線、空格）→ 違規類型 `english-format`

**執行流程**：

```
1. 用 obsidian tags vault=[vault_name] counts（或 Glob + 讀 frontmatter）取得全 vault tag 使用統計
2. 對 pages[] 中每個頁面逐一檢查 6 項規則
3. 違規寫入 tag_violations[]，格式 (page_path, violation_type, detail, suggestion)
```

**對應到 Step 4 報告段落**：`### ⚠ Tag Quality Violations`

**記錄**：將違規清單存入 `tag_violations[]`，格式包含違規類型 + 具體描述 + 建議修正。

---

## Step 3：Tag-Review Finalization（v0.9.0-rc 重寫）

> **v0.9.0-rc 變更**：tag-review 已併入 curator（見 Step 2n）。本 Step 不再「提示觸發外部 skill」，
> 而是依 `interaction_mode` 對 Step 2n 的 `tag_violations[]` 做最終處理。

### 3.1 檢查是否有違規

若 `tag_violations[]` 為空 → 跳過本 Step。

### 3.2 Mode 分流

| Mode | 行為 |
|------|------|
| `human` | 在 Step 4 報告中以結構化清單列出所有違規，附修正建議，等待使用者決定是否執行 Step 6 的自動修補 |
| `agent` | 違規寫入 `outputs/lint/<date>.md` 的 `### ⚠ Tag Quality Violations` 段落，**不修補**（修補需人類確認） |

### 3.3 輸出格式（Step 4 報告中）

```
### ⚠ Tag Quality Violations (N 個)

#### missing-hierarchy（tags[0] 無層級結構）
- [[主題知識/概念/XXX]]: tags[0] = `RAG`
  建議: 改為 `技術/AI/RAG`

#### incomplete-hierarchy（層級拆解不完整）
- [[主題知識/概念/YYY]]: tags[0] = `技術/AI/LLM`，缺平坦標籤 `技術` 或 `AI` 或 `LLM`
  建議: tags 陣列補上缺少的層級

#### category-mismatch（category ≠ tags[0] 第一層）
- [[主題知識/實體/ZZZ]]: tags[0] = `技術/AI`，但 category = `工具`
  建議: category 改為 `技術`

#### fragment-tag（只出現一次的碎片化標籤）
- [[主題知識/概念/WWW]]: tag `特殊術語2024` 僅在此頁出現
  建議: 考慮移除或合併到更通用的標籤

#### english-format（英文標籤非 PascalCase）
- [[主題知識/實體/VVV]]: tag `prompt-engineering` 應為 `PromptEngineering`
  建議: 改為 PascalCase
```

### 3.4 衍生建議（原 tag-review 的補強邏輯）

對以下情境**額外**在 Step 4 報告提示「標籤可能需要重新審視」（但不自動改）：

- `orphans[]` 中的所有頁面：孤兒頁可能因標籤分類不當而無法被其他頁引用
- 長期未更新（`staleness_warnings[]`）的頁面：標籤可能反映過時的理解

這些情境不產生 `tag_violations[]` 條目（因為標籤本身格式可能無錯），僅在報告末尾以「**建議重新審視 tag 的頁面**」段落提示。

---

## Step 4：輸出報告

產出以下結構化報告，輸出至主對話（不寫入 Vault 檔案，僅顯示於對話中）：

````markdown
# Wiki Curator 報告

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

## 7. 結構升級候選（N 個）

以下頁面的章節已達升級條件，建議拆分為目錄結構：

- [[主題知識/概念/RAG]]：章節「Chunk 策略」有 4 個 ### 子標題
- [[主題知識/概念/RAG]]：章節「Embedding」被 3 個來源引用
...

**建議**：執行自動修補將這些頁面升級為目錄結構（topic/topic.md + 子頁面）。升級流程見 `references/taxonomy/topic-hierarchy-spec.md`。

---

## 8. 父子關係候選（N 組）

以下獨立頁面建議重組為目錄結構：

- [[主題知識/實體/Obsidian]] ← [[主題知識/實體/Obsidian CLI]]（工具屬性：CLI 是 Obsidian 的命令行介面）
- [[主題知識/概念/XXX]] ← [[主題知識/概念/YYY]]（組成關係：YYY 是 XXX 的核心組件）
...

**建議**：執行自動修補將父頁面升級為目錄結構，並將子頁面移入。重組流程見 `references/taxonomy/topic-hierarchy-spec.md`。

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
| 結構升級候選 | N |
| 父子關係候選 | N |

**整體健康度**：[評級]

> 評級標準：
> - **優秀**：各類問題總計 ≤ 3
> - **良好**：各類問題總計 4–10
> - **需改善**：各類問題總計 11–25
> - **需大修**：各類問題總計 > 25，或有未解決矛盾 ≥ 3

---

## 建議優先處理

1. **未解決矛盾**（影響知識準確性，優先手動修復）
2. **結構升級候選**（可自動修補，改善知識組織）
3. **父子關係候選**（可自動修補，需使用者確認，改善知識組織）
4. **index 過期條目**（可自動修補，低風險）
5. **缺失交叉引用**（可部分自動修補，改善可導覽性）
6. **孤兒頁面**（需人工判斷是否刪除或補充引用）
7. **可能過期頁面**（視使用者是否有新來源而定）
8. **建議新建概念頁**（建議性質，視需求決定）
````

> 注意：若某類別問題為 0，在報告中保留標題但寫「無問題。」，不省略整個區塊，確保報告結構完整。

---

## Step 4.5：寫入 outputs/lint/<date>.md（v0.9.0-beta 新增）

> 依 `${CLAUDE_PLUGIN_ROOT}/references/structure/outputs-layer.md`，curator 報告必須持久化至 outputs/ 層。

### 4.5.1 檢查 outputs/lint/ 目錄

若 `[vault_path]/outputs/lint/` 不存在（v0.8 vault 未升級）→ 嘗試 `mkdir -p`。失敗則跳過本 step（不阻塞主流程）。

### 4.5.2 寫入報告

**檔名規則**：`outputs/lint/[YYYY-MM-DD].md`（每天最多一個檔案）

若同日已有檔案 → append 新段落（用 `## Run [N] - HH:mm` 標題分隔）；若無 → create 新檔。

**frontmatter 範本**（依 `references/structure/outputs-layer.md`）：

```yaml
---
type: output
output_kind: lint
date: [YYYY-MM-DD]
graph-excluded: true
generator: curator
interaction_mode: [human|agent]
checks_run: 14
violations_found: [N]
---
```

**內容**：複製 Step 4 的完整報告（含所有 8 項既有檢查結果）+ v0.9 新增的 4 項檢查段落：
- `### ⚠ Confidence Violations`（從 confidence_violations[]）
- `### ⚠ Contradictions Pending`（從 contradictions_pending[]）
- `### ⚠ Stale Concepts`（從 staleness_warnings[]，依 v0.9 動態 volatility 閾值）
- `### ⚠ Wikilink Format Violations`（從 wikilink_violations[]）
- `### high_candidate Confidence (待人類確認升級為 high)`（從 high_candidates_pending[]）

**寫入命令**：

```bash
obsidian create vault=[vault_name] path="outputs/lint/[YYYY-MM-DD].md" content="---\ntype: output\noutput_kind: lint\ndate: [YYYY-MM-DD]\ngraph-excluded: true\ngenerator: curator\ninteraction_mode: [human|agent]\nchecks_run: 14\nviolations_found: [N]\n---\n\n[Step 4 完整報告內容 + v0.9 新區段]"
```

若內容超過 16KB → 分段 append。

### 4.5.3 暫存路徑

將寫入路徑存為 `[lint_output_path]`，供 Step 5 log.md 條目引用。

---

## Step 5：追加 log.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/log-spec.md` 了解格式（若尚未讀取）。

**時間戳記**：執行以下命令取得當前本地時間：

```bash
date '+%Y-%m-%d %H:%M'
```

**省略規則**（與 log-spec.md 一致）：若某項目無問題（數量為 0），省略該行。

**Append 方法**：使用 obsidian CLI append 直接追加至 log.md。

**v0.9.0-beta 條目格式**（含結構化欄位 + outputs 連結）：

```
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] curator [agent]? | manual\nmode: curator\ninteraction_mode: [human|agent]\ntouched_specs: [confidence-gating, contradictions, staleness, aliases-and-wikilink]\nfail_reason: none\nmanual_fix: [no|yes]\n- 掃描頁面：N\n- 孤兒頁面：[[主題知識/實體/XXX]], [[主題知識/概念/YYY]]\n- 矛盾待裁決：[[主題知識/概念/AAA]] 2 處\n- staleness 警告：N 個\n- confidence 違規：N 個\n- wikilink 違規：N 個\n- high_candidate 待確認：N 個\n- 缺失交叉引用：N 處\n- index 問題：N 個（遺漏 M + 過期 K + 錯誤 L）\n- 升級候選：N 個\n- 父子關係候選：N 組\n- 整體健康度：[評級]\n- outputs: [[outputs/lint/[YYYY-MM-DD]]]"
```

> 注意：實際執行時將佔位符替換為真實數值；若某項目為 0 則省略該行，直接拼接其他行。`\"` 跳脫雙引號，若 content= 超過 16KB 則分多次 append。
>
> v0.9.0-beta 條目依 `interaction_mode` 決定標題後綴（agent mode 加 `[agent]`），並含 `mode/touched_specs/fail_reason/manual_fix` 結構化欄位 + `outputs:` 引用 lint 報告檔案。

若 `log.md` 不存在，先建立再追加：
```
obsidian create vault=[vault_name] path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- 格式：## [YYYY-MM-DD HH:mm] [ingest|query|curator] | [標題] -->\n"
```
建立後再執行上方的 append 命令。

---

## Step 6：詢問是否自動修補（選填）

> **以下操作使用管道 2（Claude Code Read/Edit/Write），見 `references/cli-usage.md`。**
> 管道 2 僅限 curator skill 的自動修補操作使用；obsidian CLI 不支援正文中間的字串置換或整檔重寫。

**可自動修補的項目**：

1. **index.md 一致性問題**（遺漏 + 過期）→ 重新生成 index.md（使用管道 2 Write 工具整檔重建）
2. **缺失交叉引用**（精確字串置換，限正文中出現的純文字主題標題）→ 使用管道 2 Edit 工具做字串置換
3. **未解決矛盾的搬移**（將尾端矛盾註記搬移至正文對應段落旁）→ 使用管道 2 Read/Edit 工具
4. **結構升級**（將符合升級條件的單頁主題升級為目錄結構）→ 使用管道 2 + Bash（mkdir/mv）
5. **父子關係重組**（將獨立子頁面移入父主題目錄）→ 使用管道 2 + Bash（mkdir/mv/Edit）

**不可自動修補的項目**（只列出建議，需使用者手動處理）：
- 孤兒頁面（需判斷是否刪除或補充引用語意）
- 可能過期頁面（需新來源，非技術問題）
- 未解決矛盾的內容裁決（需人工確認正確版本後才能移除 `[!warning]`；搬移位置屬可自動修補，見上方第 3 項）
- 建議新建概念頁（需使用者決策）

若上述可修補項目有任何一項數量 > 0，輸出以下詢問：

```
---

以下問題可自動修補：

1. index.md 一致性（[遺漏 M 個] + [過期 K 個]）→ 使用 Write 工具整檔重建 index.md
2. 缺失交叉引用（N 處）→ 對符合安全條件的位置使用 Edit 工具自動置換為 wikilink
3. 結構升級（N 個頁面）→ 將單頁升級為目錄結構（topic/topic.md + 子頁面）
4. 父子關係重組（N 組）→ 將獨立子頁面移入父主題目錄（需逐一確認）

是否執行自動修補？
  - 輸入「全部」執行所有項目
  - 輸入編號（如 1,3）執行特定項目
  - 輸入「n」或「否」跳過
```

等待使用者回覆後執行。

### 自動修補：index.md（管道 2：Write 工具）

1. 讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/index-spec.md` 了解條目格式
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

### 自動修補：結構升級（管道 2 + Bash）

> 升級流程詳見 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/topic-hierarchy-spec.md`。

對 `upgrade_candidates[]` 中的每個頁面，按以下步驟執行升級：

**前置檢查**：
- 確認頁面路徑深度未超過 3 層（`主題知識/[category]/[topic]`）。若超過，跳過該頁面並警告
- 同一頁面的多個章節升級候選，在一次升級操作中一併處理

**升級流程**（以 `主題知識/概念/RAG.md` 為例）：

1. **建立目錄**：
   ```bash
   mkdir -p [vault_path]/主題知識/概念/RAG
   ```

2. **移動主頁**：
   ```bash
   mv [vault_path]/主題知識/概念/RAG.md [vault_path]/主題知識/概念/RAG/RAG.md
   ```

3. **更新主頁 frontmatter**（管道 2 Read/Edit）：
   - 使用 Read 工具讀取 `RAG/RAG.md` 完整內容
   - 在 frontmatter 中加入 `type: topic-hub`、`children` 陣列、`aliases`（含主題名稱）
   - 使用 Edit 工具更新 frontmatter

4. **拆分章節為子頁面**：
   對每個符合升級條件的 `##` 章節：
   a. 從主頁正文中萃取該章節的完整內容（含其下所有 `###` 子標題）
   b. **分配 sources**：分析母主題的 `sources` 陣列，判斷每個 source 貢獻了哪些章節的內容。將與本章節相關的 sources 分配給子頁面（同一 source 可同時出現在主頁和子頁面）
   c. 建立子頁面 `[topic]/[章節標題].md`，frontmatter 包含：
      - `title`、`wiki_category`（繼承母主題）、`tags`（繼承母主題 + 可追加）
      - `sources`（本章節相關的來源，由步驟 b 分配）、`date`、`updated`
   d. 使用 Write 工具建立子頁面
   d. 在主頁中，將該 `##` 章節替換為一行 wikilink + 摘要：
      `- [[章節標題]] — [一句話摘要]`
   e. 使用 Edit 工具更新主頁正文

5. **在主頁新增「子頁面」導航區塊**：
   若正文中尚無 `## 子頁面` 區塊，在正文中合適位置插入

6. **更新 index.md**：
   將 index.md 中 `主題知識/概念/RAG` 的路徑更新為 `主題知識/概念/RAG/RAG`

**深度限制檢查**：
- 若升級候選位於已有目錄結構中（如 `RAG/Chunk 策略.md` 的章節需要再拆分），檢查是否超過 3 層
- 超過 3 層 → 不建立子目錄，改為在 `主題知識/[category]/` 下建立獨立頂級頁面，在原位置保留 wikilink 引用

### 自動修補：父子關係重組（管道 2 + Bash）

> 重組流程詳見 `${CLAUDE_PLUGIN_ROOT}/references/taxonomy/topic-hierarchy-spec.md`。

**前置確認**：每組父子候選需使用者逐一確認（或批次確認），不自動執行。確認時顯示：

```
父子關係重組確認：
  1. [[主題知識/實體/Obsidian]] ← [[主題知識/實體/Obsidian CLI]]（CLI 是 Obsidian 的命令行介面）
  2. ...

是否執行？（輸入「全部」/編號/「n」）
```

**重組流程**（以 Obsidian ← Obsidian CLI 為例）：

1. **檢查父頁面是否已有目錄結構**：
   - 已有 `type: topic-hub` → 跳至步驟 3
   - 尚未有 → 執行步驟 2

2. **升級父頁面為目錄結構**（同 2g 的升級流程）：
   ```bash
   mkdir -p [vault_path]/主題知識/實體/Obsidian
   mv [vault_path]/主題知識/實體/Obsidian.md [vault_path]/主題知識/實體/Obsidian/Obsidian.md
   ```
   使用 Read + Edit 工具更新父頁面 frontmatter：加入 `type: topic-hub`、`children: []`、`aliases`

3. **移動子頁面至父目錄**：
   ```bash
   mv [vault_path]/主題知識/實體/Obsidian CLI.md [vault_path]/主題知識/實體/Obsidian/Obsidian CLI.md
   ```

4. **更新父頁面的 `children` 陣列**：
   使用 Edit 工具在 `children:` 中追加 `"[[主題知識/實體/Obsidian/Obsidian CLI|Obsidian CLI]]"`

5. **更新父頁面正文**：
   若正文中尚無「子頁面」導航區塊，在適當位置插入：
   ```markdown
   ## 子頁面

   - [[Obsidian CLI]] — Obsidian 官方命令行工具
   ```

6. **更新 index.md**：使用 Edit 工具將 index.md 中子頁面和父頁面的路徑更新為新路徑

7. **Wikilink 處理**：由於 Obsidian 最短路徑解析，大部分 `[[Obsidian CLI]]` 連結會自動解析到新位置。僅在 Vault 中存在同名檔案時需手動修正。

**深度限制**：重組前檢查目標路徑深度，超過 3 層則跳過並在報告中警告。

### 修補完成通知

```
自動修補完成（使用管道 2 工具）：

- index.md：已使用 Write 工具整檔重建（新增 M 筆、移除 K 筆過期條目）
- 交叉引用：已使用 Edit 工具修補 N 處（略過 K 處不符安全條件）
- 結構升級：已將 N 個頁面升級為目錄結構（共建立 M 個子頁面）
- 父子關係重組：已重組 N 組（共移動 M 個檔案）

以下交叉引用需手動確認：
- [[主題知識/實體/XXX]] 第 12 行：「Claude」可能指 Anthropic 的 Claude，也可能是其他用法，請手動確認
```
