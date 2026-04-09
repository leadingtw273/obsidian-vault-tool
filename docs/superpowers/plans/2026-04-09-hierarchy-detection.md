# 父子關係偵測機制（Hierarchy Detection）實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓系統能在歸檔時主動識別主題間的父子關係（方案 A），並在巡檢時偵測既有頁面的潛在父子關係（方案 C），統一使用目錄結構表達從屬關係。

**Architecture:** 在 `topic-hierarchy-spec.md` 新增「父子關係判準」作為共用規則；`full-archive.md` 在 Step 1.5 去重後新增 Step 1.6「層級映射」，由主對話集中分配路徑避免並行衝突；`full-curator.md` 新增檢查項 2h「父子關係偵測」掃描既有頁面，並在自動修補中支援重組。同時放寬 `topic-hierarchy-spec.md` 的檔案移動限制，允許 curator 在使用者確認後執行跨主題的目錄重組。

**Tech Stack:** Markdown 規格文件（無程式碼）

---

## 檔案結構

| 動作 | 檔案路徑 | 職責 |
|------|---------|------|
| Modify | `references/topic-hierarchy-spec.md` | 新增「父子關係判準」段落 + 放寬 curator 檔案移動限制 |
| Modify | `skills/archive/commands/full-archive.md` | 在 Step 1.5 與 Step 2 之間插入 Step 1.6「層級映射」 |
| Modify | `skills/archive/commands/full-archive.md` | 更新 Step 2 的 wiki-writer prompt 模板，支援指定寫入路徑 |
| Modify | `skills/curator/commands/full-curator.md` | 新增 2h 檢查項 + 報告段落 + 自動修補段落 |

---

### Task 1: topic-hierarchy-spec.md — 新增「父子關係判準」

**Files:**
- Modify: `references/topic-hierarchy-spec.md:26-27`（在「獨立性三維度判斷」段落結尾後插入新段落）

- [ ] **Step 1: 在「獨立性三維度判斷」段落（第 26 行 `**規則**` 之後）與「主題生命週期」段落之間，插入以下新段落**

```markdown
---

## 父子關係判準（Hierarchy Detection）

> 用於 full-archive Step 1.6（主動建立）與 curator 2h（事後偵測）。
> 父子關係與獨立性判斷**互不衝突**——一個主題可以通過獨立性三維度成為獨立頁面，同時因從屬關係被放置在父主題的目錄下。

### 歸併條件

對兩個獨立主題 A 與 B，以下任一條件成立即判定為父子關係：

| 關係類型 | 判斷問題 | 範例（子 → 父） |
|----------|---------|-----------------|
| **工具屬性** | A 是 B 的插件、擴充、CLI、SDK 或官方介面？ | Obsidian CLI → Obsidian |
| **組成關係** | A 是 B 的核心組件或子系統？ | Tokenizer → LLM |
| **實例關係** | A 是 B 框架/標準的具體實作或特定版本？ | Claude Opus → Claude |

### 排除條件（不觸發歸併）

即使符合上述條件，以下情況仍維持獨立：

- **多重父節點**：A 可合理歸屬於多個不同父主題（如 MCP 可歸入 Claude Code 也可歸入 AI Agent 架構）→ 維持獨立，以 wikilink 引用
- **子大於父**：A 的內容深度或涵蓋範圍明顯超越「B 的子工具」定位（如 MCP 本身是跨工具協議，不應歸入任何單一工具下）
- **方向不明確**：無法明確判定誰是父、誰是子 → 維持獨立
- **深度超限**：歸併後目錄深度超過 3 層 → A 強制為獨立頂級主題

### 父子方向判定

- **父**：更廣泛、更通用、生態系的擁有者
- **子**：更具體、功能更聚焦、依附於父的生態系
- 命名包含關係可作為輔助信號（如「Obsidian CLI」包含「Obsidian」），但**不可作為唯一判據**
```

- [ ] **Step 2: 修改「檔案移動限制」表格，放寬 curator 的操作範圍**

將 `references/topic-hierarchy-spec.md` 第 97-102 行的表格替換為：

