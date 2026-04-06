# Full Archive：完整歸檔

掃描 `raw/` 目錄，對每個待歸檔檔案呼叫 record-writer 建立來源記錄、wiki-writer upsert 知識頁，
完成後更新 index.md 與 log.md，並將已成功歸檔的 raw 原檔移至 `raw/archived/`。

---

## Step -1：對話歸檔預處理（條件式）

> **觸發條件**：使用者意圖為「歸檔當前對話」或類似語意（見 SKILL.md 意圖解析）。
> 非對話歸檔情境請**直接跳至 Step 0**，不執行本步驟。

本步驟由主對話執行，不委派 sub-agent。

### -1.1 決定對話範圍

- **預設**：歸檔從本次 session 開始（或上次歸檔操作）至今的全部對話。
- **使用者指定範圍**：若使用者說「只歸檔剛剛討論 X 的部分」，依其指定萃取對應的訊息段落。
- 主對話自行判斷對話起點與終點，不需要求使用者額外確認（除非範圍模糊）。

### -1.2 萃取對話內容

從當前 session 取得對話原文，進行以下清理與保留：

**清理（移除）**：
- 工具呼叫的原始 JSON 輸出（tool use / tool result 區塊）
- 內部 thinking 區塊（若有 `<thinking>` 標籤）
- 系統提示、SKILL.md 載入過程等 harness 內部訊息

**保留**：
- 使用者的原始問題與指令（完整保留，不摘要）
- Assistant 的回答正文（保留核心內容，可省略重複的工具呼叫描述）
- 重要的程式碼區塊（用 fenced code block 包圍）
- 重要的連結與路徑

**萃取後產生**：
- **title**：對話摘要，20 字以內，描述本次對話的主要主題或任務
- **討論主題列表**：供後續 wiki-writer 使用（非必要，視內容而定）

### -1.3 決定時間戳記與檔名

執行以下命令取得時間戳記：

```bash
date '+%Y%m%d%H%M'
```

**檔名**：`conversation-[YYYYMMDDHHmm].md`

**同分鐘內多次歸檔的處理**：若 `raw/conversation-[YYYYMMDDHHmm].md` 已存在，在時間戳記後加流水號：
- `conversation-[YYYYMMDDHHmm]-2.md`
- `conversation-[YYYYMMDDHHmm]-3.md`
- 依此類推

使用 Glob 工具確認 `[vault_path]/raw/conversation-[YYYYMMDDHHmm]*.md` 是否存在，決定最終檔名。

### -1.4 產生 raw 檔 frontmatter

```yaml
---
title: [對話摘要，20 字以內]
date: [YYYY-MM-DD，今日日期]
author: [使用者稱呼]
source: conversation-[YYYYMMDDHHmm]
content_type: conversation
---
```

**author 取得方式**：
1. 讀取 `~/.claude/CLAUDE.md`，搜尋「**稱呼**：」或「稱呼：」後面的值（如 `leadi`）
2. 若找不到，填 `unknown`

**date**：執行 `date '+%Y-%m-%d'` 取得今日日期。

### -1.5 組合 raw 檔內容

完整 raw 檔格式：

```markdown
---
title: [對話摘要]
date: [YYYY-MM-DD]
author: [使用者稱呼]
source: conversation-[YYYYMMDDHHmm]
content_type: conversation
---

## 對話內容

**使用者**：
[使用者訊息1]

**Assistant**：
[assistant 回應1]

**使用者**：
[使用者訊息2]

**Assistant**：
[assistant 回應2]
```

每段 `**使用者**：` 與 `**Assistant**：` 之間空一行，保持可讀性。

### -1.6 寫入 raw/

使用以下命令建立 raw 檔（`[TIMESTAMP]` 替換為實際時間戳記）：

對話內容可能較長，須分段寫入：

```bash
# 先 create 含 frontmatter + 對話開頭部分（不超過 16KB）
obsidian create vault=[vault_name] path="raw/conversation-[TIMESTAMP].md" content="---\ntitle: [對話摘要]\ndate: [YYYY-MM-DD]\nauthor: [使用者稱呼]\nsource: conversation-[TIMESTAMP]\ncontent_type: conversation\n---\n\n## 對話內容\n\n[前段對話]"

# 若有剩餘對話內容，分段 append
obsidian append vault=[vault_name] path="raw/conversation-[TIMESTAMP].md" content="\n[中段對話]"
obsidian append vault=[vault_name] path="raw/conversation-[TIMESTAMP].md" content="\n[後段對話]"
```

> 說明：content= 單次建議不超過 16KB。超過時，先 create 寫入前段，再分段 append 剩餘部分。換行使用 `\n`，雙引號使用 `\"`，反引號使用 `` \` ``，美元符號使用 `\$`。

### -1.7 確認並繼續

寫入成功後輸出確認訊息：

```
✓ 對話已寫入 raw/conversation-[YYYYMMDDHHmm].md
  title: [對話摘要]
  author: [使用者稱呼]
  訊息數：[N] 則（使用者 X 則，Assistant Y 則）