```markdown
| 角色 | 允許的操作 | 禁止的操作 |
|------|-----------|-----------|
| **wiki-writer** | 新建頁面（含在指定父目錄下新建）、合併內容到既有頁面、新增章節 | 移動或重新命名任何既有檔案 |
| **curator** | 同一主題的自我升級（`RAG.md` → `RAG/RAG.md`）；**使用者確認後**，將獨立頁面移入父主題目錄（父子關係重組） | 未經使用者確認的跨主題檔案移動 |
| **archive 主對話** | 在 Step 1.6 中升級既有父頁面為目錄結構（`mkdir` + `mv`），為後續 wiki-writer 準備目錄 | 修改既有頁面的正文內容 |

- 歸檔流程中的目錄準備由主對話在 Step 1.6 執行，wiki-writer 只負責在指定路徑建立/更新內容
- curator 的跨主題重組需要使用者在 Step 6 確認後才執行
```

- [ ] **Step 3: Commit**

```bash
git add references/topic-hierarchy-spec.md
git commit -m "feat: 新增父子關係判準與放寬 curator 檔案移動限制

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: full-archive.md — 新增 Step 1.6「層級映射」

**Files:**
- Modify: `skills/archive/commands/full-archive.md:280-283`（在 Step 1.5 結尾 `---` 與 Step 2 標題之間插入）

- [ ] **Step 1: 在 Step 1.5 的結尾（第 280 行 `---` 之後）與 Step 2 標題之間，插入以下新步驟**

```markdown

## Step 1.6：層級映射（Hierarchy Mapping）（主對話執行）

> 在去重後、呼叫 wiki-writer 前，偵測主題間及主題與既有頁面的父子關係，為每個主題分配最終寫入路徑。
> 確保 wiki-writer 直接建檔在正確位置，避免事後搬移。由主對話集中執行，避免並行 wiki-writer 的競態問題。

### 1.6.1 收集輸入

- Step 1.5 產出的 `deduped_topics[]`（去重後的獨立主題清單）
- 現有 Vault 的主題頁清單：使用 Glob `[vault_path]/主題知識/**/*.md`，提取每個頁面的 `title`、`wiki_category`、frontmatter 中是否有 `type: topic-hub`

### 1.6.2 偵測父子關係

依 `references/topic-hierarchy-spec.md` 的「父子關係判準」，對以下兩組配對進行評估：

**a. 新主題之間**：`deduped_topics[]` 內部，兩兩比對是否存在父子關係。
**b. 新主題 vs 既有頁面**：每個新主題是否為某既有頁面的子實體。

對每個候選配對：
1. 確認符合歸併條件（工具屬性 / 組成關係 / 實例關係）
2. 檢查排除條件（多重父節點 / 子大於父 / 方向不明確 / 深度超限）
3. 判定父子方向

### 1.6.3 分配最終路徑與目錄準備

對每個去重後的獨立主題，分配 `target_path`：

**無父子關係（預設）**：
```
target_path = 主題知識/[wiki_category]/[標題].md
```

**新主題為既有頁面的子實體**：

1. 檢查父頁面是否已有目錄結構（`type: topic-hub`）：
   - **已有目錄** → `target_path = 主題知識/[cat]/[父]/[子].md`
   - **尚未有目錄** → 主對話先執行目錄準備：
     ```bash
     mkdir -p [vault_path]/主題知識/[cat]/[父]
     mv [vault_path]/主題知識/[cat]/[父].md [vault_path]/主題知識/[cat]/[父]/[父].md
     ```
     然後使用 Read + Edit 工具在父頁面 frontmatter 中加入 `type: topic-hub` 和 `children: []`。
     最後分配 `target_path = 主題知識/[cat]/[父]/[子].md`

2. 更新 `index.md` 中父頁面的路徑（若已執行 mv）

**本批次內部父子關係**（兩個新主題構成父子）：

1. 父主題按正常路徑建立（可能需先建目錄）
2. 子主題分配到父目錄下
3. **呼叫順序**：父主題的 wiki-writer **先執行**（不與子主題並行），完成後再呼叫子主題的 wiki-writer。這確保父目錄和 topic-hub frontmatter 已就緒。

### 1.6.4 深度檢查

分配路徑前計算目錄深度（`主題知識/` 算第 0 層）：
- 第 1 層：`主題知識/[category]/[topic].md`（正常）
- 第 2 層：`主題知識/[category]/[topic]/[subtopic].md`（允許）
- 第 3 層：`主題知識/[category]/[topic]/[subtopic]/[sub-subtopic].md`（允許，最深）
- 超過 3 層 → 強制為獨立頂級主題，不歸入父目錄

### 1.6.5 產出層級映射

記錄 `hierarchy_map[]`，每個項目包含：
- 主題標題
- `target_path`（最終寫入路徑）
- 父主題標題（若有）
- `needs_parent_upgrade`（布林值，是否需要升級既有父頁面為目錄結構）

### 1.6.6 輸出層級映射摘要

```
層級映射：[N] 個主題中 [M] 個識別為子主題
- [子主題A] → [父主題X]/[子主題A].md（父主題已有目錄結構）
- [子主題B] → [父主題Y]/[子主題B].md（需升級父頁面 ✓ 已完成）
```

若無父子關係偵測到，輸出：
```
層級映射：全部為獨立主題，無父子關係
```

---
```

- [ ] **Step 2: 更新 Step 2 的描述與 wiki-writer prompt 模板**

在 Step 2 開頭（第 283-287 行），將：
```
對 Step 1.5 去重後的主題清單，並行呼叫 wiki-writer agents。
```
改為：
```
對 Step 1.6 層級映射後的主題清單，並行呼叫 wiki-writer agents。
```

將 Step 2 的 wiki-writer prompt 模板（第 295-309 行）更新為：

```
**每個 agent 的 Prompt**：
~~~
**主題**：[主題標題]
**寫入路徑**：[target_path]（由 Step 1.6 分配；若為子主題，路徑含父目錄）
**父主題**：[父主題標題]（若為子主題；wiki-writer 應在正文中建立與父主題的 wikilink）
**子主題列表**：（若有子主題）
  - [子主題A]：[獨立性理由]
  - [子主題B]：[獨立性理由]
**來源記錄檔名**：[序號_概述]（若多個來源，列出所有）
**來源記錄路徑**：[完整路徑]（若多個來源，列出所有）
**raw_file_path**：[raw/[原始檔名].md]（由 record-writer 輸出提供，供讀取完整原文。注意：此時檔案尚未移至 raw/archived/，須使用原始 raw 路徑）
**來源類型**：[content_type]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
**本批次其他主題**：[列出本批次所有其他獨立主題標題，每行一個]
~~~
```

同時在 Step 2 的「呼叫策略」段落後追加：

```
> **父子主題的呼叫順序**：若 Step 1.6 識別出本批次內部的父子關係，父主題的 wiki-writer **先執行**，確認 topic-hub frontmatter 已寫入後，再於下一輪並行呼叫子主題的 wiki-writer。其餘無父子關係的主題照常並行。
```

- [ ] **Step 3: Commit**

```bash
git add skills/archive/commands/full-archive.md
git commit -m "feat: full-archive 新增 Step 1.6 層級映射 + 更新 Step 2 prompt 支援指定路徑

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: full-curator.md — 新增 2h 檢查項與自動修補

**Files:**
- Modify: `skills/curator/commands/full-curator.md:260-261`（在 2g 結尾 `---` 後插入 2h）
- Modify: `skills/curator/commands/full-curator.md:389-421`（報告模板中新增第 8 項 + 更新總結表格）
- Modify: `skills/curator/commands/full-curator.md:462-475`（Step 6 自動修補中新增父子重組段落）

- [ ] **Step 1: 在 Step 2g 結尾（第 260 行 `---` 之後）與 Step 3 之間，插入新檢查項 2h**

```markdown

### 2h. 父子關係偵測（跨頁面）

> 規格詳見 `${CLAUDE_PLUGIN_ROOT}/references/topic-hierarchy-spec.md`「父子關係判準」段落。

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
   - 歸併後深度超過 3 層 → 跳過
5. **已在目錄中的子頁面不重複偵測**：若 A 已在 B 的目錄下（路徑包含 B 的資料夾），跳過

**記錄**：將候選組存入 `hierarchy_candidates[]`，格式 `(parent_path, child_path, relationship_type, reason)`。

**輔助信號**（提高判定信心，非必要條件）：
- 子頁面的正文中引用了父頁面的 wikilink（表示從屬意識已存在）
- 子頁面的標題包含父頁面的標題作為前綴或後綴
- 子頁面的 `tags` 包含父頁面的標題作為標籤
```