接下來進入標準歸檔流程...
```

寫入失敗（obsidian CLI 報錯）則輸出錯誤並終止：

```
⛔ 對話 raw 檔寫入失敗：[錯誤訊息]
請確認 vault_path 正確且 raw/ 目錄存在。
```

---

## Step 0：掃描 raw/ 目錄

使用 Glob 工具掃描：`[vault_path]/raw/*.md`

**分支處理**：

**無檔案**：輸出以下提示後終止：
```
raw/ 目錄為空，沒有待歸檔檔案。
請先透過 Obsidian Web Clipper、手動建立或對話歸檔將內容放入 raw/。
```

**1 個檔案**：直接進入 Step 1 處理該檔案。

**多個檔案**：列出清單詢問使用者：
```
raw/ 目錄有 N 個待歸檔檔案：
  1. [檔名1]
  2. [檔名2]
  ...

請選擇：
- 輸入「全部」處理所有檔案
- 輸入編號（如 1,3）處理特定檔案
```
等待使用者回覆後，依回覆結果決定本次處理的檔案清單，再進入 Step 1。

---

## Step 1：對每個 raw 檔並行呼叫 record-writer

Agent tool，`subagent_type: "obsidian-vault-tool:record-writer"`。

**並行策略**：若使用者選擇多個檔案，在**單一訊息**中發出多個 Agent tool 呼叫（每個檔案一個 agent）。

**每個 agent 的 Prompt**：
```
**raw 檔絕對路徑**：[vault_path]/raw/[檔名].md
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

**等待每個 agent 輸出並解析**：
```
raw_file_path：[絕對路徑]
raw_archived_path：[raw/archived/[檔名].md]
來源記錄路徑：[完整路徑]
來源記錄檔名：[序號_概述]
知識主題列表：
1. [主題一]
2. [主題二]
來源類型：[content_type]

## 執行紀錄
（結構化執行紀錄）
```

從輸出提取以下欄位，依 raw 檔分組暫存：
- `raw_file_path`（供 Step 6 移動至 raw/archived/ 用）
- `raw_archived_path`（供 Step 2 傳給 wiki-writer 讀取原文用）
- `來源記錄路徑`、`來源記錄檔名`
- `知識主題列表`
- `來源類型`（`content_type`）
- 執行紀錄（存為 `record_writer_logs[]`）

**熔斷處理**：

- 若某個 record-writer 回報**欄位不全熔斷**（輸出含 `⛔ 歸檔中斷`），**該 raw 檔標記為失敗，不刪除原檔**，繼續處理其他檔案。
- 若某個 record-writer 回報**來源重複（友善終止）**，**該 raw 檔標記為已存在，移動至 raw/archived/**（因來源已在 Vault 中），繼續處理其他檔案。

---

## Step 2：解析主題列表 → 並行呼叫 wiki-writer（upsert 模式）

對每個 Step 1 成功的 record-writer 結果，依其**知識主題列表**並行呼叫 wiki-writer agents。

Agent tool，`subagent_type: "obsidian-vault-tool:wiki-writer"`。

若同批次有多個 raw 檔各自含多個主題，在**單一訊息**中對所有主題同時發出 Agent tool 呼叫。

**每個 agent 的 Prompt**：
```
**主題**：[主題標題]
**來源記錄檔名**：[序號_概述]
**來源記錄路徑**：[完整路徑]
**raw_archived_path**：[raw/archived/[原始檔名].md]（由 record-writer 輸出提供，供讀取完整原文）
**來源類型**：[content_type]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

**等待輸出並解析**：
- 寫入路徑（`主題知識/[類別]/[標題].md`）
- 寫入模式（`新建` / `merge` / `衝突待裁決`）
- `wiki_category`（實體/概念/比較/總覽）
- 同主題判定結果（Level X 命中，或 aliases +N）
- 執行紀錄（存為 `knowledge_writer_logs[]`）

**衝突待裁決處理**：若某主題回報「衝突待裁決」，**不阻塞其他主題的處理**。所有 agents 完成後，對有衝突的主題依序顯示候選清單給使用者：
```
主題「[標題]」有多個可能的合併目標，請選擇：
  1. [[主題知識/[類別]/[候選A]]] — [摘要]
  2. [[主題知識/[類別]/[候選B]]] — [摘要]
  3. 新建（不合併）
```
等待使用者選擇後，**重新呼叫該主題的 wiki-writer**，在 Prompt 末尾附加：
```
**使用者裁決**：合併至 [[主題知識/[類別]/[候選]]]（或「新建」）
```

---

## Step 3：驗證（主對話執行）

對每篇 Step 2 新建或 merge 的知識筆記，使用 Read 工具讀取前 20 行，確認：

1. 第 1 行為 `---`
2. 存在第二個 `---`（frontmatter 結束）
3. `sources:` 陣列每項被雙引號包覆（格式：`"[[來源記錄檔名]]"`）
4. `wiki_category:` 值有效（限：實體/概念/比較/總覽）
5. `updated:` 格式正確（`YYYY-MM-DD`）

若驗證失敗，重新呼叫該主題的 wiki-writer（最多 2 次外部重試）。每次重試前宣告：
```
[外部驗證重試 N/2] 主題：[主題標題]，失敗項目：[具體項目]
```

2 次重試後仍失敗，**對該篇記錄為失敗，繼續處理其他篇**，最後在完成通知統一回報。

---

## Step 4：更新 index.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/index-spec.md` 了解更新規則。

執行流程：

對本次所有寫入的知識筆記（新建 + merge，驗證通過者），對每個主題使用 `obsidian append` 追加一行條目：

```bash
obsidian append vault=[vault_name] path="index.md" content="\n[YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [一行摘要]（sources: N）[new]"
```

- **新建主題**：末尾標記 `[new]`
- **merge 主題**：末尾標記 `[updated]`
- 每個主題各自一次 append，條目格式：
  ```
  [YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [一行摘要]（sources: N）[new|updated]
  ```

> 注意：index.md 採 append-only 模式，不讀取整檔、不覆寫。lint skill 負責定期清理重複條目。
> index.md 由主對話串行更新，不委派 sub-agent，避免並行寫入衝突。

---

## Step 5：追加 log.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/log-spec.md` 了解格式。

對每個 Step 1 成功處理的 raw 檔，使用 `obsidian append` 直接追加 ingest 條目。

**時間戳記**：執行 `date '+%Y-%m-%d %H:%M'` 取得當前本地時間。

**Append 方法**：直接 append，不需讀取整檔再寫回。

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] ingest | [來源標題]\n- record: [[歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述]]]\n- new: [[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]\n- updated: [[主題知識/[類別]/主題C]]"
```

若無新建主題則省略 `- new:` 行；若無更新主題則省略 `- updated:` 行。

條目格式說明：
```markdown

## [YYYY-MM-DD HH:mm] ingest | [來源標題]
- record: [[歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述]]]
- new: [[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]
- updated: [[主題知識/[類別]/主題C]]
```

> 注意：log.md 採 append-only 模式，不讀取整檔、不覆寫整檔。
> log.md 由主對話串行更新，不委派 sub-agent，避免並行寫入衝突。

---

## Step 6：移動已成功處理的 raw 檔至 raw/archived/

對符合以下條件的 raw 檔，執行移動（`mv`）：
- Step 1 成功（record-writer 輸出完整）
- Step 2 所有主題均已完成（包含衝突已由使用者裁決）
- Step 3 驗證通過（允許部分主題驗證失敗，只要至少一篇通過）

以及：
- Step 1 回報「來源重複（友善終止）」的 raw 檔

移動命令：
```bash
mv [vault_path]/raw/[檔名].md [vault_path]/raw/archived/[檔名].md
```

> 說明：raw 原檔移至 `raw/archived/` 保留，供 wiki-writer 日後回讀完整原文使用。
> record-writer 在歷史紀錄中的反向連結（`> 原始內容見 [[raw/archived/[檔名]]]`）即對應此路徑。

**不移動**：
- Step 1 熔斷（欄位不全）的 raw 檔
- 所有主題均驗證失敗的 raw 檔
- 衝突待裁決尚未處理完畢的 raw 檔

以上情況保留在 `raw/` 供使用者後續處理。

---

## Step 7：完成通知

```
已完成歸檔（處理 [N] 個 raw 檔）：

成功：[M] 個
- [raw 檔名1] → [[來源記錄]] → 新建: X 個主題，更新: Y 個主題
- ...

失敗：[K] 個
- [raw 檔名2]：[失敗原因]

已存在（跳過）：[L] 個
- [raw 檔名3]：來源已在 Vault 中
```

> 若有驗證失敗的知識筆記，在完成通知末尾附加：
```
⚠️ 以下知識筆記驗證失敗（已放棄寫入）：
- [主題X]：[失敗原因]
```

**最末尾附加執行紀錄摘要**（從 `record_writer_logs[]` 和 `knowledge_writer_logs[]` 整合）：

```
---
## 執行紀錄摘要

**record-writer × N**
- [raw 檔名1]：✓ 成功（欄位驗證通過，識別 N 個主題）
- [raw 檔名2]：⛔ 失敗（欄位不全：author 缺失）
- [raw 檔名3]：⚠️ 來源重複（已存在，跳過）

**wiki-writer × M**
- [主題一]：✓ 新建，Level X 命中
- [主題二]：✓ merge 至 [[既有頁]]，aliases +1
- [主題三]：⚠️ 衝突待裁決 → 使用者選擇合併至 [[候選A]]，已重新寫入

**index.md**：已追加 X 筆條目（新建 + merge）
**log.md**：已追加 N 個 ingest 條目
**raw/ 清理**：已移動 M 個已歸檔檔案至 raw/archived/，保留 K 個失敗檔案
```