- [ ] **Step 2: 更新 Step 4 報告模板，新增第 8 項**

在報告模板的「## 7. 結構升級候選」區塊之後（第 387 行之後），插入：

```markdown

---

## 8. 父子關係候選（N 組）

以下獨立頁面建議重組為目錄結構：

- [[主題知識/實體/Obsidian]] ← [[主題知識/實體/Obsidian CLI]]（工具屬性：CLI 是 Obsidian 的命令行介面）
- [[主題知識/概念/XXX]] ← [[主題知識/概念/YYY]]（組成關係：YYY 是 XXX 的核心組件）
...

**建議**：執行自動修補將父頁面升級為目錄結構，並將子頁面移入。重組流程見 `references/topic-hierarchy-spec.md`。
```

更新總結表格（原第 393-401 行），追加一行：

```
| 父子關係候選 | N |
```

更新建議優先處理清單（原第 413-421 行），在第 2 項「結構升級候選」之後插入：

```
3. **父子關係候選**（可自動修補，需使用者確認，改善知識組織）
```

後續項目編號順延。

- [ ] **Step 3: 更新 Step 5 log.md 追加模板**

在 log.md 的 curator 條目範例中（約第 443 行），追加：

```
- 父子關係候選：N 組
```

- [ ] **Step 4: 更新 Step 6 自動修補段落**

在 Step 6 的「可自動修補的項目」清單（約第 462-467 行），追加：

```
5. **父子關係重組**（將獨立子頁面移入父主題目錄）→ 使用管道 2 + Bash（mkdir/mv/Edit）
```

在 Step 6 的「結構升級」自動修補段落之後，追加新段落：

```markdown
### 自動修補：父子關係重組（管道 2 + Bash）

> 重組流程詳見 `${CLAUDE_PLUGIN_ROOT}/references/topic-hierarchy-spec.md`。

**前置確認**：每組父子候選需使用者逐一確認（或批次確認），不自動執行。確認時顯示：

~~~
父子關係重組確認：
  1. [[主題知識/實體/Obsidian]] ← [[主題知識/實體/Obsidian CLI]]（CLI 是 Obsidian 的命令行介面）
  2. ...

是否執行？（輸入「全部」/編號/「n」）
~~~

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

6. **更新 index.md**：使用 Edit 工具將 index.md 中子頁面的路徑更新為新路徑

7. **Wikilink 處理**：由於 Obsidian 最短路徑解析，大部分 `[[Obsidian CLI]]` 連結會自動解析到新位置。僅在 Vault 中存在同名檔案時需手動修正。

**深度限制**：重組前檢查目標路徑深度，超過 3 層則跳過並在報告中警告。
```

- [ ] **Step 5: Commit**

```bash
git add skills/curator/commands/full-curator.md
git commit -m "feat: curator 新增 2h 父子關係偵測 + 自動修補支援

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 驗證規格一致性

- [ ] **Step 1: 確認三份文件的交叉引用一致**

檢查以下引用鏈是否正確：
- `full-archive.md` Step 1.6 引用 `references/topic-hierarchy-spec.md` 的「父子關係判準」
- `full-curator.md` 2h 引用 `references/topic-hierarchy-spec.md` 的「父子關係判準」
- `topic-hierarchy-spec.md` 的檔案移動限制表提到 `archive 主對話` 的 Step 1.6 職責
- `full-archive.md` Step 2 的 prompt 模板包含 `**寫入路徑**` 和 `**父主題**` 欄位

- [ ] **Step 2: 確認深度限制規則在三處一致（均為 3 層）**

- `topic-hierarchy-spec.md` 深度限制段落
- `full-archive.md` Step 1.6.4
- `full-curator.md` 2h 的排除條件

- [ ] **Step 3: Commit（若有修正）**
